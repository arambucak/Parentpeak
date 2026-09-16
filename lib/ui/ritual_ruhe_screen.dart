import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';

String ritualRuheText(String key, Locale locale) {
  const de = {
    'title': 'Ritual & Ruhe',
    'tileSubtitle': 'Ein ruhiger Moment für euren Familienalltag',
    'appBarNight': 'Gute Nacht',
    'appBarMorning': 'Guten Morgen',
    'sectionMorning': 'Morgen',
    'sectionAfternoon': 'Nachmittag',
    'sectionEvening': 'Abend',
    'your': 'Euer',
    'with': 'mit',
    'for': 'für',
    'years': 'Jahre',
    'welcomeNight': 'Zeit zum Runterkommen',
    'welcomeRelaxed': 'Ein kleiner, ruhiger Schritt nach dem anderen.',
    'welcomeQuestion': 'Was würde euch heute gut tun?',
    'quietMode': 'Ruhemodus',
    'close': 'Schließen',
    'editPlan': 'Bearbeiten',
    'suggestPlan': 'Vorschlag',
    'storyTitle': 'Eine Geschichte für heute',
    'storyHint': 'Eine ruhige Geschichte, passend für',
    'storyButtonNew': 'Neue Geschichte',
    'storyButtonGenerate': 'Geschichte erzählen',
    'gratitudeTitle': 'Ein guter Moment',
    'gratitudeHint': 'Heute war schön, dass …',
    'gratitudePlaceholder': 'Ein kleiner Satz genügt',
    'timerStart': 'Ruhiger Timer starten',
    'timerDone': 'Geschafft',
    'allDone': 'Für heute ist genug geschafft. Jetzt darf Ruhe kommen.',
    'timerBanner': 'Ruhiger Timer',
    'emptyTitle': 'Noch kein Kinderprofil',
    'emptyDescription':
        'Sobald ein Kinderprofil angelegt ist, kann ParentPeak die Rituale altersgerecht begleiten.',
    'emptyAction': 'Zum Familienprofil',
    'nightSectionTitle': 'Euer Abendmoment',
    'timeCardSubtitle': 'Nichts muss perfekt sein. Nehmt, was heute passt.',
  };

  const en = {
    'title': 'Ritual & Calm',
    'tileSubtitle': 'A calm moment for everyday family life',
    'appBarNight': 'Good night',
    'appBarMorning': 'Good morning',
    'sectionMorning': 'Morning',
    'sectionAfternoon': 'Afternoon',
    'sectionEvening': 'Evening',
    'your': 'Your',
    'with': 'with',
    'for': 'for',
    'years': 'years',
    'welcomeNight': 'Time to wind down',
    'welcomeRelaxed': 'One gentle step after another.',
    'welcomeQuestion': 'What would feel good today?',
    'quietMode': 'Quiet mode',
    'close': 'Close',
    'editPlan': 'Edit',
    'suggestPlan': 'Suggestion',
    'storyTitle': 'A story for today',
    'storyHint': 'A calm story for',
    'storyButtonNew': 'New story',
    'storyButtonGenerate': 'Tell a story',
    'gratitudeTitle': 'A good moment',
    'gratitudeHint': 'Today was nice because…',
    'gratitudePlaceholder': 'A little sentence is enough',
    'timerStart': 'Start calm timer',
    'timerDone': 'Done',
    'allDone': 'That is enough for today. Now it is time for calm.',
    'timerBanner': 'Calm timer',
    'emptyTitle': 'No child profile yet',
    'emptyDescription':
        'Once a child profile is created, ParentPeak can support the rituals in an age-appropriate way.',
    'emptyAction': 'To family profile',
    'nightSectionTitle': 'Your evening moment',
    'timeCardSubtitle': 'Nothing has to be perfect. Take what fits today.',
  };

  const tr = {
    'title': 'Ritüel & Huzur',
    'tileSubtitle': 'Aile hayatı için sakin bir an',
    'appBarNight': 'İyi geceler',
    'appBarMorning': 'Günaydın',
    'sectionMorning': 'Sabah',
    'sectionAfternoon': 'Öğlen',
    'sectionEvening': 'Akşam',
    'your': 'Sizin',
    'with': 'ile',
    'for': 'için',
    'years': 'yaş',
    'welcomeNight': 'Yumuşamaya zaman',
    'welcomeRelaxed': 'Küçük, sakin adımlarla.',
    'welcomeQuestion': 'Bugün size ne iyi gelir?',
    'quietMode': 'Sessiz mod',
    'close': 'Kapat',
    'editPlan': 'Düzenle',
    'suggestPlan': 'Öneri',
    'storyTitle': 'Bugün için hikâye',
    'storyHint': 'Sakin, uygun bir hikâye için',
    'storyButtonNew': 'Yeni hikâye',
    'storyButtonGenerate': 'Hikâye anlat',
    'gratitudeTitle': 'İyi bir an',
    'gratitudeHint': 'Bugün güzeldi çünkü…',
    'gratitudePlaceholder': 'Kısa bir cümle yeter',
    'timerStart': 'Sakin zamanlayıcı başlat',
    'timerDone': 'Tamam',
    'allDone': 'Bugün için yeter. Şimdi huzur zamanı.',
    'timerBanner': 'Sakin zamanlayıcı',
    'emptyTitle': 'Henüz çocuk profili yok',
    'emptyDescription':
        'Çocuk profili oluşturulunca ParentPeak ritüelleri yaşa uygun şekilde destekleyebilir.',
    'emptyAction': 'Aile profiline',
    'nightSectionTitle': 'Akşam anınız',
    'timeCardSubtitle': 'Hiçbir şey mükemmel olmak zorunda değil. Bugün ne uygunsa onu alın.',
  };

  const ku = {
    'title': 'Rîtuel û Aramî',
    'tileSubtitle': 'Demek aram û baş ji bo jiyana malbatê',
    'appBarNight': 'Şev baş',
    'appBarMorning': 'Rojbaş',
    'sectionMorning': 'Roj',
    'sectionAfternoon': 'Nîvro',
    'sectionEvening': 'Êvar',
    'your': 'Ya we',
    'with': 'bi',
    'for': 'ji bo',
    'years': 'sal',
    'welcomeNight': 'Demê ku bi aramî tê şikestin',
    'welcomeRelaxed': 'Yek gavê aram piştî ya din.',
    'welcomeQuestion': 'Îro çi ji we re baş dibe?',
    'quietMode': 'Moda aram',
    'close': 'Bigire',
    'editPlan': 'Saz bike',
    'suggestPlan': 'Pêşniyar',
    'storyTitle': 'Çîrokek ji bo îro',
    'storyHint': 'Çîrokek aram, li gorî',
    'storyButtonNew': 'Çîrokek nû',
    'storyButtonGenerate': 'Çîrokê bêje',
    'gratitudeTitle': 'Dema baş',
    'gratitudeHint': 'Îro baş bû ji ber ku…',
    'gratitudePlaceholder': 'Kurteyek têra xwe ye',
    'timerStart': 'Timerê aram dest pê bike',
    'timerDone': 'Qediya',
    'allDone': 'Ji bo îro têra xwe ye. Niha demê aramî ye.',
    'timerBanner': 'Timerê aram',
    'emptyTitle': 'Hîn profîla zarokê tune ye',
    'emptyDescription':
        'Carekê profîla zarokê were afirandin, ParentPeak dikare rîtuelan li gorî temenê wan bi rê ve bibe.',
    'emptyAction': 'Berbi profîla malbatê',
    'nightSectionTitle': 'Dema êvarê ya we',
    'timeCardSubtitle': 'Tiştek ne hewce ye ku bêkêmasî be. Ya ku îro li gorî we ye bigirin.',
  };

  const ar = {
    'title': 'طقوس وهدوء',
    'tileSubtitle': 'لحظة هادئة في يوم عائلتكم',
    'appBarNight': 'تصبحون على خير',
    'appBarMorning': 'صباح الخير',
    'sectionMorning': 'الصباح',
    'sectionAfternoon': 'بعد الظهر',
    'sectionEvening': 'المساء',
    'your': 'وقتكم', 'with': 'مع', 'for': 'لـ', 'years': 'سنوات',
    'welcomeNight': 'حان وقت الهدوء',
    'welcomeRelaxed': 'خطوة صغيرة وهادئة في كل مرة.',
    'welcomeQuestion': 'ما الذي قد يمنحكم شعوراً طيباً اليوم؟',
    'quietMode': 'وضع الهدوء', 'close': 'إغلاق', 'editPlan': 'تعديل',
    'suggestPlan': 'اقتراح', 'storyTitle': 'حكاية لهذا اليوم',
    'storyHint': 'حكاية هادئة تناسب', 'storyButtonNew': 'حكاية جديدة',
    'storyButtonGenerate': 'احكِ حكاية', 'gratitudeTitle': 'لحظة جميلة',
    'gratitudeHint': 'كان اليوم جميلاً لأن...',
    'gratitudePlaceholder': 'تكفي جملة صغيرة',
    'timerStart': 'بدء مؤقت هادئ', 'timerDone': 'تم',
    'allDone': 'هذا يكفي لليوم. الآن حان وقت الهدوء.',
    'timerBanner': 'مؤقت هادئ', 'emptyTitle': 'لا يوجد ملف للطفل بعد',
    'emptyDescription': 'بعد إنشاء ملف للطفل، يمكن لـ ParentPeak مرافقة الطقوس بما يناسب عمره.',
    'emptyAction': 'إلى ملف العائلة', 'nightSectionTitle': 'لحظة المساء الخاصة بكم',
    'timeCardSubtitle': 'ليس كل شيء بحاجة إلى أن يكون مثالياً. اختاروا ما يناسبكم اليوم.',
  };

  const ru = {
    'title': 'Ритуалы и покой', 'tileSubtitle': 'Спокойный момент в семейном дне',
    'appBarNight': 'Спокойной ночи', 'appBarMorning': 'Доброе утро',
    'sectionMorning': 'Утро', 'sectionAfternoon': 'День', 'sectionEvening': 'Вечер',
    'your': 'Ваш', 'with': 'с', 'for': 'для', 'years': 'лет',
    'welcomeNight': 'Время замедлиться', 'welcomeRelaxed': 'Один маленький спокойный шаг за другим.',
    'welcomeQuestion': 'Что помогло бы вам сегодня почувствовать себя лучше?',
    'quietMode': 'Тихий режим', 'close': 'Закрыть', 'editPlan': 'Изменить',
    'suggestPlan': 'Предложение', 'storyTitle': 'История на сегодня',
    'storyHint': 'Спокойная история для', 'storyButtonNew': 'Новая история',
    'storyButtonGenerate': 'Рассказать историю', 'gratitudeTitle': 'Хороший момент',
    'gratitudeHint': 'Сегодня было хорошо, потому что...',
    'gratitudePlaceholder': 'Достаточно одной короткой фразы',
    'timerStart': 'Запустить спокойный таймер', 'timerDone': 'Готово',
    'allDone': 'На сегодня достаточно. Теперь можно отдохнуть.',
    'timerBanner': 'Спокойный таймер', 'emptyTitle': 'Профиля ребёнка пока нет',
    'emptyDescription': 'Когда вы создадите профиль ребёнка, ParentPeak сможет поддерживать ритуалы с учётом возраста.',
    'emptyAction': 'К семейному профилю', 'nightSectionTitle': 'Ваш вечерний момент',
    'timeCardSubtitle': 'Не обязательно делать всё идеально. Выберите то, что подходит вам сегодня.',
  };

  const uk = {
    'title': 'Ритуали та спокій', 'tileSubtitle': 'Тиха мить у вашому сімейному дні',
    'appBarNight': 'На добраніч', 'appBarMorning': 'Доброго ранку',
    'sectionMorning': 'Ранок', 'sectionAfternoon': 'Після обіду', 'sectionEvening': 'Вечір',
    'your': 'Ваш', 'with': 'з', 'for': 'для', 'years': 'років',
    'welcomeNight': 'Час сповільнитися', 'welcomeRelaxed': 'Один маленький спокійний крок за раз.',
    'welcomeQuestion': 'Що могло б підтримати вас сьогодні?',
    'quietMode': 'Тихий режим', 'close': 'Закрити', 'editPlan': 'Змінити',
    'suggestPlan': 'Пропозиція', 'storyTitle': 'Історія на сьогодні',
    'storyHint': 'Спокійна історія для', 'storyButtonNew': 'Нова історія',
    'storyButtonGenerate': 'Розповісти історію', 'gratitudeTitle': 'Добра мить',
    'gratitudeHint': 'Сьогодні було добре, бо...',
    'gratitudePlaceholder': 'Достатньо короткого речення',
    'timerStart': 'Запустити тихий таймер', 'timerDone': 'Готово',
    'allDone': 'На сьогодні досить. Тепер час для спокою.',
    'timerBanner': 'Тихий таймер', 'emptyTitle': 'Профілю дитини ще немає',
    'emptyDescription': 'Коли ви створите профіль дитини, ParentPeak зможе підтримати ритуали відповідно до віку.',
    'emptyAction': 'До сімейного профілю', 'nightSectionTitle': 'Ваша вечірня мить',
    'timeCardSubtitle': 'Не все має бути ідеальним. Оберіть те, що підходить вам сьогодні.',
  };

  const es = {
    'title': 'Rituales y calma', 'tileSubtitle': 'Un momento tranquilo para el día a día en familia',
    'appBarNight': 'Buenas noches', 'appBarMorning': 'Buenos días',
    'sectionMorning': 'Mañana', 'sectionAfternoon': 'Tarde', 'sectionEvening': 'Noche',
    'your': 'Vuestro', 'with': 'con', 'for': 'para', 'years': 'años',
    'welcomeNight': 'Es hora de bajar el ritmo', 'welcomeRelaxed': 'Un pequeño paso tranquilo cada vez.',
    'welcomeQuestion': '¿Qué os vendría bien hoy?', 'quietMode': 'Modo calma',
    'close': 'Cerrar', 'editPlan': 'Editar', 'suggestPlan': 'Sugerencia',
    'storyTitle': 'Un cuento para hoy', 'storyHint': 'Un cuento tranquilo para',
    'storyButtonNew': 'Nuevo cuento', 'storyButtonGenerate': 'Contar un cuento',
    'gratitudeTitle': 'Un buen momento', 'gratitudeHint': 'Hoy ha sido bonito porque...',
    'gratitudePlaceholder': 'Basta con una frase pequeña', 'timerStart': 'Iniciar temporizador tranquilo',
    'timerDone': 'Listo', 'allDone': 'Por hoy es suficiente. Ahora toca descansar.',
    'timerBanner': 'Temporizador tranquilo', 'emptyTitle': 'Aún no hay perfil infantil',
    'emptyDescription': 'Cuando creéis un perfil infantil, ParentPeak podrá acompañar los rituales según su edad.',
    'emptyAction': 'Ir al perfil familiar', 'nightSectionTitle': 'Vuestro momento de la noche',
    'timeCardSubtitle': 'Nada tiene que ser perfecto. Elegid lo que encaje hoy.',
  };

  const fr = {
    'title': 'Rituels et calme', 'tileSubtitle': 'Un moment de calme dans votre quotidien familial',
    'appBarNight': 'Bonne nuit', 'appBarMorning': 'Bonjour',
    'sectionMorning': 'Matin', 'sectionAfternoon': 'Après-midi', 'sectionEvening': 'Soir',
    'your': 'Votre', 'with': 'avec', 'for': 'pour', 'years': 'ans',
    'welcomeNight': 'C’est le moment de ralentir', 'welcomeRelaxed': 'Un petit pas tout doux après l’autre.',
    'welcomeQuestion': 'Qu’est-ce qui vous ferait du bien aujourd’hui ?',
    'quietMode': 'Mode calme', 'close': 'Fermer', 'editPlan': 'Modifier',
    'suggestPlan': 'Suggestion', 'storyTitle': 'Une histoire pour aujourd’hui',
    'storyHint': 'Une histoire toute douce pour', 'storyButtonNew': 'Nouvelle histoire',
    'storyButtonGenerate': 'Raconter une histoire', 'gratitudeTitle': 'Un joli moment',
    'gratitudeHint': 'Aujourd’hui était une belle journée parce que...',
    'gratitudePlaceholder': 'Une petite phrase suffit', 'timerStart': 'Lancer le minuteur calme',
    'timerDone': 'Terminé', 'allDone': 'C’est assez pour aujourd’hui. Place au calme.',
    'timerBanner': 'Minuteur calme', 'emptyTitle': 'Pas encore de profil enfant',
    'emptyDescription': 'Dès qu’un profil enfant est créé, ParentPeak peut accompagner les rituels selon son âge.',
    'emptyAction': 'Vers le profil familial', 'nightSectionTitle': 'Votre moment du soir',
    'timeCardSubtitle': 'Rien ne doit être parfait. Gardez ce qui vous convient aujourd’hui.',
  };

  const it = {
    'title': 'Rituali e calma', 'tileSubtitle': 'Un momento di calma nella vita di famiglia',
    'appBarNight': 'Buonanotte', 'appBarMorning': 'Buongiorno',
    'sectionMorning': 'Mattina', 'sectionAfternoon': 'Pomeriggio', 'sectionEvening': 'Sera',
    'your': 'Il vostro', 'with': 'con', 'for': 'per', 'years': 'anni',
    'welcomeNight': 'È il momento di rallentare', 'welcomeRelaxed': 'Un piccolo passo alla volta, con calma.',
    'welcomeQuestion': 'Cosa vi farebbe stare bene oggi?', 'quietMode': 'Modalità calma',
    'close': 'Chiudi', 'editPlan': 'Modifica', 'suggestPlan': 'Suggerimento',
    'storyTitle': 'Una storia per oggi', 'storyHint': 'Una storia tranquilla per',
    'storyButtonNew': 'Nuova storia', 'storyButtonGenerate': 'Racconta una storia',
    'gratitudeTitle': 'Un bel momento', 'gratitudeHint': 'Oggi è stato bello perché...',
    'gratitudePlaceholder': 'Basta una piccola frase', 'timerStart': 'Avvia il timer della calma',
    'timerDone': 'Fatto', 'allDone': 'Per oggi va bene così. Ora è tempo di calma.',
    'timerBanner': 'Timer della calma', 'emptyTitle': 'Nessun profilo bambino ancora',
    'emptyDescription': 'Quando creerete un profilo bambino, ParentPeak potrà accompagnare i rituali in base all’età.',
    'emptyAction': 'Al profilo famiglia', 'nightSectionTitle': 'Il vostro momento della sera',
    'timeCardSubtitle': 'Non deve essere tutto perfetto. Scegliete ciò che va bene oggi.',
  };

  const pt = {
    'title': 'Rituais e calma', 'tileSubtitle': 'Um momento de calma no dia a dia da família',
    'appBarNight': 'Boa noite', 'appBarMorning': 'Bom dia',
    'sectionMorning': 'Manhã', 'sectionAfternoon': 'Tarde', 'sectionEvening': 'Noite',
    'your': 'O vosso', 'with': 'com', 'for': 'para', 'years': 'anos',
    'welcomeNight': 'É hora de abrandar', 'welcomeRelaxed': 'Um pequeno passo tranquilo de cada vez.',
    'welcomeQuestion': 'O que vos faria bem hoje?', 'quietMode': 'Modo de calma',
    'close': 'Fechar', 'editPlan': 'Editar', 'suggestPlan': 'Sugestão',
    'storyTitle': 'Uma história para hoje', 'storyHint': 'Uma história tranquila para',
    'storyButtonNew': 'Nova história', 'storyButtonGenerate': 'Contar uma história',
    'gratitudeTitle': 'Um bom momento', 'gratitudeHint': 'Hoje foi bom porque...',
    'gratitudePlaceholder': 'Uma frase pequenina basta', 'timerStart': 'Iniciar temporizador de calma',
    'timerDone': 'Concluído', 'allDone': 'Por hoje é suficiente. Agora é tempo de calma.',
    'timerBanner': 'Temporizador de calma', 'emptyTitle': 'Ainda não existe um perfil de criança',
    'emptyDescription': 'Quando criarem um perfil de criança, o ParentPeak poderá acompanhar os rituais de acordo com a idade.',
    'emptyAction': 'Ir para o perfil da família', 'nightSectionTitle': 'O vosso momento da noite',
    'timeCardSubtitle': 'Nada tem de ser perfeito. Escolham o que resulta hoje.',
  };

  final map = switch (locale.languageCode) {
    'en' => en,
    'tr' => tr,
    'ku' => ku,
    'ar' => ar,
    'ru' => ru,
    'uk' => uk,
    'es' => es,
    'fr' => fr,
    'it' => it,
    'pt' => pt,
    _ => de,
  };

  return map[key] ?? de[key] ?? key;
}

