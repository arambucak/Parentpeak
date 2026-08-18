import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF-Export für den Entwicklungsbericht.
///
/// Erstellt ein professionelles PDF mit:
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
    Map<String, double>? previousScores,
    DateTime? previousDate,
    String? aiReportText,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(childName, childAge),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Datum
          pw.Text(
            'Erstellt am ${_formatDate(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 20),

          // Chart
          _buildChartSection(currentScores, previousScores, previousDate),
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
                    'KI-Entwicklungsbericht',
                    style: pw.TextStyle(
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
              'Hinweis: Dieser Bericht basiert auf Eltern-Beobachtungen und ist keine medizinische '
              'Diagnose. Bei Bedenken zur Entwicklung deines Kindes wende dich bitte an '
              'deinen Kinderarzt oder eine Frühförderstelle.',
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
            'Entwicklungsbericht_${childName.replaceAll(' ', '_')}_${_formatDateShort(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('DevelopmentPdfService: PDF generation failed: $e');
    }
  }

  static pw.Widget _buildHeader(String childName, String childAge) {
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
              pw.Text(
                'Parentpeak',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#4CAF50'),
                ),
              ),
              pw.Text(
                'Entwicklungsbericht',
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
                style: pw.TextStyle(
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

  static pw.Widget _buildFooter(pw.Context context) {
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
            'Erstellt mit Parentpeak — parentpeak.de',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
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
  ) {
    final hasPrevious = previousScores != null && previousScores.isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Entwicklungs-Verlauf',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        if (hasPrevious && previousDate != null)
          pw.Text(
            'Vergleich mit ${_formatDate(previousDate)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        pw.SizedBox(height: 12),
        ...currentScores.entries.map((entry) {
          final domain = entry.key;
          final current = entry.value;
          final previous = previousScores?[domain];
          return _buildDomainBar(domain, current, previous);
        }),

        // Legend
        pw.SizedBox(height: 12),
        pw.Row(children: [
          _legendItem(PdfColor.fromHex('#16A34A'), 'Aktuell'),
          pw.SizedBox(width: 16),
          if (hasPrevious) _legendItem(PdfColors.grey400, 'Vorheriger Check'),
        ]),
      ],
    );
  }

  static pw.Widget _buildDomainBar(
      String domain, double current, double? previous) {
    final label = _domainLabel(domain);
    final percent = (current * 100).round();
    final trend = _getTrendLabel(current, previous);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
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

  static String _getTrendLabel(double current, double? previous) {
    if (previous == null) return '';
    final diff = current - previous;
    if (diff > 0.1) return '↗ wächst';
    if (diff < -0.1) return '↘ pausiert';
    return '→ stabil';
  }

  static String _domainLabel(String id) {
    const labels = {
      'motorik': 'Motorik',
      'sprache': 'Sprache',
      'sozial': 'Sozial-emotional',
      'kognition': 'Kognition',
      'autonomie': 'Autonomie',
    };
    return labels[id] ?? id;
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _formatDateShort(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
