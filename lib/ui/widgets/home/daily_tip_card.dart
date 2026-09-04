import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tages-Tipp-Karte — ein kurzer, umsetzbarer Eltern-Tipp pro Tag.
///
/// Wechselt täglich, passend zur Altersphase aus dem Onboarding.
/// Tap öffnet optional den KI-Chat für mehr Details.
class DailyTipCard extends StatefulWidget {
  final void Function(String tipText)? onExpandTip;

  const DailyTipCard({super.key, this.onExpandTip});

  @override
  State<DailyTipCard> createState() => _DailyTipCardState();
}

class _DailyTipCardState extends State<DailyTipCard> {
  String _tip = '';
  String _category = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTip();
  }

  Future<void> _loadTip() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('onboarding.parent_role') ?? 'kleinkind';
    final tips = _tipsForRole(role);

    // Wähle Tipp basierend auf dem Tag des Jahres
    final dayOfYear = _dayOfYear(DateTime.now());
    final index = dayOfYear % tips.length;
    final selected = tips[index];

    if (mounted) {
      setState(() {
        _tip = selected.$1;
        _category = selected.$2;
        _loading = false;
      });
    }
  }

  int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays;
  }

  List<(String, String)> _tipsForRole(String role) {
    switch (role) {
      case 'neugeboren':
        return const [
          (
            'Halte dein Baby heute 5 Minuten mehr Hautkontakt. Das stärkt die Bindung nachweislich.',
            'Bindung'
          ),
          (
            'Sprich heute bei jeder Tätigkeit laut mit deinem Baby. Es lernt durch deine Stimme.',
            'Sprache'
          ),
          (
            'Leg dein Baby heute 3 Minuten auf den Bauch. Das stärkt Nacken und Rücken.',
            'Motorik'
          ),
          (
            'Summe oder singe heute ein Lied. Wiederholung gibt deinem Baby Sicherheit.',
            'Geborgenheit'
          ),
          (
            'Achte heute auf dich: 10 Minuten nur für dich, während Baby schläft.',
            'Selbstfürsorge'
          ),
          (
            'Zeige deinem Baby heute einen Gegenstand und benenne ihn langsam. Es speichert alles.',
            'Kognition'
          ),
          (
            'Massiere heute sanft die Füße deines Babys. Das fördert die Körperwahrnehmung.',
            'Sinne'
          ),
        ];
      case 'kleinkind':
        return const [
          (
            'Lass dein Kind heute eine kleine Entscheidung treffen: rotes oder blaues T-Shirt?',
            'Selbstständigkeit'
          ),
          (
            'Lest heute zusammen ein Bilderbuch — und lass dein Kind die Bilder beschreiben.',
            'Sprache'
          ),
          (
            'Baut heute zusammen einen Turm und werft ihn um. Wiederholung ist Lernen.',
            'Motorik'
          ),
          (
            'Sag heute 3x bewusst: "Ich sehe, dass du dir Mühe gibst." statt "Gut gemacht."',
            'Ermutigung'
          ),
          (
            'Geht heute barfuß durch den Garten oder Park. Verschiedene Böden = Sinnestraining.',
            'Sinne'
          ),
          (
            'Lass dein Kind heute beim Kochen helfen: umrühren, Gemüse waschen, Kräuter zupfen.',
            'Alltag'
          ),
          (
            'Spielt heute 5 Minuten Verstecken. Es lernt: Du kommst immer wieder.',
            'Vertrauen'
          ),
          (
            'Male heute mit deinem Kind mit den Fingern. Perfektion ist egal — der Spaß zählt.',
            'Kreativität'
          ),
          (
            'Sag heute Abend: "Was war dein schönstes Erlebnis heute?" Auch wenn die Antwort kurz ist.',
            'Reflexion'
          ),
          (
            'Lass dein Kind heute draußen Steine sammeln und nach Größe sortieren.',
            'Kognition'
          ),
        ];
      case 'schulkind':
        return const [
          (
            'Frag heute: "Was hat dich in der Schule überrascht?" statt "Wie war die Schule?"',
            'Kommunikation'
          ),
          (
            'Lass dein Kind heute eine Aufgabe komplett allein planen: Rucksack packen, Wecker stellen.',
            'Verantwortung'
          ),
          (
            'Spielt heute zusammen ein Brettspiel. Verlieren üben gehört dazu.',
            'Soziales'
          ),
          (
            'Gib heute ein echtes Kompliment für Anstrengung, nicht für das Ergebnis.',
            'Ermutigung'
          ),
          (
            'Kocht heute zusammen: Dein Kind darf das Rezept aussuchen und die Zutaten abmessen.',
            'Mathe im Alltag'
          ),
          (
            '10 Minuten gemeinsam lesen — jeder sein eigenes Buch, aber zusammen auf der Couch.',
            'Rituale'
          ),
          (
            'Frag heute: "Gibt es etwas, das dich gerade beschäftigt?" und höre nur zu.',
            'Vertrauen'
          ),
          (
            'Geht heute ohne Plan spazieren und lasst euer Kind die Route bestimmen.',
            'Autonomie'
          ),
          (
            'Zeig deinem Kind heute wie du ein Problem gelöst hast. Kinder lernen durch Vorbild.',
            'Vorbild'
          ),
          (
            'Lass dein Kind heute 30 Minuten komplett ohne Plan. Langeweile fördert Kreativität.',
            'Kreativität'
          ),
        ];
      case 'teenager':
        return const [
          (
            'Frag heute nicht "Wie war die Schule?" sondern "Was beschäftigt dich gerade?"',
            'Kommunikation'
          ),
          (
            'Respektiere heute bewusst eine Entscheidung deines Teenagers, auch wenn sie dir nicht gefällt.',
            'Respekt'
          ),
          (
            'Biete heute Hilfe an, aber akzeptiere ein "Nein" ohne nachzufragen.',
            'Autonomie'
          ),
          (
            'Erzähle heute von einem eigenen Fehler als Teenager. Das schafft Verbindung.',
            'Verletzlichkeit'
          ),
          (
            'Schicke heute eine kurze, liebevolle Nachricht. Ohne Frage, ohne Erwartung.',
            'Zuneigung'
          ),
          (
            'Lass heute das Handy-Thema ruhen. Ein Tag ohne Diskussion darüber.',
            'Frieden'
          ),
          (
            'Frag heute: "Kann ich etwas für dich tun?" und meine es ernst.',
            'Unterstützung'
          ),
          (
            'Höre heute einen Song deines Teenagers und frag, warum er/sie ihn mag.',
            'Interesse'
          ),
          (
            'Gib heute bewusst Raum. Manchmal ist Nähe = Abstand lassen.',
            'Vertrauen'
          ),
          (
            'Sag heute: "Ich bin stolz auf dich, einfach so." Ohne Grund, ohne Bedingung.',
            'Liebe'
          ),
        ];
      default:
        return const [
          (
            'Nimm dir heute 5 Minuten bewusste Zeit nur für dein Kind. Handy weg, Augen zu.',
            'Achtsamkeit'
          ),
          (
            'Sag heute einmal mehr "Ja" als "Nein". Schau was passiert.',
            'Positiv'
          ),
          (
            'Lache heute bewusst mit deinem Kind. Albern sein ist erlaubt.',
            'Freude'
          ),
          (
            'Frag heute: "Was brauchst du gerade von mir?" und höre zu.',
            'Verbindung'
          ),
          (
            'Gönn dir heute 10 Minuten nur für dich. Ohne schlechtes Gewissen.',
            'Selbstfürsorge'
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const SizedBox(height: 80);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0EA5A4).withValues(alpha: 0.08),
            const Color(0xFF0EA5A4).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF0EA5A4).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5A4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        size: 14, color: Color(0xFF0F766E)),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('daily_tip_title'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF0F766E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _category,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _tip,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onExpandTip != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => widget.onExpandTip?.call(_tip),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 15, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('daily_tip_explain'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
