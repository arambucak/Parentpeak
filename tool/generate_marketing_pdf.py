#!/usr/bin/env python3
"""Generiert den Parentpeak Marketing-Bericht als PDF."""

from fpdf import FPDF
import os

OUTPUT_PATH = os.path.join(os.path.dirname(__file__), '..', 'docs', 'MARKETING_BERICHT_PARENTPEAK.pdf')

# ─── Farben ────────────────────────────────────────────────────────────────────
BLUE_DARK   = (15,  86, 219)   # #0F56DB
BLUE_LIGHT  = (37, 99, 235)    # #2563EB
TEAL        = (14, 165, 164)   # #0EA5A4
WHITE       = (255, 255, 255)
DARK_TEXT   = (15,  23,  42)   # #0F172A
GREY_TEXT   = (100, 116, 139)  # slate-500
GREY_BG     = (248, 250, 252)  # slate-50
BORDER      = (226, 232, 240)  # slate-200


def clean(text: str) -> str:
    """Replace characters not supported by cp1252."""
    return (text
            .replace('\u2014', '-')   # em dash
            .replace('\u2013', '-')   # en dash
            .replace('\u201c', '"')   # left quote
            .replace('\u201d', '"')   # right quote
            .replace('\u2018', "'")   # left single quote
            .replace('\u2019', "'"))  # right single quote


class MarketingPDF(FPDF):
    def __init__(self):
        super().__init__()
        self.core_fonts_encoding = 'latin-1'

    @staticmethod
    def _c(text):
        """Sanitize text for cp1252."""
        return (str(text)
                .replace('\u2014', '-').replace('\u2013', '-')
                .replace('\u201c', '"').replace('\u201d', '"')
                .replace('\u2018', "'").replace('\u2019', "'")
                .replace('\u2026', '...'))
    def header(self):
        # Blauer Streifen oben
        self.set_fill_color(*BLUE_DARK)
        self.rect(0, 0, 210, 12, 'F')
        self.set_y(14)

    def footer(self):
        self.set_y(-14)
        self.set_font('Helvetica', 'I', 8)
        self.set_text_color(*GREY_TEXT)
        self.cell(0, 5, f'Parentpeak Marketing-Bericht 2026  |  Seite {self.page_no()}', align='C')

    def colored_title_page(self):
        # Hintergrund
        self.set_fill_color(*BLUE_DARK)
        self.rect(0, 0, 210, 297, 'F')

        # Weißes Rechteck in der Mitte
        self.set_fill_color(*WHITE)
        self.rect(20, 60, 170, 160, 'F')

        # Titel
        self.set_y(80)
        self.set_font('Helvetica', 'B', 32)
        self.set_text_color(*BLUE_DARK)
        self.cell(0, 16, 'Parentpeak', align='C', ln=True)

        self.set_font('Helvetica', 'B', 18)
        self.set_text_color(*BLUE_LIGHT)
        self.cell(0, 10, 'Marketing-Bericht 2026', align='C', ln=True)

        self.set_y(125)
        self.set_font('Helvetica', '', 12)
        self.set_text_color(*DARK_TEXT)
        self.set_x(30)
        self.multi_cell(150, 7,
            'Alles, was das Marketing-Team über Parentpeak wissen muss\n'
            '- um Eltern zu überzeugen, die App zu nutzen.',
            align='C')

        # Trennlinie
        self.set_draw_color(*TEAL)
        self.set_line_width(1)
        self.line(60, 160, 150, 160)

        # Meta-Infos
        self.set_y(168)
        self.set_font('Helvetica', '', 10)
        self.set_text_color(*GREY_TEXT)
        for line in ['Erstellt: Juli 2026', 'Plattformen: iOS . Android . Web', 'parentpeak.de']:
            self.cell(0, 7, line, align='C', ln=True)

    def section_header(self, number, title, color=BLUE_DARK):
        self.ln(4)
        # Hintergrundbalken
        self.set_fill_color(*color)
        self.rect(self.get_x(), self.get_y(), 190, 10, 'F')
        self.set_font('Helvetica', 'B', 12)
        self.set_text_color(*WHITE)
        self.cell(8, 10, str(number) + '.', ln=False)
        self.cell(0, 10, '  ' + title, ln=True)
        self.set_text_color(*DARK_TEXT)
        self.ln(3)

    def sub_header(self, icon, title):
        self.ln(3)
        self.set_font('Helvetica', 'B', 11)
        self.set_text_color(*BLUE_LIGHT)
        self.cell(0, 7, icon + '  ' + title, ln=True)
        self.set_text_color(*DARK_TEXT)

    def body_text(self, text, indent=0):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(*DARK_TEXT)
        if indent:
            self.set_x(self.get_x() + indent)
        self.multi_cell(190 - indent, 6, text)

    def bullet(self, text, indent=8):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(*DARK_TEXT)
        x = self.get_x() + indent
        y = self.get_y()
        self.set_xy(x, y)
        self.cell(5, 6, '-')
        self.multi_cell(185 - indent, 6, text)

    def highlight_box(self, text, bg=GREY_BG, border=BORDER):
        self.ln(2)
        self.set_fill_color(*bg)
        self.set_draw_color(*border)
        self.set_line_width(0.3)
        x, y = self.get_x(), self.get_y()
        self.rect(x, y, 190, 12, 'FD')
        self.set_font('Helvetica', 'I', 10)
        self.set_text_color(*BLUE_DARK)
        self.set_xy(x + 4, y + 3)
        self.multi_cell(182, 5, text)
        self.ln(4)
        self.set_text_color(*DARK_TEXT)

    def feature_card(self, num, icon, title, desc, argument):
        self.ln(2)
        # Karte
        x, y = 10, self.get_y()
        # Nummern-Badge
        self.set_fill_color(*BLUE_DARK)
        self.rect(x, y, 12, 12, 'F')
        self.set_font('Helvetica', 'B', 10)
        self.set_text_color(*WHITE)
        self.set_xy(x, y + 2)
        self.cell(12, 8, str(num), align='C')

        # Titel
        self.set_xy(x + 14, y + 2)
        self.set_font('Helvetica', 'B', 11)
        self.set_text_color(*BLUE_DARK)
        self.cell(170, 8, icon + '  ' + title)

        self.set_xy(x, y + 14)
        self.set_font('Helvetica', '', 10)
        self.set_text_color(*DARK_TEXT)
        self.multi_cell(190, 5, desc)

        if argument:
            ay = self.get_y() + 1
            self.set_fill_color(224, 242, 254)  # light blue
            self.rect(x, ay, 190, 8, 'F')
            self.set_xy(x + 3, ay + 1)
            self.set_font('Helvetica', 'I', 9)
            self.set_text_color(14, 116, 144)
            self.multi_cell(185, 6, 'Argument: ' + argument)
            self.set_text_color(*DARK_TEXT)
        self.ln(4)


