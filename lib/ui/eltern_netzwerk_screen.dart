import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/friend_chat_service.dart';
import 'package:parentpeak/ui/group_chat_screen.dart';
import 'package:parentpeak/ui/widgets/user_avatar.dart';
import 'package:parentpeak/logic/spielfreunde_backend_service.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friendship_service.dart';
import 'package:parentpeak/logic/user_profile_service.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/services/block_report_service.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';
import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/ui/widgets/playmate_publication_dialog.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/match_conversation_screen.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

String networkWizardOptionLabel(
    String language, String group, String key, String fallback) {
  if (language != 'ku') return fallback;
  const options = <String, Map<String, String>>{
    'family': {
      'kernfamilie': 'Malbata biçûk',
      'alleinerziehend': 'Tenê dêûbav',
      'patchwork': 'Malbata tevlihev',
      'regenbogen': 'Malbata rengîn',
      'grossfamilie': 'Malbata mezin',
      'co_parenting': 'Dêûbaviya hevpar',
      'pflegefamilie': 'Malbata xwedîkirinê',
      'grosseltern': 'Malbata dapîr û bapîr',
      'wg_familie': 'Malbata bi hev re dijîn',
    },
    'gender': {'maennlich': 'Kur', 'weiblich': 'Keç', 'divers': 'Cihêreng'},
    'child': {
      'spielplatz': 'Lîstikgeh',
      'basteln': 'Destkariyê',
      'malen': 'Wênekirin',
      'natur': 'Keşifkirina xwezayê',
      'sport': 'Werziş',
      'musik': 'Muzîk',
      'tanzen': 'Govd',
      'tiere': 'Heywan',
      'bücher': 'Pirtûk',
      'bauen': 'Avakirin',
      'rollenspiel': 'Lîstika rolan',
      'kochen_backen': 'Xwarin çêkirin û nanpêjî',
      'wasser': 'Lîstina bi avê',
      'fahrrad': 'Bisîklet û skuter',
      'theater': 'Şano û cilguhertin',
      'experimente': 'Ceribandin',
    },
    'values': {
      'gfk': 'Axaftina bê tundî',
      'bedürfnisorientiert': 'Li gorî hewcedariyan',
      'attachment_parenting': 'Dêûbaviya bi girêdanê',
      'unerzogen': 'Perwerdehiya azad',
      'montessori': 'Montessori',
      'waldorf': 'Waldorf',
      'freilernend': 'Fêrbûna azad',
      'pikler': 'Pikler',
      'respektvoll': 'Bi rêz',
      'strukturiert': 'Bi rêk û pêk',
      'demokratisch': 'Demokratîk',
      'religioes': 'Olî / ruhanî',
      'interkulturell': 'Pirçandî',
      'feministisch': 'Femînîst',
      'naturverbunden': 'Girêdayî xwezayê',
      'offen': 'Ji her tiştî re vekirî',
    },
    'looking': {
      'spielplatz': 'Hevdîtina lîstikgehê',
      'natur': 'Daristan û xweza',
      'sport': 'Werziş û hereket',
      'kreativ': 'Hevdîtina afirîner',
      'kochen': 'Bi hev re xwarin çêkirin',
      'musik': 'Muzîk û stran',
      'vorlesen': 'Xwendin û çîrok',
      'eltern_austausch': 'Axaftina dêûbavan',
      'babysitting_tausch': 'Alîkariya hevpar a lênihêrînê',
      'kita_fahrgemeinschaft': 'Rêwîtiya hevpar a dibistanê',
      'kindergeburtstage': 'Rojbûnên zarokan',
      'ausflug': 'Ger û rêwîtî',
      'indoor_treffen': 'Hevdîtina hundir',
      'regelmaessig': 'Koma birêkûpêk',
      'spontan': 'Hevdîtina bêplan',
      'online_austausch': 'Axaftina serhêl',
    },
    'days': {
      'montag': 'Du',
      'dienstag': 'Sê',
      'mittwoch': 'Çar',
      'donnerstag': 'Pênc',
      'freitag': 'În',
      'samstag': 'Şem',
      'sonntag': 'Yek'
    },
    'times': {
      'morgens': 'Sibe (6–9)',
      'vormittags': 'Berî nîvro (9–12)',
      'nachmittags': 'Piştî nîvro (12–17)',
      'abends': 'Êvar (17–21)',
      'nach_kita': 'Piştî baxçeyê zarokan / dibistanê',
      'flexibel': 'Guhêrbar'
    },
    'specials': {
      'behinderung': 'Zarokê bi astengiyê',
      'neurodivergent': 'Cihêrengiya mejî (ADHD/otîzm)',
      'hochsensibel': 'Pir hestiyar',
      'fruehchen': 'Dêûbavên zarokên zûdayikbûyî',
      'mehrlinge': 'Cêwî an zarokên pirjimar',
      'chronisch_krank': 'Nexweşiya demdirêj',
      'allergien': 'Alerjî',
      'schreibaby': 'Pitikê pir digirî',
      'pflegekind': 'Zarokê xwedîkirî'
    },
    'language': {
      'de': 'Almanî',
      'en': 'Îngilîzî',
      'tr': 'Tirkî',
      'ku': 'Kurdî',
      'ar': 'Erebî',
      'fr': 'Fransî',
      'es': 'Spanî',
      'ru': 'Rûsî',
      'pl': 'Polonî',
      'it': 'Îtalî',
      'pt': 'Portekîzî',
      'nl': 'Holendî',
      'uk': 'Ukraynî',
      'ro': 'Romenî',
      'bg': 'Bulgarî',
      'sr': 'Sirbî',
      'hr': 'Xirwatî',
      'bs': 'Bosnayî',
      'sq': 'Albanî',
      'el': 'Yewnanî',
      'fa': 'Farisî',
      'hi': 'Hindî',
      'zh': 'Çînî',
      'ja': 'Japonî',
      'ko': 'Koreyî',
      'vi': 'Viyetnamî',
      'sw': 'Swahilî'
    },
  };
  return options[group]?[key] ?? fallback;
}

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);

