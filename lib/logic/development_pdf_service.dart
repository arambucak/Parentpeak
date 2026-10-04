import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Alle nutzersichtbaren Texte des Entwicklungsbericht-PDFs — lokalisiert von
/// der UI übergeben, damit das PDF in der App-Sprache erscheint (keine hart
/// codierten deutschen Strings mehr).
@immutable
class DevelopmentPdfLabels {
  const DevelopmentPdfLabels({
    required this.reportTitle,
    required this.createdOn,
    required this.progressTitle,
    required this.compareWith,
    required this.aiReportTitle,
    required this.disclaimer,
    required this.legendCurrent,
    required this.legendPrevious,
    required this.trendUp,
    required this.trendDown,
    required this.trendStable,
    required this.footer,
    required this.pageOf,
    required this.fileNamePrefix,
    required this.domainLabels,
  });

  final String reportTitle; // z.B. "Entwicklungsbericht"
  final String createdOn; // "Erstellt am {date}"
  final String progressTitle; // "Entwicklungs-Verlauf"
  final String compareWith; // "Vergleich mit {date}"
  final String aiReportTitle; // "KI-Entwicklungsbericht"
  final String disclaimer; // Haftungs-/Hinweistext
  final String legendCurrent; // "Aktuell"
  final String legendPrevious; // "Vorheriger Check"
  final String trendUp; // "wächst"
  final String trendDown; // "pausiert"
  final String trendStable; // "stabil"
  final String footer; // Fußzeile links
  final String pageOf; // "Seite {page} von {total}"
  final String fileNamePrefix; // Dateiname-Präfix (ASCII-sicher)

  /// domainId -> lokalisierter Bereichsname (aus den DevDomain-Titeln).
  final Map<String, String> domainLabels;
}

/// PDF-Export für den Entwicklungsbericht.
///
/// Erstellt ein professionelles, vollständig lokalisiertes PDF mit:
/// - Parentpeak-Header + Kind-Info
/// - Balkenvergleich (aktuell vs. vorherig)
/// - KI-Bericht Text
/// - Disclaimer
class DevelopmentPdfService {
  DevelopmentPdfService._();

  /// Erstellt und zeigt den PDF-Druck/Speicher-Dialog.
  static Future<void> generateAndShow({
    required String childName,
    required String childAge,
    required Map<String, double> currentScores,
    required DevelopmentPdfLabels labels,
    Map<String, double>? previousScores,
    DateTime? previousDate,
    String? aiReportText,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildHeader(childName, childAge, labels.reportTitle),
        footer: (context) => _buildFooter(context, labels),
        build: (context) => [
          // Datum
          pw.Text(
            labels.createdOn.replaceAll('{date}', _formatDate(DateTime.now())),
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 20),

          // Chart
          _buildChartSection(
              currentScores, previousScores, previousDate, labels),
          pw.SizedBox(height: 24),

          // KI-Bericht
          if (aiReportText != null && aiReportText.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    labels.aiReportTitle,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    aiReportText,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      lineSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // Disclaimer
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FEF3C7'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              labels.disclaimer,
              style: const pw.TextStyle(fontSize: 8, lineSpacing: 3),
            ),
          ),
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name:
            '${labels.fileNamePrefix}_${_sanitizeFileName(childName)}_${_formatDateShort(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('DevelopmentPdfService: PDF generation failed: $e');
    }
  }

  static pw.Widget _buildHeader(
      String childName, String childAge, String reportTitle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Markenname bleibt sprachunabhängig.
              pw.Text(
                'Parentpeak',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#4CAF50'),
                ),
              ),
              pw.Text(
                reportTitle,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                childName,
                style: const pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                childAge,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
      pw.Context context, DevelopmentPdfLabels labels) {
    final pageText = labels.pageOf
        .replaceAll('{page}', '${context.pageNumber}')
        .replaceAll('{total}', '${context.pagesCount}');
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            labels.footer,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            pageText,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildChartSection(
    Map<String, double> currentScores,
    Map<String, double>? previousScores,
    DateTime? previousDate,
    DevelopmentPdfLabels labels,
  ) {
    final hasPrevious = previousScores != null && previousScores.isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          labels.progressTitle,
          style:
              const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        if (hasPrevious && previousDate != null)
          pw.Text(
            labels.compareWith.replaceAll('{date}', _formatDate(previousDate)),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        pw.SizedBox(height: 12),
        ...currentScores.entries.map((entry) {
          final domain = entry.key;
          final current = entry.value;
          final previous = previousScores?[domain];
          return _buildDomainBar(domain, current, previous, labels);
        }),

        // Legend
        pw.SizedBox(height: 12),
        pw.Row(children: [
          _legendItem(PdfColor.fromHex('#16A34A'), labels.legendCurrent),
          pw.SizedBox(width: 16),
          if (hasPrevious)
            _legendItem(PdfColors.grey400, labels.legendPrevious),
        ]),
      ],
    );
  }

  static pw.Widget _buildDomainBar(String domain, double current,
      double? previous, DevelopmentPdfLabels labels) {
    final label = labels.domainLabels[domain] ?? domain;
    final percent = (current * 100).round();
    final trend = _getTrendLabel(current, previous, labels);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(
              child: pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text('$percent% $trend',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
          pw.SizedBox(height: 4),
          // Bar background
          pw.Container(
            height: 8,
            child: pw.Row(children: [
              pw.Expanded(
                flex: (current * 100).round().clamp(1, 100),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#16A34A'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
              ),
              if ((current * 100).round() < 100)
                pw.Expanded(
                  flex: (100 - (current * 100).round()).clamp(1, 100),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _legendItem(PdfColor color, String label) {
    return pw.Row(children: [
      pw.Container(width: 10, height: 10, color: color),
      pw.SizedBox(width: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
    ]);
  }

  static String _getTrendLabel(
      double current, double? previous, DevelopmentPdfLabels labels) {
    if (previous == null) return '';
    final diff = current - previous;
    if (diff > 0.1) return '↗ ${labels.trendUp}';
    if (diff < -0.1) return '↘ ${labels.trendDown}';
    return '→ ${labels.trendStable}';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _formatDateShort(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Entfernt für Dateinamen ungeeignete Zeichen (Umlaute/Sonderzeichen).
  static String _sanitizeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final trimmed = cleaned.replaceAll(RegExp(r'^_|_$'), '');
    return trimmed.isEmpty ? 'Kind' : trimmed;
  }
}