class RitualRuheScreen extends StatefulWidget {
  const RitualRuheScreen({super.key});

  @override
  State<RitualRuheScreen> createState() => _RitualRuheScreenState();
}

class _RitualRuheScreenState extends State<RitualRuheScreen> {
  static const _quietModeKey = 'ritual_ruhe.quiet_mode';
  static const _plansKey = 'ritual_ruhe.plans.v2';
  final _gratitudeController = TextEditingController();
  List<KindDossier> _children = const [];
  int _selectedChild = 0;
  Set<String> _completed = <String>{};
  bool _quietMode = false;
  bool _loading = true;
  bool _storyLoading = false;
  String? _story;
  String? _ageNotice;
  Timer? _ritualTimer;
  int _secondsRemaining = 0;
  String _selectedSection = 'morning';
  Map<String, Map<String, _RitualPlan>> _plans = {};
  bool _planLoading = false;

  bool get _isEvening {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  bool get _isNightSection => _selectedSection == 'night';
  Locale get _locale => Localizations.localeOf(context);

  String get _sectionTitle => switch (_selectedSection) {
        'afternoon' => ritualRuheText('sectionAfternoon', _locale),
        'night' => ritualRuheText('appBarNight', _locale),
        _ => ritualRuheText('sectionMorning', _locale),
      };

  KindDossier? get _child => _children.isEmpty
      ? null
      : _children[_selectedChild.clamp(0, _children.length - 1)];

  int get _ageMonths => _child?.ageMonths ?? 60;
  int get _ageYears => (_ageMonths / 12).floor();
  String get _ageVariantLabel {
    if (_ageYears < 5) return '2–5 Jahre: Bild- und Bewegungskarten';
    if (_ageYears < 8) return '5–7 Jahre: Bild + kurzer Satz';
    if (_ageYears < 11) return '6–10 Jahre: Tagesplaner';
    return '10–14 Jahre: Selbstplanung & Reflexion';
  }

  String get _suggestionLabel =>
      '${ritualRuheText('suggestPlan', _locale)} ${ritualRuheText('for', _locale)} $_ageYears ${ritualRuheText('years', _locale)}, $_sectionTitle';

  _RitualPlan? get _customPlan =>
      _plans[_child?.childName ?? '']?[_selectedSection];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ritualTimer?.cancel();
    _gratitudeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await KindDossierService.instance.load();
    var children = KindDossierService.instance.dossiers;
    if (children.isEmpty) {
      final profile = await FamilyMatchProfile.load();
      children = profile?.children
              .map((child) => KindDossier(
                    childName: child.name,
                    birthDate: child.birthDate,
                    ageMonths: child.ageMonths,
                  ))
              .toList() ??
          const [];
    }
    if (children.isEmpty) {
      // Legacy fallback: children added via the "Eure Kinder" profile section
      // before it synced with `KindDossierService` may only exist here.
      final saved = prefs.getStringList('profile.children') ?? [];
      children = saved
          .map((raw) => raw.split('|'))
          .where((parts) => parts.length >= 2 && parts[0].trim().isNotEmpty)
          .map((parts) {
            final years = int.tryParse(RegExp(r'\d+')
                    .firstMatch(parts[1])
                    ?.group(0) ??
                '');
            return KindDossier(
              childName: parts[0],
              ageMonths: years != null ? years * 12 : null,
            );
          })
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _children = children;
      _quietMode = prefs.getBool(_quietModeKey) ?? false;
      _loading = false;
    });
    _selectedSection = _isEvening
        ? 'night'
        : DateTime.now().hour < 12
            ? 'morning'
            : 'afternoon';
    await _loadPlans();
    final ageKey = 'ritual_ruhe.age.${_child?.childName ?? 'family'}';
    final previousAge = prefs.getInt(ageKey);
    final currentAge = _child?.ageYears ?? 0;
    if (previousAge != null && previousAge != currentAge && mounted) {
      setState(() => _ageNotice =
          '${_child?.childName ?? 'Euer Kind'} ist jetzt $currentAge — mögt ihr die Rituale gemeinsam anpassen?');
    }
    await prefs.setInt(ageKey, currentAge);
    await _loadChildState();
  }

  String get _stateKey =>
      'ritual_ruhe.state.${_child?.childName ?? 'family'}.${DateTime.now().toIso8601String().substring(0, 10)}';

  Future<void> _loadChildState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    final state = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _completed = (state['completed'] as List? ?? []).cast<String>().toSet();
      _gratitudeController.text = state['gratitude']?.toString() ?? '';
      _story = state['story']?.toString();
    });
  }

  Future<void> _loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plansKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _plans = decoded.map((child, sections) {
        final sectionMap = sections is Map ? sections : <String, dynamic>{};
        return MapEntry(
            child,
            sectionMap.map((section, plan) => MapEntry(
                  section,
                  _RitualPlan.fromJson(Map<String, dynamic>.from(plan as Map)),
                )));
      });
    } catch (_) {
      _plans = {};
    }
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _plansKey,
      jsonEncode(_plans.map((child, sections) => MapEntry(
            child,
            sections.map((section, plan) => MapEntry(section, plan.toJson())),
          ))),
    );
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _stateKey,
        jsonEncode({
          'completed': _completed.toList(),
          'gratitude': _gratitudeController.text.trim(),
          if (_story != null) 'story': _story,
        }));
  }

  List<_RitualStep> get _steps {
    if (_selectedSection == 'morning') {
      return _customPlan?.steps ??
          [
            const _RitualStep('aufstehen', 'Guten Morgen',
                Icons.wb_sunny_rounded, 'Langsam ankommen'),
            const _RitualStep('anziehen', 'Anziehen', Icons.checkroom_rounded,
                'Etwas Bequemes finden'),
            const _RitualStep('fruehstueck', 'Frühstück',
                Icons.breakfast_dining_rounded, 'Gemeinsam in den Tag starten'),
            const _RitualStep('tasche', 'Bereit für den Tag',
                Icons.backpack_rounded, 'Was brauchen wir heute?'),
          ];
    }
    if (_selectedSection == 'afternoon') {
      return _customPlan?.steps ??
          [
            const _RitualStep('ankommen', 'Ankommen', Icons.home_rounded,
                'Schuhe aus, erst einmal ankommen'),
            const _RitualStep('snack', 'Kleine Pause', Icons.local_cafe_rounded,
                'Etwas trinken und durchatmen'),
            const _RitualStep('spielen', 'Freie Zeit', Icons.toys_rounded,
                'Was tut euch jetzt gut?'),
          ];
    }
    if (!_isNightSection) {
      return [
        const _RitualStep('aufstehen', 'Guten Morgen', Icons.wb_sunny_rounded,
            'Langsam ankommen'),
        const _RitualStep('anziehen', 'Anziehen', Icons.checkroom_rounded,
            'Etwas Bequemes finden'),
        const _RitualStep('fruehstueck', 'Frühstück',
            Icons.breakfast_dining_rounded, 'Gemeinsam in den Tag starten'),
        const _RitualStep('tasche', 'Bereit für den Tag',
            Icons.backpack_rounded, 'Was brauchen wir heute?'),
      ];
    }
    if (_ageYears < 5) {
      return [
        const _RitualStep('waschen', 'Waschen', Icons.water_drop_rounded,
            'Gesicht und Hände werden ruhig'),
        const _RitualStep('zaehne', 'Zähne putzen', Icons.clean_hands_rounded,
            'Kleine Kreise, ganz in Ruhe'),
        const _RitualStep('kuscheln', 'Kuscheln', Icons.favorite_rounded,
            'Noch ein lieber Moment'),
      ];
    }
    if (_ageYears < 8) {
      return [
        const _RitualStep('waschen', 'Waschen', Icons.water_drop_rounded,
            'Frisch und gemütlich werden'),
        const _RitualStep('zaehne', 'Zähne putzen', Icons.clean_hands_rounded,
            'Der Mund bekommt seine Nachtpflege'),
        const _RitualStep('morgen', 'Für morgen vorbereiten',
            Icons.checkroom_rounded, 'Lieblingskleidung bereitlegen'),
        const _RitualStep('geschichte', 'Geschichte aussuchen',
            Icons.auto_stories_rounded, 'Eine ruhige Geschichte wartet'),
      ];
    }
    if (_ageYears < 11) {
      return [
        const _RitualStep('zaehne', 'Zähne putzen', Icons.clean_hands_rounded,
            'In Ruhe fertig werden'),
        const _RitualStep('morgen', 'Morgen vorbereiten',
            Icons.backpack_rounded, 'Tasche und Kleidung bereitlegen'),
        const _RitualStep('aufräumen', 'Kurz Ordnung schaffen',
            Icons.auto_awesome_rounded, 'Ein kleiner Handgriff für morgen'),
        const _RitualStep('reflexion', 'Tagesmoment',
            Icons.chat_bubble_outline_rounded, 'Was war heute gut?'),
      ];
    }
    return [
      const _RitualStep('morgen', 'Morgen vorbereiten', Icons.backpack_rounded,
          'Tasche, Kleidung und Wecker'),
      const _RitualStep('abschluss', 'Tag abschließen', Icons.nightlight_round,
          'Was darf für heute losgelassen werden?'),
      const _RitualStep('reflexion', 'Ein guter Moment',
          Icons.favorite_border_rounded, 'Ein Satz für dich selbst'),
    ];
  }

  Future<void> _toggleStep(String id) async {
    setState(() {
      if (!_completed.remove(id)) _completed.add(id);
    });
    await _saveState();
  }

  Future<void> _selectSection(String section) async {
    setState(() {
      _selectedSection = section;
      _completed = <String>{};
    });
    await _loadChildState();
  }

  Future<void> _suggestPlan() async {
    final child = _child;
    if (child == null || _planLoading || _selectedSection == 'night') return;
    setState(() => _planLoading = true);
    _RitualPlan plan;
    try {
      final response = await GeminiAIService().generateText(
        'Erstelle eine kurze Ritualvorlage für ein Kind im Alter von $_ageYears Jahren. Tageszeit: $_sectionTitle. Liefere ausschließlich JSON mit name, time, weekdays und steps. steps ist eine Liste aus title, subtitle, icon und timerSeconds. Maximal 6 Schritte. Keine Namen und keine persönlichen Daten.',
        systemInstruction:
            'Du bist eine pädagogische, inklusive Familienbegleitung. Erstelle sanfte, realistische und druckfreie Rituale. Nutze nur JSON, keine Markdown-Zeichen. Keine Punkte, Streaks, Strafen oder Leistungsdruck.',
        appLanguage: 'de',
      );
      plan = _RitualPlan.fromJson(jsonDecode(response));
    } catch (_) {
      plan = _fallbackPlan(_selectedSection, _ageYears);
    }
    if (!mounted) return;
    await _editPlan(plan);
    if (mounted) setState(() => _planLoading = false);
  }

  _RitualPlan _fallbackPlan(String section, int ageYears) => _RitualPlan(
        name:
            section == 'morning' ? 'Sanfter Morgen' : 'Ankommen am Nachmittag',
        time: section == 'morning' ? '07:30' : '15:30',
        weekdays: [1, 2, 3, 4, 5],
        steps: section == 'morning'
            ? [
                const _RitualStep('wake', 'Aufwachen', Icons.wb_sunny_rounded,
                    'Langsam in den Tag finden'),
                const _RitualStep('dress', 'Anziehen', Icons.checkroom_rounded,
                    'Bequeme Kleidung auswählen'),
                const _RitualStep('breakfast', 'Frühstück',
                    Icons.breakfast_dining_rounded, 'Gemeinsam starten'),
              ]
            : [
                const _RitualStep('arrive', 'Ankommen', Icons.home_rounded,
                    'Erst einmal durchatmen'),
                const _RitualStep('pause', 'Pause', Icons.local_cafe_rounded,
                    'Trinken, snacken, entspannen'),
              ],
      );

  Future<void> _editPlan(_RitualPlan initial) async {
    final edited = await showModalBottomSheet<_RitualPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RitualPlanEditor(initial: initial, title: _sectionTitle),
    );
    if (edited == null || _child == null) return;
    setState(() {
      _plans[_child!.childName] ??= {};
      _plans[_child!.childName]![_selectedSection] = edited;
    });
    await _savePlans();
  }

  Future<void> _toggleQuietMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quietModeKey, value);
    if (mounted) setState(() => _quietMode = value);
  }

  void _startTimer() {
    _ritualTimer?.cancel();
    setState(() => _secondsRemaining = 120);
    _ritualTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _timerLabel {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatTimer(int seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes == 0) return '0:${remainder.toString().padLeft(2, '0')}';
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _generateStory() async {
    final child = _child;
    if (child == null || _storyLoading) return;
    setState(() => _storyLoading = true);
    try {
      final story = await GeminiAIService().generateText(
        'Schreibe eine kurze Gute-Nacht-Geschichte für ein Kind, etwa $_ageYears Jahre alt. Thema: Mut, Geborgenheit und ein kleiner freundlicher Moment. 350 bis 500 Wörter. Verwende keine Namen und keine persönlichen Daten.',
        systemInstruction:
            'Du bist eine ruhige, inklusive Kinderbuchautorin. Schreibe warm, beruhigend und altersgerecht auf Deutsch. Keine Angst, Gewalt, Diagnosen oder Leistungsdruck. Gib nur die Geschichte zurück, ohne Überschrift oder Erklärung.',
        appLanguage: 'de',
      );
      if (mounted) setState(() => _story = story.trim());
    } catch (_) {
      if (mounted) setState(() => _story = _fallbackStory(child.childName));
    } finally {
      if (mounted) {
        setState(() => _storyLoading = false);
        await _saveState();
      }
    }
  }

  String _fallbackStory(String name) =>
      'Als ${name.isEmpty ? 'ein Kind' : name} am Abend aus dem Fenster schaute, sah es einen kleinen Stern, der besonders freundlich funkelte. Der Stern erinnerte ${name.isEmpty ? 'das Kind' : name} daran, dass jeder Tag kleine gute Momente trägt: ein Lächeln, eine warme Hand und ein Zuhause, in dem man einfach sein darf.\n\nDer Wind flüsterte: „Für heute ist genug geschafft.“ ${name.isEmpty ? 'Das Kind' : name} kuschelte sich ein. Der Stern blieb noch ein wenig am Fenster und passte auf. Dann wurde alles still und weich, bis der neue Morgen kam.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = _child;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        title: Text(_isEvening
            ? ritualRuheText('appBarNight', _locale)
            : ritualRuheText('appBarMorning', _locale)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: ritualRuheText('quietMode', _locale),
            onPressed: () => _toggleQuietMode(!_quietMode),
            icon: Icon(_quietMode
                ? Icons.notifications_off_rounded
                : Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : child == null
              ? _EmptyChildState(onOpenProfile: () => Navigator.pop(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                  children: [
                    if (_ageNotice != null) _buildAgeNotice(theme),
                    if (_children.length > 1) _buildChildSwitcher(theme),
                    _buildSectionPicker(theme),
                    _buildWelcome(theme, child),
                    const SizedBox(height: 18),
                    _buildRitualCard(theme),
                    if (_isNightSection) ...[
                      const SizedBox(height: 16),
                      _buildStoryCard(theme, child),
                      const SizedBox(height: 16),
                      _buildGratitudeCard(theme),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSectionPicker(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'morning',
                label: Text(ritualRuheText('sectionMorning', _locale)),
                icon: const Icon(Icons.wb_sunny_rounded)),
            ButtonSegment(
                value: 'afternoon',
                label: Text(ritualRuheText('sectionAfternoon', _locale)),
                icon: const Icon(Icons.wb_twilight_rounded)),
            ButtonSegment(
                value: 'night',
                label: Text(ritualRuheText('sectionEvening', _locale)),
                icon: const Icon(Icons.nightlight_round)),
          ],
          selected: {_selectedSection},
          onSelectionChanged: (value) => _selectSection(value.first),
        ),
      );

  Widget _buildChildSwitcher(ThemeData theme) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _children.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => ChoiceChip(
            selected: index == _selectedChild,
            label: Text(_children[index].childName),
            avatar: const Icon(Icons.child_care_rounded, size: 18),
            onSelected: (_) async {
              setState(() => _selectedChild = index);
              await _loadChildState();
            },
          ),
        ),
      );

  Widget _buildWelcome(ThemeData theme, KindDossier child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF385A75), Color(0xFF6E7BA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_isEvening ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: const Color(0xFFFFD98A), size: 32),
          const SizedBox(height: 18),
          Text(
            _isNightSection
                ? ritualRuheText('welcomeNight', _locale)
                : '${ritualRuheText('sectionMorning', _locale)} ${ritualRuheText('with', _locale)} ${child.childName}',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            _isNightSection
                ? ritualRuheText('welcomeRelaxed', _locale)
                : ritualRuheText('welcomeQuestion', _locale),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82), height: 1.4),
          ),
        ]),
      );

  Widget _buildAgeNotice(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: const Color(0xFFE7F1EE),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF287F76)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_ageNotice!, style: theme.textTheme.bodySmall)),
              IconButton(
                tooltip: ritualRuheText('close', _locale),
                onPressed: () => setState(() => _ageNotice = null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ]),
          ),
        ),
      );

  Widget _buildRitualCard(ThemeData theme) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5DED7)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _isNightSection
                  ? ritualRuheText('nightSectionTitle', _locale)
                  : '${ritualRuheText('your', _locale)} $_sectionTitle',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(ritualRuheText('timeCardSubtitle', _locale),
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            _ageVariantLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF287F76),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!_isNightSection) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _planLoading
                        ? null
                        : () => _editPlan(
                              _customPlan ??
                                  _fallbackPlan(_selectedSection, _ageYears),
                            ),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(ritualRuheText('editPlan', _locale)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _planLoading ? null : _suggestPlan,
                    icon: _planLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_suggestionLabel),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ..._steps.where((step) => !_completed.contains(step.id)).map(
                (step) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEAF3EF),
                    child: Icon(step.icon, color: const Color(0xFF287F76)),
                  ),
                  title: Text(step.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.subtitle),
                      if (step.timerSeconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hourglass_bottom_rounded,
                                  size: 15, color: Color(0xFF287F76)),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimer(step.timerSeconds),
                                style: const TextStyle(
                                  color: Color(0xFF287F76),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: ritualRuheText('timerStart', _locale),
                        onPressed: () {
                          if (step.timerSeconds > 0) {
                            setState(
                                () => _secondsRemaining = step.timerSeconds);
                          }
                          _startTimer();
                        },
                        icon: const Icon(Icons.hourglass_bottom_rounded),
                      ),
                      TextButton(
                        onPressed: () => _toggleStep(step.id),
                        child: Text(ritualRuheText('timerDone', _locale)),
                      ),
                    ],
                  ),
                ),
              ),
          if (_steps.every((step) => _completed.contains(step.id)))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
              child: Text(
                  ritualRuheText('allDone', _locale),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF287F76))),
            ),
          if (_secondsRemaining > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text('${ritualRuheText('timerBanner', _locale)}  $_timerLabel',
                  style: const TextStyle(
                      color: Color(0xFF287F76), fontWeight: FontWeight.w800)),
            ),
        ]),
      );

  Widget _buildStoryCard(ThemeData theme, KindDossier child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE8F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_stories_rounded, color: Color(0xFF6F5A9C)),
            const SizedBox(width: 8),
            Text(ritualRuheText('storyTitle', _locale),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          if (_story == null)
            Text('${ritualRuheText('storyHint', _locale)} ${child.childName}.',
                style: theme.textTheme.bodyMedium)
          else
            Text(_story!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _storyLoading ? null : _generateStory,
            icon: _storyLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_story == null
                ? ritualRuheText('storyButtonGenerate', _locale)
                : ritualRuheText('storyButtonNew', _locale)),
          ),
        ]),
      );

  Widget _buildGratitudeCard(ThemeData theme) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ritualRuheText('gratitudeTitle', _locale),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(ritualRuheText('gratitudeHint', _locale)),
          const SizedBox(height: 10),
          TextField(
            controller: _gratitudeController,
            maxLines: 2,
            onChanged: (_) => _saveState(),
            decoration: InputDecoration(
              hintText: ritualRuheText('gratitudePlaceholder', _locale),
              filled: true,
              fillColor: Colors.white,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ]),
      );
}