String _networkCopy(String key, String fallback) {
  const copies = {
    'en': {
      'friends': 'Friends',
      'playmates': 'Playmates',
      'invite': 'Invite',
      'invite_hero_title': 'Invite friends',
      'invite_hero_description':
          'Share your personal link or QR code - one tap and you are connected.',
      'share': 'Share',
      'setup_hint':
          'In 5 short steps, you will find families who are a good fit for you.',
      'empty_title': 'Be the first family in your area',
      'empty_description':
          'Your profile is active and visible. As soon as other families nearby join, they will appear here automatically. Invite neighbors and friends to grow your network.',
      'invite_playmates': 'Invite playmates',
      'values_tip':
          'Tip: Families with similar values understand each other best. Choose what matters to you.',
      'bio_hint':
          'Tell us about yourselves: What makes your family special? What are you looking for?',
      'step_1': 'Step 1: Your family',
      'step_2': 'Step 2: Your children',
      'step_3': 'Step 3: Values and style',
      'step_4': 'Step 4: What are you looking for?',
      'step_5': 'Step 5: Languages and more',
      'bio_title': 'Short bio',
      'login_required': 'Please sign in to publish your playmate profile.',
      'same_city': 'In your city',
      'reason_nearby': 'Nearby',
      'reason_shared_interests': 'Shared interests',
      'reason_similar_child_age': 'Children of a similar age',
      'reason_shared_languages': 'Shared languages',
      'reason_shared_values': 'Similar parenting values',
      'reason_shared_family_form': 'Similar family setup',
      'request_sent': 'Your request was sent to {name}.',
      'request_failed':
          'Your request could not be sent. Please try again later.',
      'no_gender': 'Prefer not to say',
      'gender_maennlich': 'Boy',
      'gender_weiblich': 'Girl',
      'gender_divers': 'Diverse',
      'invite_share': 'Share invitation',
      'invite_share_hint': 'WhatsApp, SMS, email',
      'qr_show': 'Show QR code',
      'qr_hint': 'Scan at the playground',
      'link_copy': 'Copy link',
      'connect': 'Connect?',
      'cancel': 'Cancel',
      'connect_button': 'Connect',
      'save': 'Save...',
      'create_profile': 'Create profile',
      'step_family': 'Step 1: Your family',
      'name_hint': 'Your first name / nickname',
      'name_example': 'e.g. Sarah, The Muellers',
      'location_hint': 'Choose your district / ZIP code',
      'family_form': 'Family type',
      'custom': 'Custom',
      'custom_family': 'Your family type',
      'custom_example': 'e.g. chosen family, multigenerational...',
    },
    'ku': {
      'friends': 'Heval',
      'playmates': 'Hevalên lîstikê',
      'invite': 'Vexwendin',
      'invite_hero_title': 'Hevalan vexwîne',
      'invite_hero_description':
          'Girêdana xwe ya kesane an koda QR parve bike - bi yek pêlê hûn tên girêdan.',
      'share': 'Parve bike',
      'setup_hint':
          'Di 5 gavên kurt de hûn ê malbatên ku bi we re guncaw in bibînin.',
      'empty_title': 'Di herêma xwe de malbata yekem bibe',
      'empty_description':
          'Profîla we çalak û xuya ye. Gava malbatên din li nêzîkê beşdar bibin, ew dê li vir bixuyan. Cîran û hevalan vexwînin da ku tora we mezin bibe.',
      'invite_playmates': 'Hevalên lîstikê vexwîne',
      'values_tip':
          'Şîret: Malbatên bi nirxên wekhev herî baş hev fam dikin. Ya ku ji we re girîng e hilbijêrin.',
      'bio_hint':
          'Kurte ji me re behsa xwe bikin: Çi malbata we taybet dike? Hûn çi dixwazin?',
      'step_1': 'Gav 1: Malbata we',
      'step_2': 'Gav 2: Zarokên we',
      'step_3': 'Gav 3: Nirx û şêwaz',
      'step_4': 'Gav 4: Hûn li çi digerin?',
      'step_5': 'Gav 5: Ziman û zêdetir',
      'bio_title': 'Bioya kurt',
      'login_required':
          'Ji bo weşandina profîla hevalên lîstikê têkeve hesabê xwe.',
      'same_city': 'Di bajarê te de',
      'reason_nearby': 'Li nêzîkê',
      'reason_shared_interests': 'Berjewendiyên hevpar',
      'reason_similar_child_age': 'Zarokên bi temenê nêzîk',
      'reason_shared_languages': 'Zimanên hevpar',
      'reason_shared_values': 'Nirxên perwerdehiyê yên wekhev',
      'reason_shared_family_form': 'Şêwaza malbatê ya wekhev',
      'request_sent': 'Daxwaza te ji {name} re hat şandin.',
      'request_failed':
          'Daxwaza te nehat şandin. Ji kerema xwe paşê dîsa biceribîne.',
      'no_gender': 'Naxwazim bibêjim',
      'gender_maennlich': 'Kur',
      'gender_weiblich': 'Keç',
      'gender_divers': 'Cûda',
      'invite_share': 'Vexwendinê parve bike',
      'invite_share_hint': 'WhatsApp, SMS, e-name',
      'qr_show': 'Koda QR nîşan bide',
      'qr_hint': 'Li parka lîstikê bixwîne',
      'link_copy': 'Girêdanê kopî bike',
      'connect': 'Girêdan?',
      'cancel': 'Betal bike',
      'connect_button': 'Girêde',
      'save': 'Tê tomarkirin...',
      'create_profile': 'Profîlê çêbike',
      'step_family': 'Gav 1: Malbata we',
      'name_hint': 'Navê te / navê kurt',
      'name_example': 'mînak: Sarah, Müller',
      'location_hint': 'Navçeya / koda postê hilbijêre',
      'family_form': 'Şêwaza malbatê',
      'custom': 'Taybet',
      'custom_family': 'Şêwaza malbata we',
      'custom_example': 'mînak: malbata hilbijartî, çend-neslî...',
    },
    'tr': {
      'friends': 'Arkadaşlar',
      'playmates': 'Oyun arkadaşları',
      'invite': 'Davet et',
      'invite_hero_title': 'Arkadaşlarını davet et',
      'invite_hero_description':
          'Kişisel bağlantını veya QR kodunu paylaş - tek dokunuşla bağlantı kurun.',
      'share': 'Paylaş',
      'setup_hint': '5 kısa adımda size uygun aileleri bulun.',
      'empty_title': 'Bölgenizdeki ilk aile siz olun',
      'empty_description':
          'Profiliniz aktif ve görünür. Yakınınızdaki diğer aileler katıldığında burada otomatik olarak görünürler. Ağınızı büyütmek için komşularınızı ve arkadaşlarınızı davet edin.',
      'invite_playmates': 'Oyun arkadaşlarını davet et',
      'values_tip':
          'İpucu: Benzer değerlere sahip aileler birbirini daha iyi anlar. Sizin için önemli olanı seçin.',
      'bio_hint':
          'Kendinizden kısaca bahsedin: Ailenizi özel kılan nedir? Ne arıyorsunuz?',
      'step_1': '1. Adım: Aileniz',
      'step_2': '2. Adım: Çocuklarınız',
      'step_3': '3. Adım: Değerler ve yaklaşım',
      'step_4': '4. Adım: Ne arıyorsunuz?',
      'step_5': '5. Adım: Diller ve daha fazlası',
      'bio_title': 'Kısa biyografi',
      'login_required':
          'Oyun arkadaşı profilinizi yayınlamak için giriş yapın.',
      'same_city': 'Şehrinizde',
      'reason_nearby': 'Yakınınızda',
      'reason_shared_interests': 'Ortak ilgi alanları',
      'reason_similar_child_age': 'Benzer yaşta çocuklar',
      'reason_shared_languages': 'Ortak diller',
      'reason_shared_values': 'Benzer ebeveynlik değerleri',
      'reason_shared_family_form': 'Benzer aile yapısı',
      'request_sent': '{name} için isteğiniz gönderildi.',
      'request_failed':
          'İsteğiniz gönderilemedi. Lütfen daha sonra tekrar deneyin.',
      'no_gender': 'Belirtmek istemiyorum',
      'gender_maennlich': 'Erkek',
      'gender_weiblich': 'Kız',
      'gender_divers': 'Diğer',
      'invite_share': 'Daveti paylaş',
      'invite_share_hint': 'WhatsApp, SMS, e-posta',
      'qr_show': 'QR kodunu göster',
      'qr_hint': 'Parkta okut',
      'link_copy': 'Bağlantıyı kopyala',
      'connect': 'Bağlan?',
      'cancel': 'İptal',
      'connect_button': 'Bağlan',
      'save': 'Kaydediliyor...',
      'create_profile': 'Profil oluştur',
      'step_family': '1. Adım: Aileniz',
      'name_hint': 'Adınız / takma adınız',
      'name_example': 'örn. Sarah, Müller ailesi',
      'location_hint': 'Mahallenizi / posta kodunuzu seçin',
      'family_form': 'Aile biçimi',
      'custom': 'Özel',
      'custom_family': 'Aile biçiminiz',
      'custom_example': 'örn. seçilmiş aile, çok kuşaklı aile...',
    },
  };
  return copies[languageService.currentLanguage]?[key] ?? fallback;
}

class ElternNetzwerkScreen extends StatefulWidget {
  final String? initialFriendCode;

  /// 0 = Chats, 1 = Netzwerk, 2 = Spielfreunde
  final int initialTab;
  const ElternNetzwerkScreen(
      {super.key, this.initialFriendCode, this.initialTab = 0});
  @override
  State<ElternNetzwerkScreen> createState() => _ScreenState();
}