def build_pdf():
    pdf = MarketingPDF()
    pdf.set_auto_page_break(auto=True, margin=18)

    # ── Titelseite ──────────────────────────────────────────────────────────────
    pdf.add_page()
    pdf.colored_title_page()

    # ── Seite 2: Einleitung ─────────────────────────────────────────────────────
    pdf.add_page()
    pdf.section_header(1, 'Was ist Parentpeak?')
    pdf.body_text(
        'Parentpeak ist eine mobile App für Eltern, die den Familienalltag einfacher, sicherer und '
        'verbundener macht. Die App kombiniert KI-gestützte Erziehungsberatung, Familienorganisation, '
        'ein lokales Event-Netzwerk und eine sichere Community - alles in einer einzigen Anwendung.\n'
    )
    pdf.highlight_box(
        '"Parentpeak gibt Eltern das, was sie wirklich brauchen: Unterstützung im richtigen Moment, '
        'ohne lange suchen zu müssen."'
    )
    pdf.body_text('Verfügbar auf: iOS . Android . Web (parentpeak.de)\n'
                  'Sprachen: Deutsch, Englisch, Arabisch, Japanisch, Chinesisch, Hindi, Türkisch und mehr\n'
                  'Zielgruppe: Eltern mit Kindern von 0-18 Jahren')

    # ── Seite 3-4: Kernfunktionen ───────────────────────────────────────────────
    pdf.add_page()
    pdf.section_header(2, 'Die 12 Kernfunktionen', BLUE_DARK)

    features = [
        (1, 'KI-Elternberatung', '24/7 Erziehungsberatung via Gemini AI (GfK-Pädagogik). '
            'Eltern tippen ihre Frage - und bekommen in Sekunden eine fundierte Antwort.',
            'Andere Apps geben allgemeine Tipps. Parentpeak gibt persönliche Antworten.'),
        (2, 'Wöchentlicher Elternimpuls', 'Jede Woche ein neuer, praxisnaher Tipp zu Trotzphasen, '
            'Schlaf, Medienkonsum, Schule und Pubertät - automatisch, ohne Suche.', ''),
        (3, 'Entwicklungsschema 0-18 Jahre', 'Digitaler Begleiter durch alle Entwicklungsphasen. '
            'Was ist normal? Was braucht mein Kind gerade? Weniger Unsicherheit, mehr Vertrauen.', ''),
        (4, 'Familienkalender', 'Geteilter Kalender für die ganze Familie - von der Arztvorsorge '
            'bis zum Schulausflug. Erinnerungen, Übersicht, weniger Chaos.', ''),
        (5, 'Eltern-Matching', 'Wie Tinder für Eltern-Bekanntschaften. Filter nach Kindesalter, '
            'Interessen, Sprachen. Swipen und matchen für Spielplatz, Playdates, gegenseitige Hilfe.',
            'Viele Eltern fühlen sich allein. Parentpeak verbindet sie mit Menschen, die das gleiche Leben leben.'),
        (6, 'Events & Aktivitäten', 'Lokale Familienevents entdecken oder selbst erstellen. '
            'Mit Teilnahme-System, Gruppen-Chat und Stripe-Zahlungen für bezahlte Kurse.', ''),
        (7, 'Verschenkmarkt', 'Kinderkleidung, Spielzeug, Bücher verschenken und tauschen - '
            'lokal, kostenlos, persönlich. Eltern verbinden sich durch das Teilen.',
            'Nachhaltig, kostenlos und gemeinschaftsbildend - eine Funktion, die Eltern lieben.'),
        (8, 'Organisation', 'Geteilte Einkaufsliste und To-do-Listen für die ganze Familie. '
            'Nie wieder vergessen, wer was erledigen sollte.', ''),
        (9, 'Schutz & Sicherheit', 'Sicherheitsleitfaden, Notfallkontakte, Geräteverwaltung '
            'und Präventionstipps für den Alltag - alles auf einem Blick.', ''),
        (10, 'Familienprofil', 'Mitglieder anlegen, Rollen verwalten, Interessen festlegen. '
             'Privacy-Modus schützt sensible Familieninformationen.', ''),
        (11, 'Fotos & Kontakte', 'Familien-Fotoalbum und Vertrauenskontakte direkt in der App '
             'sicher verwahren.', ''),
        (12, 'Familien-Küche / Küchen-Impulse', 'KI-generierte Rezeptideen für den Familienalltag '
             'mit direkter Einkaufslisten-Integration.', ''),
    ]

    for num, title, desc, argument in features:
        if pdf.get_y() > 240:
            pdf.add_page()
        pdf.feature_card(num, '', title, desc, argument)

    # ── Einzigartigkeit ─────────────────────────────────────────────────────────
    pdf.add_page()
    pdf.section_header(3, 'Was macht Parentpeak einzigartig?', TEAL)

    headers = ['Feature', 'Parentpeak', 'Andere Apps']
    rows = [
        ['KI-Beratung 24/7',       'Ja - GfK-Paedagogik',          'Nur FAQs'],
        ['Eltern-Netzwerk',         'Matching + Events',              'Facebook-Gruppen'],
        ['Lokaler Marktplatz',      'Verschenkmarkt',                 'Nicht vorhanden'],
        ['Mehrsprachig',            '10+ Sprachen',                   'Meist nur DE/EN'],
        ['Alles in einer App',      'Ja',                             'Viele separate Apps'],
        ['Datenschutz-Modus',       'Privacy-Modus integriert',       'Oft unklar'],
    ]

    col_w = [70, 65, 55]
    pdf.set_fill_color(*BLUE_DARK)
    pdf.set_text_color(*WHITE)
    pdf.set_font('Helvetica', 'B', 10)
    for i, h in enumerate(headers):
        pdf.cell(col_w[i], 9, h, border=1, fill=True)
    pdf.ln()

    for j, row in enumerate(rows):
        fill = j % 2 == 0
        pdf.set_fill_color(*GREY_BG) if fill else pdf.set_fill_color(*WHITE)
        pdf.set_text_color(*DARK_TEXT)
        pdf.set_font('Helvetica', '', 10)
        for i, cell in enumerate(row):
            pdf.cell(col_w[i], 8, cell, border=1, fill=True)
        pdf.ln()

    # ── Zielgruppen ─────────────────────────────────────────────────────────────
    pdf.ln(6)
    pdf.section_header(4, 'Zielgruppen', BLUE_LIGHT)

    pdf.sub_header('', 'Primäre Zielgruppe')
    for b in ['Eltern mit Kindern 0-10 Jahre (Kernzielgruppe)',
              'Alleinerziehende Eltern',
              'Eltern in neuen Städten ohne lokales Netzwerk',
              'Eltern mit Migrationshintergrund (Mehrsprachigkeit!)']:
        pdf.bullet(b)

    pdf.ln(2)
    pdf.sub_header('', 'Sekundäre Zielgruppe')
    for b in ['Pädagogen und Erzieher',
              'Großeltern als aktive Familienmitglieder',
              'Kursleiter (Events erstellen und monetarisieren)']:
        pdf.bullet(b)

    # ── 5 Argumente ─────────────────────────────────────────────────────────────
    pdf.add_page()
    pdf.section_header(5, 'Die 5 stärksten Argumente für Eltern', BLUE_DARK)

    args = [
        ('1', 'Sofortige Hilfe statt einsamer Suche',
         'Eltern googeln täglich nach Erziehungstipps und landen auf widersprüchlichen Ratgeberseiten. '
         'Mit Parentpeak tippen sie ihre Frage - und bekommen in Sekunden eine pädagogisch fundierte Antwort. '
         'Jederzeit. Kostenlos in der Testphase.'),
        ('2', 'Gemeinschaft statt Isolation',
         'Viele Eltern fühlen sich allein. Parentpeak verbindet sie mit echten Eltern in ihrer Nachbarschaft. '
         'Aus einem Match wird ein Spielplatzbesuch, aus einem Event wird eine Freundschaft.'),
        ('3', 'Nachhaltigkeit, die Spaß macht',
         'Der Verschenkmarkt ermöglicht es, Kindersachen sinnvoll weiterzugeben. '
         'Kostenlos, lokal, persönlich. Eltern lieben das.'),
        ('4', 'Eine App statt zehn',
         'Kalender, Checklisten, Ratgeber, Community, Events - alles getrennt? '
         'Mit Parentpeak ist das vorbei. Eine App. Alles drin.'),
        ('5', 'Vertrauen und Datenschutz',
         'Die App wurde von Anfang an datenschutzfreundlich entwickelt. '
         'Eltern entscheiden selbst, was sichtbar ist. Ein Privacy-Modus schützt sensible Familieninformationen.'),
    ]

    for num, title, desc in args:
        if pdf.get_y() > 240:
            pdf.add_page()
        y = pdf.get_y()
        pdf.set_fill_color(*BLUE_LIGHT)
        pdf.rect(10, y, 12, 12, 'F')
        pdf.set_font('Helvetica', 'B', 11)
        pdf.set_text_color(*WHITE)
        pdf.set_xy(10, y + 2)
        pdf.cell(12, 8, num, align='C')
        pdf.set_xy(24, y + 2)
        pdf.set_text_color(*BLUE_DARK)
        pdf.cell(170, 8, title)
        pdf.set_xy(10, y + 15)
        pdf.set_font('Helvetica', '', 10)
        pdf.set_text_color(*DARK_TEXT)
        pdf.multi_cell(190, 5, desc)
        pdf.ln(3)

    # ── Preismodell ─────────────────────────────────────────────────────────────
    pdf.add_page()
    pdf.section_header(6, 'Preismodell', TEAL)

    price_rows = [
        ['Kostenlose Testphase', '14 Tage - alle Funktionen freigeschaltet, keine Kreditkarte nötig'],
        ['Premium-Abo',          'Monatlich oder jährlich - voller Zugang zu allen Features'],
        ['Bezahlte Events',      'Für Kursleiter und Coaches - Zahlungsabwicklung über Stripe'],
    ]
    col_w2 = [60, 130]
    pdf.set_fill_color(*BLUE_DARK)
    pdf.set_text_color(*WHITE)
    pdf.set_font('Helvetica', 'B', 10)
    pdf.cell(col_w2[0], 9, 'Stufe', border=1, fill=True)
    pdf.cell(col_w2[1], 9, 'Details', border=1, fill=True)
    pdf.ln()

    for j, row in enumerate(price_rows):
        fill = j % 2 == 0
        pdf.set_fill_color(*GREY_BG) if fill else pdf.set_fill_color(*WHITE)
        pdf.set_text_color(*DARK_TEXT)
        pdf.set_font('Helvetica', '', 10)
        pdf.cell(col_w2[0], 9, row[0], border=1, fill=True)
        pdf.cell(col_w2[1], 9, row[1], border=1, fill=True)
        pdf.ln()

    pdf.ln(4)
    pdf.highlight_box(
        'Tipp: Die 14-tägige Testphase ist das stärkste Onboarding-Werkzeug. '
        'Eltern, die die App einmal benutzt haben, kennen den Wert sofort.'
    )

    # ── Marketing-Botschaften ───────────────────────────────────────────────────
    pdf.section_header(7, 'Empfohlene Marketing-Botschaften', BLUE_DARK)

    pdf.sub_header('', 'Hauptslogan-Ideen')
    slogans = [
        '"Parentpeak - Erziehung war noch nie so vernetzt."',
        '"Die App, die Eltern wirklich gebraucht haben."',
        '"Dein KI-Erziehungsberater. Deine lokale Elterngemeinschaft. Eine App."',
    ]
    for s in slogans:
        pdf.bullet(s)

    pdf.ln(4)
    pdf.sub_header('', 'Social Media - Instagram / TikTok')
    for s in [
        '3 Uhr nachts. Baby schreit. Du weißt nicht weiter. -> Parentpeak antwortet.',
        'Neue Stadt, keine Freunde, ein Kleinkind. -> Parentpeak-Matching hilft.',
        '500 Kinderkleidungsstücke, die niemand mehr braucht. -> Verschenkmarkt.',
    ]:
        pdf.bullet(s)

    pdf.ln(2)
    pdf.sub_header('', 'Facebook (Elterngruppen)')
    for s in [
        'Kostenlos 14 Tage alle Funktionen testen - keine Kreditkarte nötig.',
        'Welche Frage würdest du um 3 Uhr deinem KI-Erziehungsberater stellen?',
    ]:
        pdf.bullet(s)

    # ── Roadmap ─────────────────────────────────────────────────────────────────
    pdf.ln(4)
    pdf.section_header(8, 'Geplante Features (Roadmap)', TEAL)
    for b in [
        'Push-Benachrichtigungen für Events in der Nähe',
        'KI-generierte Wochenpläne für Familien',
        'Babysitter-Netzwerk (Vertrauenspersonen empfehlen)',
        'Kindergarten- und Schulratgeber mit KI-Unterstützung',
    ]:
        pdf.bullet(b)

    # ── Zusammenfassung ─────────────────────────────────────────────────────────
    pdf.add_page()
    pdf.set_fill_color(*BLUE_DARK)
    pdf.rect(0, 60, 210, 60, 'F')
    pdf.set_y(70)
    pdf.set_font('Helvetica', 'B', 14)
    pdf.set_text_color(*WHITE)
    pdf.cell(0, 10, 'Zusammenfassung in einem Satz:', align='C', ln=True)
    pdf.set_font('Helvetica', '', 12)
    pdf.set_x(20)
    pdf.multi_cell(170, 8,
        'Parentpeak ist die erste App, die Eltern sofortige KI-Beratung, ein lokales '
        'Familien-Netzwerk, einen Verschenkmarkt und vollständige Familienorganisation '
        'in einer einzigen, datenschutzfreundlichen Anwendung verbindet.',
        align='C')

    pdf.set_y(140)
    pdf.set_font('Helvetica', '', 10)
    pdf.set_text_color(*GREY_TEXT)
    pdf.cell(0, 7, 'Version 1.0  |  Juli 2026  |  Parentpeak', align='C')

    # ── Speichern ───────────────────────────────────────────────────────────────
    output = os.path.abspath(OUTPUT_PATH)
    pdf.output(output)
    print(f'PDF gespeichert: {output}')


if __name__ == '__main__':
    build_pdf()