class _RitualStep {
  const _RitualStep(this.id, this.title, this.icon, this.subtitle,
      {this.timerSeconds = 0});
  final String id;
  final String title;
  final IconData icon;
  final String subtitle;
  final int timerSeconds;
}

class _RitualPlan {
  const _RitualPlan({
    required this.name,
    required this.time,
    required this.weekdays,
    required this.steps,
  });

  final String name;
  final String time;
  final List<int> weekdays;
  final List<_RitualStep> steps;

  Map<String, dynamic> toJson() => {
        'name': name,
        'time': time,
        'weekdays': weekdays,
        'steps': steps
            .map((step) => {
                  'id': step.id,
                  'title': step.title,
                  'subtitle': step.subtitle,
                  'icon': _iconName(step.icon),
                  'timerSeconds': step.timerSeconds,
                })
            .toList(),
      };

  factory _RitualPlan.fromJson(Map<String, dynamic> json) => _RitualPlan(
        name: json['name']?.toString() ?? 'Mein Ritual',
        time: json['time']?.toString() ?? '08:00',
        weekdays: (json['weekdays'] as List? ?? const [1, 2, 3, 4, 5])
            .map((value) => int.tryParse(value.toString()) ?? 1)
            .toList(),
        steps: (json['steps'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => _RitualStep(
                  raw['id']?.toString() ?? DateTime.now().toIso8601String(),
                  raw['title']?.toString() ?? 'Schritt',
                  _iconFromName(raw['icon']?.toString()),
                  raw['subtitle']?.toString() ?? '',
                  timerSeconds:
                      int.tryParse(raw['timerSeconds']?.toString() ?? '') ?? 0,
                ))
            .toList(),
      );
}

String _iconName(IconData icon) {
  if (icon == Icons.checkroom_rounded) return 'checkroom';
  if (icon == Icons.backpack_rounded) return 'backpack';
  if (icon == Icons.breakfast_dining_rounded) return 'breakfast';
  if (icon == Icons.local_cafe_rounded) return 'cafe';
  if (icon == Icons.toys_rounded) return 'toys';
  if (icon == Icons.water_drop_rounded) return 'water';
  return 'star';
}

IconData _iconFromName(String? name) => switch (name) {
      'checkroom' => Icons.checkroom_rounded,
      'backpack' => Icons.backpack_rounded,
      'breakfast' => Icons.breakfast_dining_rounded,
      'cafe' => Icons.local_cafe_rounded,
      'toys' => Icons.toys_rounded,
      'water' => Icons.water_drop_rounded,
      _ => Icons.auto_awesome_rounded,
    };

class _RitualPlanEditor extends StatefulWidget {
  const _RitualPlanEditor({required this.initial, required this.title});
  final _RitualPlan initial;
  final String title;