class _ScreenState extends State<ElternNetzwerkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _backend = SpielfreundeBackendService();
  final _matching = ParentMatchingBackendService(
      apiClient: BackendServiceFactory.createApiClient());
  FamilyMatchProfile? _profile;
  bool _deletingProfile = false;
  Set<String> _dismissedSuggestions = {};
  List<_SuggestedParent> _suggestedProfiles = [];
  bool _loadingSuggestions = true;

  // Echte Spielfreunde-Discovery (nutzt /api/parent-matching/find)
  List<MatchResult> _matches = [];
  bool _loadingMatches = false;
  String _matchScope = '10km';

  // Chats-Tab: Messenger-Übersicht
  List<ConversationSummary> _conversations = [];
  bool _loadingConversations = true;
  final _chatSearchCtrl = TextEditingController();
  String _chatQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    FriendshipService.instance.addListener(_rebuild);
    _chatSearchCtrl.addListener(() {
      setState(() => _chatQuery = _chatSearchCtrl.text.trim().toLowerCase());
    });
    _loadConversations();
    _init();
    final incoming = widget.initialFriendCode;
    if (incoming != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (incoming.startsWith('invite:')) {
          // Einladungslink -> Anfrage-Flow (1 Tap).
          _handleInviteToken(incoming.substring('invite:'.length));
        } else {
          // Alter Freund-Link (parentpeak.de/freund/<CODE>): Code -> UID
          // aufloesen und eine UID-Freundschaftsanfrage senden.
          _handleLegacyCodeLink(incoming);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _chatSearchCtrl.dispose();
    FriendshipService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Lädt die Messenger-Übersicht (alle Unterhaltungen) für den Chats-Tab.
  Future<void> _loadConversations() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loadingConversations = false);
      return;
    }
    if (mounted) setState(() => _loadingConversations = true);
    final list = await FriendChatService.instance.fetchOverview(uid);
    if (!mounted) return;
    setState(() {
      _conversations = list;
      _loadingConversations = false;
    });
  }

  /// Öffnet eine Unterhaltung und markiert sie als gelesen.
  Future<void> _openConversation({
    required String roomId,
    required String title,
    required bool isGroup,
    String? photoUrl,
  }) async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isGroup
            ? GroupChatScreen(
                roomId: roomId, groupName: title, photoUrl: photoUrl)
            : MatchConversationScreen(
                profileId: roomId,
                profileName: title,
                isFriendChat: true,
              ),
      ),
    );
    // Nach Rückkehr: als gelesen markieren und Übersicht aktualisieren.
    if (uid.isNotEmpty) {
      await FriendChatService.instance.markRead(roomId, uid);
    }
    await _loadConversations();
  }

  /// Einladungslink (/f/<token>) verarbeiten: Einladenden auflösen und eine
  /// Freundschaftsanfrage senden — 1 Tap, kein Code-Abtippen.
  Future<void> _handleInviteToken(String token) async {
    final resolved = await FriendshipService.instance.resolveInvite(token);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('network_invalid_invite')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final name = resolved['name']?.isNotEmpty == true
        ? resolved['name']!
        : 'diese Familie';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_networkCopy('connect', 'Verbinden?')),
        content: Text(_t('network_connect_confirm').replaceAll('{name}', name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_networkCopy('cancel', 'Abbrechen'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_networkCopy('connect_button', 'Verbinden'))),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await FriendshipService.instance.sendRequest(resolved['uid']!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent
          ? 'Anfrage an $name gesendet. 👋'
          : 'Konnte nicht verbinden — bitte später erneut versuchen.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: sent ? const Color(0xFF16A34A) : null,
    ));
  }

  /// Alter Freund-Link (parentpeak.de/freund/<CODE>): den Code ueber die noch
  /// vorhandene lookup-Bruecke in eine UID aufloesen und eine Anfrage senden.
  /// So funktionieren bereits geteilte alte Links weiter — ohne Code-Eingabe.
  Future<void> _handleLegacyCodeLink(String code) async {
    final resolved = await FriendshipService.instance.resolveCode(code);
    if (!mounted) return;
    if (resolved == null || (resolved['uid'] ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Dieser Link ist nicht mehr aktiv. Bitte nutze den Einladungslink '
            'der anderen Familie.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final name = resolved['name']?.isNotEmpty == true
        ? resolved['name']!
        : 'diese Familie';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_networkCopy('connect', 'Verbinden?')),
        content: Text(_t('network_connect_confirm').replaceAll('{name}', name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_networkCopy('cancel', 'Abbrechen'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_networkCopy('connect_button', 'Verbinden'))),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await FriendshipService.instance.sendRequest(resolved['uid']!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent
          ? 'Anfrage an $name gesendet. 👋'
          : 'Konnte nicht verbinden — bitte später erneut versuchen.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: sent ? const Color(0xFF16A34A) : null,
    ));
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('friends.dismissed') ?? [];
    if (mounted) setState(() => _dismissedSuggestions = dismissed.toSet());
    final p = await FamilyMatchProfile.load();
    if (mounted) setState(() => _profile = p);
    if (p != null) {
      unawaited(_loadMatches());
    }

    // NEUES FUNDAMENT: den app-weiten Anzeigenamen serverseitig sichern
    // (uid -> displayName). Kommt aus der Registrierung; hier nur gespiegelt.
    final myName = AuthService.instance.currentUser?.displayName ??
        _profile?.displayName ??
        'Familie';
    final myUserId = AuthService.instance.currentUser?.uid ?? '';
    unawaited(UserProfileService.instance.setDisplayName(myName));
    // Neue UID-Freundschaften + offene Anfragen laden.
    unawaited(FriendshipService.instance.load());

    try {
      final sug = await _backend.getProfiles();
      if (mounted) {
        // Vorschlaege filtern: nicht ich selbst, nicht bereits befreundet
        // (UID-basiert), nicht bereits weggewischt.
        final friendUids =
            FriendshipService.instance.friends.map((f) => f.uid).toSet();
        final suggestions = sug
            .where((mp) =>
                mp['userId'] != null &&
                (mp['userId'] as String) != myUserId &&
                !friendUids.contains(mp['userId'] as String) &&
                !_dismissedSuggestions.contains(mp['userId'] as String? ?? ''))
            .take(6)
            .map((mp) {
          final name = mp['displayName'] as String? ?? 'Familie';
          final district = mp['district'] as String? ?? '';
          final children =
              (mp['children'] as List? ?? []).cast<Map<String, dynamic>>();
          final kidsText = children.isEmpty
              ? ''
              : children.map((c) => '${c['name']} (${c['age']})').join(' · ');
          final reason = (_profile?.district != null &&
                  district.isNotEmpty &&
                  district == _profile!.district)
              ? '📍 Gleicher Bezirk'
              : district.isNotEmpty
                  ? '🌍 $district'
                  : '👥 In deiner Nähe';
          return _SuggestedParent(
              id: mp['userId'] as String,
              name: name,
              kids: kidsText,
              reason: reason);
        }).toList();
        setState(() {
          _suggestedProfiles = suggestions;
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'eltern_netzwerk_title')),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: _t('network_tab_chats')),
            Tab(text: _t('network_tab_network')),
            Tab(text: _networkCopy('playmates', 'Spielfreunde')),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          // FAB nur im Chats-Tab: neuer Chat / neue Gruppe.
          if (_tabs.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _showNewChatOptions,
            backgroundColor: const Color(0xFF7C3AED),
            icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
            label: Text(
              _t('network_new_chat'),
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _chatsTab(theme),
          _netzwerkTab(theme),
          _spielfreundeTab(theme),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: CHATS (Messenger-Übersicht)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _chatsTab(ThemeData theme) {
    final filtered = _conversations.where((c) {
      if (_chatQuery.isEmpty) return true;
      final name = (c.name ?? c.lastAuthorName).toLowerCase();
      return name.contains(_chatQuery) ||
          c.lastMessage.toLowerCase().contains(_chatQuery);
    }).toList();

    return Column(children: [
      // Suchleiste
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: TextField(
          controller: _chatSearchCtrl,
          decoration: InputDecoration(
            hintText: _t('network_search_hint'),
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadConversations,
          child: _loadingConversations
              ? _chatsLoadingSkeleton(theme)
              : filtered.isEmpty
                  ? _chatsEmptyState(theme)
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 76,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                      itemBuilder: (_, i) =>
                          _conversationTile(theme, filtered[i]),
                    ),
        ),
      ),
    ]);
  }

  Widget _conversationTile(ThemeData theme, ConversationSummary c) {
    final title = c.isGroup
        ? (c.name ?? _t('network_group'))
        : (c.lastAuthorName.isNotEmpty && c.lastAuthorUserId != _myUid
            ? c.lastAuthorName
            : (c.name ?? _t('network_chat')));
    final preview = c.lastMessage.isEmpty
        ? _t('network_no_messages_yet')
        : (c.lastAuthorUserId == _myUid
            ? '${_t('network_you_prefix')} ${c.lastMessage}'
            : c.lastMessage);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: UserAvatar(
        name: c.isGroup ? (c.name ?? 'G') : title,
        photoUrl: c.photoUrl.isNotEmpty ? c.photoUrl : null,
        isGroup: c.isGroup,
        radius: 26,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: c.hasUnread ? FontWeight.w800 : FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: c.hasUnread
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: c.hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (c.lastMessageAt != null)
            Text(
              _formatConversationTime(c.lastMessageAt!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: c.hasUnread
                    ? const Color(0xFF7C3AED)
                    : theme.colorScheme.outline,
                fontWeight: c.hasUnread ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          const SizedBox(height: 6),
          if (c.hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            )
          else
            const SizedBox(width: 20, height: 20),
        ],
      ),
      onTap: () => _openConversation(
        roomId: c.roomId,
        title: title,
        isGroup: c.isGroup,
        photoUrl: c.photoUrl.isNotEmpty ? c.photoUrl : null,
      ),
      onLongPress: () => _showChatActions(c, title),
    );
  }

  /// Lösch-Optionen für einen Chat (WhatsApp-Stil): Für mich / Für alle.
  Future<void> _showChatActions(ConversationSummary c, String title) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              UserAvatar(
                name: c.isGroup ? (c.name ?? 'G') : title,
                photoUrl: c.photoUrl.isNotEmpty ? c.photoUrl : null,
                isGroup: c.isGroup,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_rounded),
            title: Text(_t('chat_delete_for_me')),
            subtitle: Text(_t('chat_delete_for_me_hint')),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmChatDelete(c, title, forAll: false);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded,
                color: theme.colorScheme.error),
            title: Text(_t('chat_delete_for_all'),
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: Text(_t('chat_delete_for_all_hint')),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmChatDelete(c, title, forAll: true);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _confirmChatDelete(ConversationSummary c, String title,
      {required bool forAll}) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text(forAll ? _t('chat_delete_for_all') : _t('chat_delete_for_me')),
        content: Text(forAll
            ? _t('chat_delete_for_all_confirm')
            : _t('chat_delete_for_me_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: forAll
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error)
                : null,
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = AuthService.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final ok = forAll
        ? await FriendChatService.instance.deleteForAll(c.roomId, uid)
        : await FriendChatService.instance.clearForMe(c.roomId, uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? _t('chat_deleted') : _t('chat_delete_failed')),
      behavior: SnackBarBehavior.floating,
    ));
    await _loadConversations();
  }

  Widget _chatsLoadingSkeleton(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        6,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(
                        height: 10,
                        width: 220,
                        decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6))),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chatsEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 34, color: Color(0xFF8B5CF6)),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _t('network_chats_empty_title'),
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _t('network_chats_empty_desc'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: _showNewChatOptions,
            icon: const Icon(Icons.add_comment_rounded, size: 18),
            label: Text(_t('network_new_chat')),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  String get _myUid => AuthService.instance.currentUser?.uid ?? '';

  /// Zeit-Label für die Chat-Liste: HH:mm (heute), "Gestern", oder TT.MM.
  String _formatConversationTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return _t('network_yesterday');
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.';
  }

  // ─── Neuer Chat / Neue Gruppe ──────────────────────────────────────────────

  Future<void> _showNewChatOptions() async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF7C3AED),
              child: Icon(Icons.person_rounded, color: Colors.white),
            ),
            title: Text(_t('network_start_direct_chat'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_t('network_start_direct_chat_hint')),
            onTap: () {
              Navigator.pop(sheetCtx);
              _tabs.animateTo(1); // Zum Netzwerk-Tab (dort Freunde anchatten)
            },
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF0EA5A4),
              child: Icon(Icons.groups_rounded, color: Colors.white),
            ),
            title: Text(_t('network_create_group'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_t('network_create_group_hint')),
            onTap: () {
              Navigator.pop(sheetCtx);
              _showCreateGroupSheet();
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  /// Gruppe erstellen: Name eingeben + Freunde als Mitglieder wählen.
  Future<void> _showCreateGroupSheet() async {
    final friends = FriendshipService.instance.friends;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('network_group_needs_friends')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final nameCtrl = TextEditingController();
    final selected = <String>{};
    Uint8List? photoBytes; // ausgewähltes Gruppen-Foto (Web-sicher)
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        bool saving = false;

        Future<void> pickGroupPhoto(StateSetter setSheet) async {
          final source = await showModalBottomSheet<ImageSource>(
            context: sheetCtx,
            builder: (pickCtx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text(_t('network_photo_camera')),
                  onTap: () => Navigator.pop(pickCtx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(_t('network_photo_gallery')),
                  onTap: () => Navigator.pop(pickCtx, ImageSource.gallery),
                ),
              ]),
            ),
          );
          if (source == null) return;
          final picked = await ImagePicker().pickImage(
            source: source,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          );
          if (picked == null) return;
          final bytes = await picked.readAsBytes();
          setSheet(() => photoBytes = bytes);
        }

        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          final theme = Theme.of(sheetCtx);
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_t('network_create_group'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              // Gruppen-Foto (optional) — tippen zum Auswählen/Ändern.
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: saving ? null : () => pickGroupPhoto(setSheet),
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          const Color(0xFF0EA5A4).withValues(alpha: 0.15),
                      backgroundImage:
                          photoBytes != null ? MemoryImage(photoBytes!) : null,
                      child: photoBytes == null
                          ? const Icon(Icons.groups_rounded,
                              size: 32, color: Color(0xFF0EA5A4))
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0EA5A4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text(_t('network_group_photo_hint'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: _t('network_group_name'),
                  hintText: _t('network_group_name_hint'),
                  prefixIcon: const Icon(Icons.groups_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_t('network_choose_members'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: friends.map((f) {
                    final isSel = selected.contains(f.uid);
                    return CheckboxListTile(
                      value: isSel,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: UserAvatar(name: f.name, radius: 20),
                      title: Text(f.name),
                      onChanged: (v) => setSheet(() {
                        if (v == true) {
                          selected.add(f.uid);
                        } else {
                          selected.remove(f.uid);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetCtx)
                                .showSnackBar(SnackBar(
                              content: Text(_t('network_group_name_required')),
                            ));
                            return;
                          }
                          if (selected.isEmpty) {
                            ScaffoldMessenger.of(sheetCtx)
                                .showSnackBar(SnackBar(
                              content: Text(_t('network_group_select_member')),
                            ));
                            return;
                          }
                          setSheet(() => saving = true);
                          final ok = await _createGroup(
                            nameCtrl.text.trim(),
                            selected.toList(),
                            friends,
                            photoBytes,
                          );
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx, ok);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5A4),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_t('network_create_group')),
                ),
              ),
            ]),
          );
        });
      },
    );
    nameCtrl.dispose();
    if (created == true) await _loadConversations();
  }

  Future<bool> _createGroup(String name, List<String> memberUids,
      List<Friend> friends, Uint8List? photoBytes) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    final ownerName =
        AuthService.instance.currentUser?.displayName ?? 'Familie';
    final memberNames = <String, String>{
      for (final f in friends)
        if (memberUids.contains(f.uid)) f.uid: f.name,
    };
    // Optionales Gruppen-Foto zuerst hochladen (fehlertolerant: scheitert der
    // Upload, wird die Gruppe trotzdem ohne Foto erstellt).
    String photoUrl = '';
    if (photoBytes != null && photoBytes.isNotEmpty) {
      final url = await FriendChatService.instance.uploadGroupPhoto(photoBytes);
      if (url != null) photoUrl = url;
    }
    final group = await FriendChatService.instance.createGroup(
      name: name,
      ownerUserId: uid,
      ownerName: ownerName,
      memberUids: memberUids,
      memberNames: memberNames,
      photoUrl: photoUrl,
    );
    if (!mounted) return false;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('network_group_create_failed')),
        behavior: SnackBarBehavior.floating,
      ));
      return false;
    }
    // Direkt in die neue Gruppe springen.
    await _openConversation(
      roomId: group.roomId,
      title: group.name,
      isGroup: true,
      photoUrl: group.photoUrl.isNotEmpty ? group.photoUrl : null,
    );
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: SPIELFREUNDE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _spielfreundeTab(ThemeData theme) {
    if (_profile == null) return _profileSetup(theme);
    return _discoveryView(theme);
  }

  Widget _profileSetup(ThemeData theme) {
    return Column(children: [
      const SizedBox(height: 16),
      Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
              borderRadius: BorderRadius.circular(18)),
          child: const Center(
              child: Text('\u{1F46A}', style: TextStyle(fontSize: 28)))),
      const SizedBox(height: 12),
      Text(
          AppStringsManager.getString(
              languageService.currentLanguage, 'find_playmates'),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
            _networkCopy('setup_hint',
                'In 5 kurzen Schritten findet ihr Familien die so ticken wie ihr.'),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.3),
            textAlign: TextAlign.center),
      ),
      const SizedBox(height: 16),
      Expanded(child: _ProfileForm(onSave: (p) async {
        final uid = AuthService.instance.currentUser?.uid;
        if (uid == null || uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_networkCopy(
                'login_required',
                'Bitte melde dich an, um dein Spielfreunde-Profil zu veröffentlichen.',
              )),
            ));
          }
          return;
        }
        try {
          final result = await PlaymateProfileService(matchingService: _matching)
              .publishProfile(
            p,
            uid,
            confirmPublication: () => confirmPlaymatePublication(context));
          if (!mounted || result == PlaymatePublicationResult.cancelled) return;
          if (result == PlaymatePublicationResult.failed) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_t('network_publish_failed')),
              backgroundColor: theme.colorScheme.error,
            ));
            return;
          }
        } on SuspendedAccountException {
          if (mounted) await showAccountSuspendedNotice(context);
          return;
        }
        await _init();
        await _loadMatches();
      })),
    ]);
  }

  /// Laedt echte Familien in der Naehe ueber das bestehende Matching-Backend.
  Future<void> _loadMatches() async {
    if (_profile == null) return;
    if (mounted) setState(() => _loadingMatches = true);
    final uid = AuthService.instance.currentUser?.uid ?? 'guest';
    final childAges = _profile!.children.map((c) {
      final years = c.ageMonths ~/ 12;
      return years >= 1 ? '${years}J' : '${c.ageMonths % 12}M';
    }).toList();
    try {
      final result = await _matching.findMatchesWithFallback(
        userId: uid,
        limit: 20,
        childAges: childAges,
      );
      // Prio 4: blockierte Familien zusätzlich clientseitig ausblenden
      // (Server filtert bereits, das hier ist Absicherung + sofortige Wirkung).
      final visible = result.matches.where((m) {
        final ownerId = m.profile.userId;
        if (ownerId == null || ownerId.isEmpty) return true;
        return !BlockReportService.instance.isBlocked(ownerId);
      }).toList();
      if (mounted && _profile != null) {
        setState(() {
          _matches = visible;
          _matchScope = result.scope;
          _loadingMatches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  Widget _discoveryView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Eigenes Profil (Header) ──────────────────────────────────────
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12))),
              child: Row(children: [
                const Text('\u{1F46A}', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Familie ${_profile!.displayName}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                          _profile!.bio.isNotEmpty
                              ? _profile!.bio
                              : 'Profil aktiv \u{2714}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                    ])),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _deletingProfile ? null : () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('spielfreunde.profile');
                        setState(() => _profile = null);
                      },
                      child: Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage, 'edit_btn'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary))),
                  const SizedBox(width: 12),
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _deletingProfile
                          ? null
                          : () => _confirmDeleteProfile(theme),
                      child: Text(_t('delete'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error))),
                ])
              ])),
          const SizedBox(height: 20),

          // ── Titelzeile Discovery ─────────────────────────────────────────
          Row(children: [
            const Text('\u{1F50D}', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_t('network_families_nearby'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (_loadingMatches)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _loadMatches,
                child: Icon(Icons.refresh_rounded,
                    size: 20, color: theme.colorScheme.primary),
              ),
          ]),
          if (!_loadingMatches && _matches.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                _matchScope == '10km'
                    ? 'Im Umkreis von ~10 km'
                    : _matchScope == '50km'
                        ? 'Im Umkreis von ~50 km'
                        : _matchScope == '100km'
                            ? 'Im Umkreis von ~100 km'
                            : 'Deutschlandweit',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
          const SizedBox(height: 12),

          // ── Ergebnis: Liste, Loading oder ehrlicher Empty-State ──────────
          if (_loadingMatches)
            _matchesLoadingSkeleton(theme)
          else if (_matches.isEmpty)
            _emptyDiscoveryState(theme)
          else
            ..._matches.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _matchCard(theme, m),
                )),
        ]),
      ),
    );
  }

  /// Ehrlicher Empty-State: keine Fake-Familien, echter Aufruf zum Mitmachen.
  Widget _emptyDiscoveryState(ThemeData theme) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        child: Column(children: [
          const Text('\u{1F331}', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
              _networkCopy(
                  'empty_title', 'Sei die erste Familie in deiner Gegend'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              _networkCopy(
                  'empty_description',
                  'Dein Profil ist aktiv und sichtbar. Sobald andere Familien in '
                      'deiner Nähe dabei sind, erscheinen sie hier automatisch. '
                      'Lade Nachbarn & Freunde ein - so wächst euer Netzwerk am schnellsten.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _tabs.animateTo(2),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                  _networkCopy('invite_playmates', 'Spielkameraden einladen')),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]));
  }

  Widget _matchesLoadingSkeleton(ThemeData theme) {
    return Column(
      children: List.generate(
          2,
          (_) => Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
              )),
    );
  }

  /// Karte einer echten gematchten Familie mit Verbinden-Aktion.
  Widget _matchCard(ThemeData theme, MatchResult m) {
    final p = m.profile;
    final kids = p.childAges.isEmpty
        ? ''
        : '\u{1F9D2} ${p.childAges.join(' \u{2022} ')}';
    final distanceKm = m.breakdown['distanceKm'];
    final reasonCodes = (m.breakdown['reasons'] as List? ?? const [])
        .map((reason) => reason.toString())
        .take(3);
    final meta = <String>[
      if (distanceKm != null) '\u{1F4CD} $distanceKm km',
      if (distanceKm == null && m.breakdown['locationLabel'] == 'same_city')
        _networkCopy('same_city', 'In deiner Stadt'),
      if (p.languages.isNotEmpty)
        p.languages
            .take(3)
            .map((code) => networkWizardOptionLabel(
                languageService.currentLanguage, 'language', code, code))
            .join(', '),
    ].join('  \u{2022}  ');
    final tags = <String>[
      ...p.valuesFocus.take(2).map((code) => networkWizardOptionLabel(
          languageService.currentLanguage, 'values', code, code)),
      ...p.interests.take(2).map((code) => networkWizardOptionLabel(
          languageService.currentLanguage, 'looking', code, code)),
    ];

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11)),
                child: const Center(
                    child: Text('\u{1F46A}', style: TextStyle(fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (p.city.isNotEmpty)
                    Text(p.city,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                ])),
            if (m.score > 0)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${m.score}% Match',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A)))),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 18, color: theme.colorScheme.outline),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'report') {
                  showReportSheet(
                    context,
                    userId: m.profile.userId ?? m.profile.id,
                    userName: m.profile.name,
                    contentType: 'profile',
                  );
                } else if (v == 'block') {
                  _blockMatch(m);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'report',
                    child: Row(children: [
                      Icon(Icons.flag_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Melden'),
                    ])),
                PopupMenuItem(
                    value: 'block',
                    child: Row(children: [
                      Icon(Icons.block_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Blockieren'),
                    ])),
              ],
            ),
          ]),
          if (kids.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(kids,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.bio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C3AED)))))
                    .toList()),
          ],
          if (reasonCodes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reasonCodes
                  .map((code) => Text(
                        _networkCopy('reason_$code', code),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF0E7F77),
                          fontWeight: FontWeight.w700,
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _connectWithMatch(m),
              icon: const Icon(Icons.waving_hand_rounded, size: 16),
              label: const Text('Hallo sagen'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]));
  }

  /// Verbindungswunsch senden (echte Aktion im Matching-Backend).
  Future<void> _connectWithMatch(MatchResult m) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final targetUserId = m.profile.userId;
    final ok = targetUserId != null && targetUserId.isNotEmpty
        ? await FriendshipService.instance.sendRequest(targetUserId)
        : false;
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? _networkCopy(
                  'request_sent', 'Deine Anfrage wurde an {name} gesendet.')
              .replaceAll('{name}', m.profile.name)
          : _networkCopy('request_failed',
              'Deine Anfrage konnte nicht gesendet werden. Bitte versuche es später erneut.')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? const Color(0xFF16A34A) : errorColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Familie blockieren (lokal + serverseitig) und sofort ausblenden.
  Future<void> _blockMatch(MatchResult m) async {
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = m.profile.userId ?? m.profile.id;
    await BlockReportService.instance.blockUser(ownerId, m.profile.name);
    if (!mounted) return;
    setState(() {
      _matches = _matches
          .where((x) => (x.profile.userId ?? x.profile.id) != ownerId)
          .toList();
    });
    messenger.showSnackBar(SnackBar(
      content: Text('${m.profile.name} wurde blockiert.'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: NETZWERK (Freunde, Anfragen, Vorschläge, Einladen)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _netzwerkTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Einladungs-Karte: verbinden per Link/QR (1 Tap) ────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(children: [
            const Icon(Icons.group_add_rounded, color: Colors.white, size: 34),
            const SizedBox(height: 12),
            Text(
              _networkCopy('invite_hero_title', 'Freunde einladen'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _networkCopy(
                'invite_hero_description',
                'Teile deinen persönlichen Link oder QR-Code - ein Tap und '
                    'ihr seid verbunden.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: _shareActionBtn(
                      Icons.ios_share_rounded, _networkCopy('share', 'Teilen'),
                      () async {
                final box = context.findRenderObject() as RenderBox?;
                // Frischen Einladungslink erzeugen (1-Tap-Verbinden).
                final link =
                    await FriendshipService.instance.createInviteLink();
                if (link == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_t('network_link_create_failed')),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                  return;
                }
                await Share.share(
                    _t('network_share_message').replaceAll('{link}', link),
                    sharePositionOrigin: box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null);
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: _shareActionBtn(Icons.qr_code_2_rounded, 'QR-Code',
                      () async {
                final link =
                    await FriendshipService.instance.createInviteLink();
                if (!mounted) return;
                if (link == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_t('network_qr_create_failed')),
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                _showFriendQR(theme, link);
              })),
            ]),
          ]),
        ),
        const SizedBox(height: 32),

        _suggestedParentsSection(theme),
        const SizedBox(height: 32),

        // NEUES UID-Fundament: offene Anfragen + Freundesliste vom Server.
        _friendRequestsSection(theme),
        _uidFriendsSection(theme),
      ]),
    );
  }

  // ── Eingehende Freundschaftsanfragen (annehmen/ablehnen) ──────────────────
  Widget _friendRequestsSection(ThemeData theme) {
    final incoming = FriendshipService.instance.incoming;
    if (incoming.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          _t('network_requests_count')
              .replaceAll('{count}', '${incoming.length}'),
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      ...incoming.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: _avatarColor(f.name),
                  backgroundImage:
                      f.avatarUrl != null ? NetworkImage(f.avatarUrl!) : null,
                  child: f.avatarUrl == null
                      ? Text(
                          f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800),
                        )
                      : null),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      _t('network_wants_to_connect')
                          .replaceAll('{name}', f.name),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A)),
                tooltip: context.tr('tooltip_accept'),
                onPressed: () async {
                  await FriendshipService.instance.accept(f.uid);
                },
              ),
              IconButton(
                icon: Icon(Icons.cancel_rounded,
                    color: theme.colorScheme.outline),
                tooltip: context.tr('tooltip_reject'),
                onPressed: () async {
                  await FriendshipService.instance.remove(f.uid);
                },
              ),
            ]),
          )),
      const SizedBox(height: 20),
    ]);
  }

  // ── Bestätigte Freunde (UID-basiert) ──────────────────────────────────────
  Widget _uidFriendsSection(ThemeData theme) {
    final friends = FriendshipService.instance.friends;
    final outgoing = FriendshipService.instance.outgoing;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'my_friends'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (friends.isNotEmpty)
          Text('${friends.length} verbunden',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: const Color(0xFF7C3AED))),
      ]),
      const SizedBox(height: 12),
      if (friends.isEmpty)
        _emptyFriendsState(theme)
      else
        ...friends.map((f) => _uidFriendCard(theme, f)),
      if (outgoing.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Gesendete Anfragen',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        ...outgoing.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        _t('network_waiting_confirmation')
                            .replaceAll('{name}', f.name),
                        style: theme.textTheme.bodySmall)),
                TextButton(
                    onPressed: () => FriendshipService.instance.remove(f.uid),
                    child: Text(_t('network_withdraw'))),
              ]),
            )),
      ],
    ]);
  }

  // Freundes-Karte (UID-basiert) mit Chat, Melden, Entfernen.
  Widget _uidFriendCard(ThemeData theme, Friend f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        CircleAvatar(
            radius: 23,
            backgroundColor: _avatarColor(f.name),
            backgroundImage:
                f.avatarUrl != null ? NetworkImage(f.avatarUrl!) : null,
            child: f.avatarUrl == null
                ? Text(
                    f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  )
                : null),
        const SizedBox(width: 12),
        Expanded(
            child: Text(f.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchConversationScreen(
                profileId: f.roomId,
                profileName: f.name,
                isFriendChat: true,
              ),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
          label: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'chat_btn')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8B5CF6),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              size: 18, color: theme.colorScheme.outline),
          onSelected: (v) async {
            if (v == 'remove') {
              await FriendshipService.instance.remove(f.uid);
            } else if (v == 'block') {
              await BlockReportService.instance.blockUser(f.uid, f.name);
              await FriendshipService.instance.remove(f.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${f.name} wurde blockiert.'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            } else if (v == 'report') {
              showReportSheet(context,
                  userId: f.uid, userName: f.name, contentType: 'profile');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('Melden')),
            PopupMenuItem(value: 'block', child: Text('Blockieren')),
            PopupMenuItem(value: 'remove', child: Text('Entfernen')),
          ],
        ),
      ]),
    );
  }

  Widget _emptyFriendsState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
              child: Icon(Icons.group_add_rounded,
                  size: 28, color: Color(0xFF8B5CF6))),
        ),
        const SizedBox(height: 14),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'no_friends_yet'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_t('network_share_code_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _shareActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _suggestedParentsSection(ThemeData theme) {
    if (_loadingSuggestions) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6), strokeWidth: 2)));
    }
    if (_suggestedProfiles.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'maybe_you_know'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'real_parents_nearby'),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ]),
        Text(
            _t('network_suggestions_count')
                .replaceAll('{count}', '${_suggestedProfiles.length}'),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: const Color(0xFF8B5CF6))),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: _suggestedProfiles.length,
          itemBuilder: (ctx, i) =>
              _suggestionCard(theme, _suggestedProfiles[i]),
        ),
      ),
    ]);
  }

  Widget _suggestionCard(ThemeData theme, _SuggestedParent s) {
    final color = _avatarColor(s.name);
    final initial = s.name.isNotEmpty ? s.name[0].toUpperCase() : '?';

    return Container(
      width: 168,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(s.name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (s.kids.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(s.kids,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(s.reason,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const Spacer(),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () async {
                // Echte UID-Freundschaftsanfrage (neues System). s.id ist die
                // vollstaendige UID des Vorschlags.
                final ok = await FriendshipService.instance.sendRequest(s.id);
                if (mounted) {
                  setState(() {
                    _dismissedSuggestions.add(s.id);
                    _suggestedProfiles.removeWhere((x) => x.id == s.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'Anfrage an ${s.name} gesendet. 👋'
                        : 'Konnte nicht verbinden — bitte später erneut versuchen.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: ok ? const Color(0xFF16A34A) : null,
                  ));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'connect_btn')),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              if (mounted) {
                setState(() {
                  _dismissedSuggestions.add(s.id);
                  _suggestedProfiles.removeWhere((x) => x.id == s.id);
                });
                await prefs.setStringList(
                    'friends.dismissed', _dismissedSuggestions.toList());
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 16, color: theme.colorScheme.outline),
            ),
          ),
        ]),
      ]),
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF0EA5E9),
      Color(0xFF059669),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF6366F1),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  void _showFriendQR(ThemeData theme, String qrData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'show_this_code'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_t('network_scan_to_connect'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child:
                QrImageView(data: qrData, version: QrVersions.auto, size: 200),
          ),
          const SizedBox(height: 16),
          Text(_t('network_scan_to_connect'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'done_btn'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDeleteProfile(ThemeData theme) async {
    if (_deletingProfile) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'delete_profile')),
        content: Text(_t('network_delete_profile_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: Text(_t('delete'))),
        ],
      ),
    );
    if (confirmed != true || !mounted || _deletingProfile) return;
    setState(() => _deletingProfile = true);
    try {
      final uid = AuthService.instance.currentUser?.uid ?? '';
      final deleted = await PlaymateProfileService(matchingService: _matching)
          .deleteProfile(uid);
      if (!mounted) return;
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('network_delete_failed')),
          backgroundColor: theme.colorScheme.error,
        ));
        return;
      }
      setState(() {
        _profile = null;
        _matches = [];
        _loadingMatches = false;
      });
    } catch (e) {
      debugPrint('ElternNetzwerkScreen profile deletion failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('network_delete_failed')),
          backgroundColor: theme.colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _deletingProfile = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class _SuggestedParent {
  final String id;
  final String name;
  final String kids;
  final String reason;

  const _SuggestedParent({
    required this.id,
    required this.name,
    required this.kids,
    required this.reason,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFIL-WIZARD (5 Schritte)
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileForm extends StatefulWidget {
  final Future<void> Function(FamilyMatchProfile) onSave;
  const _ProfileForm({required this.onSave});
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 5;
  bool _saving = false;

  // Schritt 1: Grundinfos
  final _nameCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  PickedLocation? _pickedLocation;
  String _familyForm = 'kernfamilie';
  final _familyFormCustomCtrl = TextEditingController();

  // Schritt 2: Kinder
  final List<_ChildData> _children = [_ChildData()];

  // Schritt 3: Werte
  final Set<String> _values = {};
  final _valuesCustomCtrl = TextEditingController();

  // Schritt 4: Aktivitäten + Verfügbarkeit
  final Set<String> _lookingFor = {};
  final _lookingForCustomCtrl = TextEditingController();
  final Set<String> _availDays = {};
  final Set<String> _availTimes = {};
  final _availCustomCtrl = TextEditingController();

  // Schritt 5: Sprachen + Bio + Besonderheiten
  final Set<String> _langs = {'de'};
  final _bioCtrl = TextEditingController();
  final Set<String> _specials = {};
  final _specialsCustomCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Anzeigename aus dem Konto vorbelegen — Eltern tippen ihn nicht erneut.
    final accountName =
        AuthService.instance.currentUser?.displayName.trim() ?? '';
    if (accountName.isNotEmpty) {
      _nameCtrl.text = accountName;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _districtCtrl.dispose();
    _familyFormCustomCtrl.dispose();
    _valuesCustomCtrl.dispose();
    _lookingForCustomCtrl.dispose();
    _availCustomCtrl.dispose();
    _bioCtrl.dispose();
    _specialsCustomCtrl.dispose();
    for (final c in _children) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    // Validierung mit Feedback
    if (_nameCtrl.text.trim().isEmpty) {
      _showValidationError(_t('network_validation_name'));
      return;
    }
    if (_districtCtrl.text.trim().isEmpty) {
      _showValidationError(_t('network_validation_district'));
      return;
    }
    setState(() => _saving = true);
    try {
      final children = _children
          .map((c) => ChildEntry(
                name: c.nameCtrl.text.trim(),
                ageMonths: c.ageMonths,
                gender: c.gender,
                interests: c.interests.toList(),
                interestsCustom: c.interestsCustomCtrl.text.trim().isEmpty
                    ? null
                    : c.interestsCustomCtrl.text.trim(),
              ))
          .toList();

      final profile = FamilyMatchProfile(
        displayName: _nameCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        city: _pickedLocation?.city,
        latitude: coarseCoordinate(_pickedLocation?.lat),
        longitude: coarseCoordinate(_pickedLocation?.lon),
        children: children,
        languages: _langs.toList(),
        familyForm: _familyForm,
        familyFormCustom: _familyFormCustomCtrl.text.trim().isEmpty
            ? null
            : _familyFormCustomCtrl.text.trim(),
        values: _values.toList(),
        valuesCustom: _valuesCustomCtrl.text.trim().isEmpty
            ? null
            : _valuesCustomCtrl.text.trim(),
        lookingFor: _lookingFor.toList(),
        lookingForCustom: _lookingForCustomCtrl.text.trim().isEmpty
            ? null
            : _lookingForCustomCtrl.text.trim(),
        availDays: _availDays.toList(),
        availTimes: _availTimes.toList(),
        availCustom: _availCustomCtrl.text.trim().isEmpty
            ? null
            : _availCustomCtrl.text.trim(),
        specials: _specials.toList(),
        specialsCustom: _specialsCustomCtrl.text.trim().isEmpty
            ? null
            : _specialsCustomCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await widget.onSave(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_t('network_save_error').replaceAll('{error}', '$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      // Progress dots
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalSteps, (i) {
              final active = i == _step;
              final done = i < _step;
              return Container(
                width: active ? 28 : 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF16A34A)
                      : active
                          ? const Color(0xFF8B5CF6)
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            })),
      ),
      // Step label
      Text(_stepLabel(_step),
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6))),
      const SizedBox(height: 16),
      // Pages
      Expanded(
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _step1(theme),
            _step2(theme),
            _step3(theme),
            _step4(theme),
            _step5(theme)
          ],
        ),
      ),
      // Navigation
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          if (_step > 0)
            TextButton.icon(
                onPressed: _saving ? null : _prev,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(_t('network_back')))
          else
            const Spacer(),
          const Spacer(),
          if (_step < _totalSteps - 1)
            FilledButton.icon(
                onPressed: _saving ? null : _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'next_btn_wizard')),
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))))
          else
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_saving
                  ? _networkCopy('save', 'Speichern...')
                  : _networkCopy('create_profile', 'Profil erstellen')),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
        ]),
      ),
    ]);
  }

  static const _stepLabels = [
    'Schritt 1: Eure Familie',
    'Schritt 2: Eure Kinder',
    'Schritt 3: Werte & Stil',
    'Schritt 4: Was sucht ihr?',
    'Schritt 5: Sprachen & Mehr',
  ];

  String _stepLabel(int step) =>
      _networkCopy('step_${step + 1}', _stepLabels[step]);

  // ─── SCHRITT 1: Grundinfos ─────────────────────────────────────────────────
  Widget _step1(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _inputField(
              _nameCtrl,
              _networkCopy('name_hint', 'Euer Vorname / Spitzname'),
              _networkCopy('name_example', 'z.B. Sarah, Die Muellers'),
              Icons.person_rounded),
          const SizedBox(height: 14),
          LocationPickerWidget(
            hint: _networkCopy('location_hint', 'Euer Stadtteil / PLZ wählen'),
            onLocationPicked: (loc) {
              _pickedLocation = loc;
              _districtCtrl.text = loc.displayName;
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme,
              '\u{1F46A} ${_networkCopy('family_form', 'Familienform')}'),
          const SizedBox(height: 8),
          Text(_t('network_wizard_choose'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.familyForms.map((f) => ChoiceChip(
                  label: Text(
                      networkWizardOptionLabel(languageService.currentLanguage,
                          'family', f, MatchOptions.familyFormLabels[f] ?? f),
                      style: const TextStyle(fontSize: 12)),
                  selected: _familyForm == f,
                  onSelected: (_) => setState(() => _familyForm = f),
                  avatar: null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                )),
            ActionChip(
              label: Text('\u{2795} ${_networkCopy('custom', 'Eigene')}',
                  style: const TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _familyForm = 'custom'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
            ),
          ]),
          if (_familyForm == 'custom') ...[
            const SizedBox(height: 10),
            _inputField(
                _familyFormCustomCtrl,
                _networkCopy('custom_family', 'Eure Familienform'),
                _networkCopy(
                    'custom_example', 'z.B. Wahlfamilie, Mehrgenerationen...'),
                Icons.edit_rounded),
          ],
        ]));
  }

  // ─── SCHRITT 2: Kinder ─────────────────────────────────────────────────────
  Widget _step2(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text(_t('network_wizard_for_whom'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          ..._children
              .asMap()
              .entries
              .map((entry) => _childCard(theme, entry.key, entry.value)),
          const SizedBox(height: 12),
          Center(
              child: TextButton.icon(
            onPressed: () => setState(() => _children.add(_ChildData())),
            icon: const Icon(Icons.add_rounded),
            label: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'add_child_btn')),
          )),
        ]));
  }

  Widget _childCard(ThemeData theme, int index, _ChildData child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('\u{1F476} Kind ${index + 1}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_children.length > 1)
            IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: theme.colorScheme.error),
                onPressed: () => setState(() {
                      _children[index].dispose();
                      _children.removeAt(index);
                    })),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: child.nameCtrl,
            decoration: InputDecoration(
                labelText: _t('network_child_name_local'),
                hintText: 'z.B. Mia',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true)),
        const SizedBox(height: 12),
        // Alter Slider
        Row(children: [
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'age_label'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
              child: Slider(
            value: child.ageMonths.toDouble(),
            min: 0, max: 216, // 0 bis 18 Jahre
            divisions: 216,
            label: _ageLabel(child.ageMonths),
            onChanged: (v) => setState(() => child.ageMonths = v.round()),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_ageLabel(child.ageMonths),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6))),
          ),
        ]),
        const SizedBox(height: 10),
        // Geschlecht
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'gender_optional'),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
            spacing: 8,
            children: [null, ...MatchOptions.genderLabels.keys]
                .map((g) => ChoiceChip(
                      label: Text(
                          g == null
                              ? _networkCopy('no_gender', 'Keine Angabe')
                              : _networkCopy(
                                  'gender_$g',
                                  MatchOptions.genderLabels[g]!,
                                ),
                          style: const TextStyle(fontSize: 11)),
                      selected: child.gender == g,
                      onSelected: (_) => setState(() => child.gender = g),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        const SizedBox(height: 12),
        // Interessen
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'interests_label'),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ...MatchOptions.childInterests.map((i) => FilterChip(
                label: Text(
                    networkWizardOptionLabel(languageService.currentLanguage,
                        'child', i, MatchOptions.childInterestLabels[i] ?? i),
                    style: const TextStyle(fontSize: 10)),
                selected: child.interests.contains(i),
                onSelected: (s) => setState(() =>
                    s ? child.interests.add(i) : child.interests.remove(i)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                visualDensity: VisualDensity.compact,
              )),
          ActionChip(
            label:
                const Text('\u{2795} Eigenes', style: TextStyle(fontSize: 10)),
            onPressed: () => _showCustomInput(
                child.interestsCustomCtrl, 'Was mag dein Kind noch?'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
            visualDensity: VisualDensity.compact,
          ),
        ]),
        if (child.interestsCustomCtrl.text.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('\u{2728} ${child.interestsCustomCtrl.text}',
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic))),
      ]),
    );
  }

  String _ageLabel(int months) {
    if (months < 12) return '$months Mon.';
    final y = months ~/ 12;
    final m = months % 12;
    return m == 0 ? '$y Jahre' : '$y J. $m M.';
  }

  // ─── SCHRITT 3: Werte & Erziehungsstil ─────────────────────────────────────
  Widget _step3(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15))),
            child: Row(children: [
              const Text('\u{1F49A}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      _networkCopy('values_tip',
                          'Tipp: Familien mit ähnlichen Werten verstehen sich am besten. Wähle was euch wichtig ist.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                          height: 1.3)))
            ]),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '\u{2728} Was lebt ihr?'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.valueOptions.map((v) => FilterChip(
                  label: Text(
                      networkWizardOptionLabel(languageService.currentLanguage,
                          'values', v, MatchOptions.valueLabels[v] ?? v),
                      style: const TextStyle(fontSize: 11)),
                  selected: _values.contains(v),
                  onSelected: (s) =>
                      setState(() => s ? _values.add(v) : _values.remove(v)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  selectedColor: v == 'gfk'
                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                      : null,
                  checkmarkColor: v == 'gfk' ? const Color(0xFF16A34A) : null,
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'custom_value'),
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _valuesCustomCtrl, 'Was ist euch noch wichtig?'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_valuesCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_valuesCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
        ]));
  }

  // ─── SCHRITT 4: Aktivitaeten + Verfügbarkeit ──────────────────────────────
  Widget _step4(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F3AF} Was sucht ihr?'),
          const SizedBox(height: 6),
          Text(_t('network_wizard_activities'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.lookingForOptions.map((l) => FilterChip(
                  label: Text(
                      networkWizardOptionLabel(languageService.currentLanguage,
                          'looking', l, MatchOptions.lookingForLabels[l] ?? l),
                      style: const TextStyle(fontSize: 11)),
                  selected: _lookingFor.contains(l),
                  onSelected: (s) => setState(
                      () => s ? _lookingFor.add(l) : _lookingFor.remove(l)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'custom_idea'),
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _lookingForCustomCtrl, 'Was wünscht ihr euch noch?'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_lookingForCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_lookingForCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F4C5} Wann habt ihr Zeit?'),
          const SizedBox(height: 10),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'days_label'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MatchOptions.dayOptions
                  .map((d) => FilterChip(
                        label: Text(
                            networkWizardOptionLabel(
                                languageService.currentLanguage,
                                'days',
                                d,
                                MatchOptions.dayLabels[d] ?? d),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        selected: _availDays.contains(d),
                        onSelected: (s) => setState(
                            () => s ? _availDays.add(d) : _availDays.remove(d)),
                        shape: const CircleBorder(),
                        showCheckmark: false,
                        padding: const EdgeInsets.all(4),
                      ))
                  .toList()),
          const SizedBox(height: 14),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'times_label'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.timeOptions.map((t) => FilterChip(
                  label: Text(
                      networkWizardOptionLabel(languageService.currentLanguage,
                          'times', t, MatchOptions.timeLabels[t] ?? t),
                      style: const TextStyle(fontSize: 11)),
                  selected: _availTimes.contains(t),
                  onSelected: (s) => setState(
                      () => s ? _availTimes.add(t) : _availTimes.remove(t)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'other_time'),
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _availCustomCtrl, 'z.B. Nur in Ferien, Nur Feiertage...'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_availCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_availCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
        ]));
  }

  // ─── SCHRITT 5: Sprachen + Bio + Besonderheiten ────────────────────────────
  Widget _step5(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F30D} Welche Sprachen sprecht ihr?'),
          const SizedBox(height: 6),
          Text(_t('network_wizard_languages'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MatchOptions.languageLabels.entries
                  .map((e) => FilterChip(
                        label: Text(
                            networkWizardOptionLabel(
                                languageService.currentLanguage,
                                'language',
                                e.key,
                                e.value),
                            style: const TextStyle(fontSize: 11)),
                        selected: _langs.contains(e.key),
                        onSelected: (s) => setState(
                            () => s ? _langs.add(e.key) : _langs.remove(e.key)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        avatar: e.key == 'ku'
                            ? const AlaRenginFlag(width: 20, height: 14)
                            : null,
                      ))
                  .toList()),
          const SizedBox(height: 22),
          _sectionTitle(
              theme, '\u{1F4AC} ${_networkCopy('bio_title', 'Kurze Bio')}'),
          const SizedBox(height: 6),
          TextField(
              controller: _bioCtrl,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                  hintText: _networkCopy('bio_hint',
                      'Erzaehlt kurz von euch: Was macht eure Familie besonders? Was wuenscht ihr euch?'),
                  hintStyle:
                      TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF8B5CF6), width: 1.5)))),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F49C} Besonderheiten (optional)'),
          const SizedBox(height: 6),
          Text(_t('network_specials_local'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.specialOptions.map((s) => FilterChip(
                  label: Text(
                      networkWizardOptionLabel(languageService.currentLanguage,
                          'specials', s, MatchOptions.specialLabels[s] ?? s),
                      style: const TextStyle(fontSize: 11)),
                  selected: _specials.contains(s),
                  onSelected: (sel) => setState(
                      () => sel ? _specials.add(s) : _specials.remove(s)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'custom_entry'),
                  style: const TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(_specialsCustomCtrl,
                  _t('network_specials_hint')),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_specialsCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_specialsCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
          const SizedBox(height: 20),
        ]));
  }

  // ─── Hilfsmethoden ─────────────────────────────────────────────────────────
  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(text,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800));
  }

  Widget _inputField(
      TextEditingController ctrl, String label, String hint, IconData icon) {
    return TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
        ));
  }

  void _showCustomInput(TextEditingController ctrl, String hint) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 60,
                  decoration: InputDecoration(
                      hintText: hint,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onSubmitted: (_) {
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                        child: Text(_t('done')))),
              ]),
            ),
          );
        });
  }
}

// ─── Kind-Daten Helfer ───────────────────────────────────────────────────────
class _ChildData {
  final nameCtrl = TextEditingController();
  final interestsCustomCtrl = TextEditingController();
  int ageMonths = 36; // default 3 Jahre
  String? gender;
  final Set<String> interests = {};

  void dispose() {
    nameCtrl.dispose();
    interestsCustomCtrl.dispose();
  }
}

// ─── Location Autocomplete Widget ────────────────────────────────────────────

class _LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(LocationSuggestion) onSelected;

  const _LocationAutocompleteField({
    required this.controller,
    required this.onSelected,
  });

  @override
  State<_LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<_LocationAutocompleteField> {
  final _service = LocationAutocompleteService.instance;
  List<LocationSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    final text = widget.controller.text.trim();
    if (text.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final results = await _service.searchImmediate(text);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'Stadtteil oder PLZ',
          hintText: 'Tippe z.B. Kreuzberg, 10997...',
          prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() {
                          _suggestions = [];
                          _showSuggestions = false;
                        });
                      })
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
          ),
        ),
      ),
      if (_showSuggestions) ...[
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 44,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (ctx, i) {
              final s = _suggestions[i];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place_rounded,
                      size: 16, color: Color(0xFF8B5CF6)),
                ),
                title: Text(s.shortLabel,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: s.postcode.isNotEmpty
                    ? Text(s.postcode,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline))
                    : null,
                onTap: () {
                  widget.controller.text = s.shortLabel;
                  widget.controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: s.shortLabel.length));
                  setState(() => _showSuggestions = false);
                  widget.onSelected(s);
                },
              );
            },
          ),
        ),
      ],
    ]);
  }
}