  @override
  State<_RitualPlanEditor> createState() => _RitualPlanEditorState();
}

class _RitualPlanEditorState extends State<_RitualPlanEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _timeController;
  late List<_RitualStep> _steps;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _timeController = TextEditingController(text: widget.initial.time);
    _steps = [...widget.initial.steps];
    _weekdays = widget.initial.weekdays.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _addStep() async {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    final timerController = TextEditingController(text: '0');
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Schritt hinzufügen'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Titel')),
          TextField(
              controller: subtitleController,
              decoration: const InputDecoration(labelText: 'Kurzer Satz')),
          const SizedBox(height: 8),
          TextField(
            controller: timerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Timer in Sekunden',
              hintText: '0 = ohne Timer',
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(
                dialogContext, titleController.text.trim().isNotEmpty),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (added == true) {
      final timerSeconds = int.tryParse(timerController.text.trim()) ?? 0;
      setState(() => _steps.add(_RitualStep(
            DateTime.now().microsecondsSinceEpoch.toString(),
            titleController.text.trim(),
            Icons.auto_awesome_rounded,
            subtitleController.text.trim(),
            timerSeconds: timerSeconds.clamp(0, 1800),
          )));
    }
    titleController.dispose();
    subtitleController.dispose();
    timerController.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _RitualPlan(
        name: _nameController.text.trim().isEmpty
            ? widget.initial.name
            : _nameController.text.trim(),
        time: _timeController.text.trim().isEmpty
            ? widget.initial.time
            : _timeController.text.trim(),
        weekdays: _weekdays.toList()..sort(),
        steps: _steps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.title} bearbeiten',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Ritualname')),
                const SizedBox(height: 8),
                TextField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                        labelText: 'Uhrzeit', hintText: '08:00')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return FilterChip(
                      label: Text(
                          ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][index]),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() => selected
                          ? _weekdays.add(day)
                          : _weekdays.remove(day)),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ReorderableListView.builder(
                    itemCount: _steps.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final step = _steps.removeAt(oldIndex);
                        _steps.insert(newIndex, step);
                      });
                    },
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return ListTile(
                        key: ValueKey(step.id),
                        leading: Icon(step.icon),
                        title: Text(step.title),
                        subtitle: Text(step.subtitle),
                        trailing: IconButton(
                          tooltip: 'Schritt entfernen',
                          onPressed: () =>
                              setState(() => _steps.removeAt(index)),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      );
                    },
                  ),
                ),
                Row(children: [
                  OutlinedButton.icon(
                      onPressed: _addStep,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Schritt')),
                  const Spacer(),
                  FilledButton(
                      onPressed: _save, child: const Text('Speichern')),
                ]),
              ]),
        ),
      );
}

class _EmptyChildState extends StatelessWidget {
  const _EmptyChildState({required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.child_care_rounded,
              size: 56, color: Color(0xFF6E7BA8)),
          const SizedBox(height: 14),
          Text(ritualRuheText('emptyTitle', locale),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
              ritualRuheText('emptyDescription', locale),
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: onOpenProfile,
              child: Text(ritualRuheText('emptyAction', locale))),
        ]),
      ),
    );
  }
}
