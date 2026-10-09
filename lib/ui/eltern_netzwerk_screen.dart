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
import 'package:parentpeak/logic/playmate_suggestions.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friendship_service.dart';
import 'package:parentpeak/logic/user_profile_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/services/block_report_service.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';
import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/ui/widgets/playmate_publication_dialog.dart';
import 'package:parentpeak/ui/widgets/playmate_profile_status.dart';
import 'package:parentpeak/ui/widgets/playmate_discovery_error.dart';
import 'package:parentpeak/ui/widgets/playmate_discovery_empty_state.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/match_conversation_screen.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

String networkWizardOptionLabel(
  String language,
  String group,
  String key,
  String fallback,
) {
  final translationKey = 'network_option_${group}_$key';
  final label = AppStringsManager.getString(language, translationKey);
  return label == translationKey ? fallback : label;
}

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);

String networkMatchReasonLabel(String language, String code) {
  final key = 'network_copy_reason_$code';
  final label = AppStringsManager.getString(language, key);
  return label == key ? code : label;
}

String networkChildAgeLabel(String language, String tag) {
  final match = RegExp(r'^(\d+)([JM])$').firstMatch(tag);
  if (match == null) return tag;
  final years = match[2] == 'J';
  return AppStringsManager.getString(
    language,
    years ? 'network_age_years' : 'network_age_months',
  ).replaceAll(years ? '{years}' : '{months}', match[1]!);
}

class ElternNetzwerkScreen extends StatefulWidget {
  final String? initialFriendCode;

  /// 0 = Chats, 1 = Netzwerk, 2 = Spielfreunde
  final int initialTab;
  const ElternNetzwerkScreen({
    super.key,
    this.initialFriendCode,
    this.initialTab = 0,
  });
  @override
  State<ElternNetzwerkScreen> createState() => _ScreenState();
}

class _ScreenState extends State<ElternNetzwerkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _matching = ParentMatchingBackendService(
    apiClient: BackendServiceFactory.createApiClient(),
  );
  FamilyMatchProfile? _profile;
  bool _editingProfile = false;
  bool _deletingProfile = false;
  bool _profileLoading = true;
  bool _assigningDraft = false;
  bool _hasUnassignedDraft = false;
  String? _profileAccount;
  int _profileRequest = 0;
  PlaymateProfileStatus _profileStatus = PlaymateProfileStatus.unavailable;
  Set<String> _dismissedSuggestions = {};

  // Echte Spielfreunde-Discovery (nutzt /api/parent-matching/find)
  List<MatchResult> _matches = [];
  bool _loadingMatches = false;
  String? _matchesErrorKey;
  int _matchRequest = 0;
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
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    FriendshipService.instance.addListener(_rebuild);
    _profileAccount = AuthService.instance.currentUser?.uid;
    AuthService.instance.addListener(_onAccountChanged);
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
    AuthService.instance.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onAccountChanged() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == _profileAccount) return;
    setState(() {
      _profileAccount = uid;
      _profile = null;
      _editingProfile = false;
      _hasUnassignedDraft = false;
      _matches = [];
      _loadingMatches = false;
      _matchesErrorKey = null;
      _matchRequest++;
      _conversations = [];
      _loadingConversations = false;
      _profileStatus = PlaymateProfileStatus.unavailable;
    });
    unawaited(_refreshProfile());
    unawaited(_loadConversations());
  }

  Future<void> _refreshProfile() async {
    final request = ++_profileRequest;
    final uid = AuthService.instance.currentUser?.uid;
    if (mounted) {
      setState(() {
        _profileLoading = true;
        _profileStatus = PlaymateProfileStatus.unavailable;
      });
    }
    try {
      final state = uid == null || uid.isEmpty
          ? const PlaymateProfileState(
              status: PlaymateProfileStatus.unavailable,
            )
          : await PlaymateProfileService(
              matchingService: _matching,
            ).loadState(uid);
      if (!mounted ||
          request != _profileRequest ||
          AuthService.instance.currentUser?.uid != uid) {
        return;
      }
      setState(() {
        _profile = state.profile;
        _profileStatus = state.status;
        _hasUnassignedDraft = state.hasUnassignedDraft;
        _profileLoading = false;
        _matches = [];
      });
      if (state.status == PlaymateProfileStatus.active &&
          state.profile != null) {
        unawaited(_loadMatches());
      }
    } catch (e) {
      debugPrint('ElternNetzwerkScreen profile verification failed: $e');
      if (!mounted ||
          request != _profileRequest ||
          AuthService.instance.currentUser?.uid != uid) {
        return;
      }
      setState(() {
        _profileStatus = PlaymateProfileStatus.unavailable;
        _profileLoading = false;
      });
    }
  }

  Future<void> _assignDraft() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _assigningDraft) return;
    setState(() => _assigningDraft = true);
    try {
      final assigned = await PlaymateProfileService(matchingService: _matching)
          .adoptUnassignedDraft(
            uid,
            confirmOwnership: () async {
              final confirmed = await confirmPlaymateDraftOwnership(
                context,
                AuthService.instance.currentUser?.displayName ?? uid,
              );
              return mounted &&
                  AuthService.instance.currentUser?.uid == uid &&
                  confirmed;
            },
          );
      if (!mounted || AuthService.instance.currentUser?.uid != uid) return;
      if (assigned) await _refreshProfile();
    } catch (e) {
      debugPrint('ElternNetzwerkScreen draft assignment failed: $e');
      if (mounted && AuthService.instance.currentUser?.uid == uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('network_draft_assign_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningDraft = false);
    }
  }

  /// Lädt die Messenger-Übersicht (alle Unterhaltungen) für den Chats-Tab.
  Future<void> _loadConversations() async {
    final ticket = ProfileAccountStore.instance.ticket;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loadingConversations = false);
      return;
    }
    if (mounted) setState(() => _loadingConversations = true);
    try {
      final list = await FriendChatService.instance.fetchOverview(uid);
      if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return;
      setState(() {
        _conversations = list;
        _loadingConversations = false;
      });
    } catch (error) {
      debugPrint('Chat overview failed: $error');
      if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return;
      setState(() => _loadingConversations = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('friend_chat_request_failed'))),
      );
    }
  }

  /// Öffnet eine Unterhaltung und markiert sie als gelesen.
  Future<void> _openConversation({
    required String roomId,
    required String title,
    required bool isGroup,
    String? photoUrl,
  }) async {
    final ticket = ProfileAccountStore.instance.ticket;
    final uid = AuthService.instance.currentUser?.uid ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isGroup
            ? GroupChatScreen(
                roomId: roomId,
                groupName: title,
                photoUrl: photoUrl,
              )
            : MatchConversationScreen(
                profileId: roomId,
                profileName: title,
                isFriendChat: true,
              ),
      ),
    );
    // Nach Rückkehr: als gelesen markieren und Übersicht aktualisieren.
    if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return;
    if (uid.isNotEmpty) {
      try {
        await FriendChatService.instance.markRead(roomId, uid);
      } catch (error) {
        debugPrint('Chat read marker failed: $error');
        if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('friend_chat_request_failed'))),
        );
      }
    }
    await _loadConversations();
  }

  /// Einladungslink (/f/<token>) verarbeiten: Einladenden auflösen und eine
  /// Freundschaftsanfrage senden — 1 Tap, kein Code-Abtippen.
  Future<void> _handleInviteToken(String token) async {
    final resolved = await FriendshipService.instance.resolveInvite(token);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('network_invalid_invite')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = resolved['name']?.isNotEmpty == true
        ? resolved['name']!
        : _t('network_family_fallback');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('network_copy_connect')),
        content: Text(_t('network_connect_confirm').replaceAll('{name}', name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('network_copy_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('network_copy_connect_button')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await FriendshipService.instance.sendRequest(resolved['uid']!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? _t('network_copy_request_sent').replaceAll('{name}', name)
              : _t('network_copy_request_failed'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: sent ? const Color(0xFF16A34A) : null,
      ),
    );
  }

  /// Alter Freund-Link (parentpeak.de/freund/<CODE>): den Code ueber die noch
  /// vorhandene lookup-Bruecke in eine UID aufloesen und eine Anfrage senden.
  /// So funktionieren bereits geteilte alte Links weiter — ohne Code-Eingabe.
  Future<void> _handleLegacyCodeLink(String code) async {
    final resolved = await FriendshipService.instance.resolveCode(code);
    if (!mounted) return;
    if (resolved == null || (resolved['uid'] ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('network_legacy_link_inactive')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final name = resolved['name']?.isNotEmpty == true
        ? resolved['name']!
        : _t('network_family_fallback');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('network_copy_connect')),
        content: Text(_t('network_connect_confirm').replaceAll('{name}', name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('network_copy_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('network_copy_connect_button')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await FriendshipService.instance.sendRequest(resolved['uid']!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? _t('network_copy_request_sent').replaceAll('{name}', name)
              : _t('network_copy_request_failed'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: sent ? const Color(0xFF16A34A) : null,
      ),
    );
  }

  Future<void> _init() async {
    final ticket = ProfileAccountStore.instance.ticket;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('friends.dismissed') ?? [];
    if (mounted) setState(() => _dismissedSuggestions = dismissed.toSet());
    await _refreshProfile();
    if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return;

    // NEUES FUNDAMENT: den app-weiten Anzeigenamen serverseitig sichern
    // (uid -> displayName). Kommt aus der Registrierung; hier nur gespiegelt.
    final myName =
        AuthService.instance.currentUser?.displayName ??
        _profile?.displayName ??
        'Familie';
    unawaited(UserProfileService.instance.setDisplayName(myName, ticket: ticket).catchError((Object error) {
      debugPrint('Network profile identity sync failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('profile_account_failed'))));
      }
    }));
    // Neue UID-Freundschaften + offene Anfragen laden.
    unawaited(FriendshipService.instance.load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStringsManager.getString(
            languageService.currentLanguage,
            'eltern_netzwerk_title',
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: _t('network_tab_chats')),
            Tab(text: _t('network_tab_network')),
            Tab(text: _t('network_copy_playmates')),
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

    return Column(
      children: [
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
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
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
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    itemBuilder: (_, i) =>
                        _conversationTile(theme, filtered[i]),
                  ),
          ),
        ),
      ],
    );
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
                  fontWeight: FontWeight.w800,
                ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  UserAvatar(
                    name: c.isGroup ? (c.name ?? 'G') : title,
                    photoUrl: c.photoUrl.isNotEmpty ? c.photoUrl : null,
                    isGroup: c.isGroup,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
              leading: Icon(
                Icons.delete_forever_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                _t('chat_delete_for_all'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: Text(_t('chat_delete_for_all_hint')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmChatDelete(c, title, forAll: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmChatDelete(
    ConversationSummary c,
    String title, {
    required bool forAll,
  }) async {
    final ticket = ProfileAccountStore.instance.ticket;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          forAll ? _t('chat_delete_for_all') : _t('chat_delete_for_me'),
        ),
        content: Text(
          forAll
              ? _t('chat_delete_for_all_confirm')
              : _t('chat_delete_for_me_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: forAll
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  )
                : null,
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !ProfileAccountStore.instance.isCurrent(ticket)) return;
    final uid = AuthService.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final ok = forAll
        ? await FriendChatService.instance.deleteForAll(c.roomId, uid)
        : await FriendChatService.instance.clearForMe(c.roomId, uid);
    if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? _t('chat_deleted') : _t('chat_delete_failed')),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadConversations();
  }

  Widget _chatsLoadingSkeleton(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        6,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
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
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 220,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 34,
              color: Color(0xFF8B5CF6),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _t('network_chats_empty_title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t('network_chats_empty_desc'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: _showNewChatOptions,
            icon: const Icon(Icons.add_comment_rounded, size: 18),
            label: Text(_t('network_new_chat')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF7C3AED),
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              title: Text(
                _t('network_start_direct_chat'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
              title: Text(
                _t('network_create_group'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_t('network_create_group_hint')),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showCreateGroupSheet();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Gruppe erstellen: Name eingeben + Freunde als Mitglieder wählen.
  Future<void> _showCreateGroupSheet() async {
    final friends = FriendshipService.instance.friends;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('network_group_needs_friends')),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                ],
              ),
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

        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final theme = Theme.of(sheetCtx);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t('network_create_group'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Gruppen-Foto (optional) — tippen zum Auswählen/Ändern.
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: saving ? null : () => pickGroupPhoto(setSheet),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(
                              0xFF0EA5A4,
                            ).withValues(alpha: 0.15),
                            backgroundImage: photoBytes != null
                                ? MemoryImage(photoBytes!)
                                : null,
                            child: photoBytes == null
                                ? const Icon(
                                    Icons.groups_rounded,
                                    size: 32,
                                    color: Color(0xFF0EA5A4),
                                  )
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
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('network_group_photo_hint'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: _t('network_group_name'),
                      hintText: _t('network_group_name_hint'),
                      prefixIcon: const Icon(Icons.groups_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _t('network_choose_members'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _t('network_group_name_required'),
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (selected.isEmpty) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _t('network_group_select_member'),
                                    ),
                                  ),
                                );
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_t('network_create_group')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameCtrl.dispose();
    if (created == true) await _loadConversations();
  }

  Future<bool> _createGroup(
    String name,
    List<String> memberUids,
    List<Friend> friends,
    Uint8List? photoBytes,
  ) async {
    final ticket = ProfileAccountStore.instance.ticket;
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
    if (!ProfileAccountStore.instance.isCurrent(ticket)) return false;
    final group = await FriendChatService.instance.createGroup(
      name: name,
      ownerUserId: uid,
      ownerName: ownerName,
      memberUids: memberUids,
      memberNames: memberNames,
      photoUrl: photoUrl,
    );
    if (!mounted || !ProfileAccountStore.instance.isCurrent(ticket)) return false;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('network_group_create_failed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    if (_profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profileAccount == null) {
      return Center(child: Text(_t('network_copy_login_required')));
    }
    if (_profile != null &&
        !_editingProfile &&
        _profileStatus != PlaymateProfileStatus.active) {
      return Column(
        children: [
          _profileStatusPanel(),
          TextButton(
            onPressed: () => setState(() => _editingProfile = true),
            child: Text(_t('edit_btn')),
          ),
          TextButton(
            onPressed: _deletingProfile
                ? null
                : () => _confirmDeleteProfile(theme),
            child: Text(_t('delete')),
          ),
        ],
      );
    }
    if (_profile == null || _editingProfile) return _profileSetup(theme);
    return _discoveryView(theme);
  }

  Widget _profileStatusPanel() => PlaymateProfileStatusPanel(
    status: _profileStatus,
    hasUnassignedDraft: _hasUnassignedDraft,
    onRetry: _refreshProfile,
    onAssignDraft: _assigningDraft ? null : _assignDraft,
  );

  Widget _profileSetup(ThemeData theme) {
    return Column(
      children: [
        _profileStatusPanel(),
        if (_profile == null && _profileStatus == PlaymateProfileStatus.active)
          TextButton(
            onPressed: _deletingProfile
                ? null
                : () => _confirmDeleteProfile(theme),
            child: Text(_t('delete')),
          ),
        const SizedBox(height: 16),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text('\u{1F46A}', style: TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppStringsManager.getString(
            languageService.currentLanguage,
            'find_playmates',
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _t('network_copy_setup_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PlaymateProfileForm(
            key: ValueKey(_profileAccount),
            initialProfile: _profile,
            onCancel: _editingProfile
                ? () => setState(() => _editingProfile = false)
                : null,
            onSave: (p) async {
              final uid = AuthService.instance.currentUser?.uid;
              if (uid == null || uid.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_t('network_copy_login_required'))),
                  );
                }
                return;
              }
              try {
                final result =
                    await PlaymateProfileService(
                      matchingService: _matching,
                    ).publishProfile(
                      p,
                      uid,
                      confirmPublication: () async {
                        final confirmed = await confirmPlaymatePublication(
                          context,
                        );
                        return mounted &&
                            AuthService.instance.currentUser?.uid == uid &&
                            confirmed;
                      },
                    );
                if (!mounted || result == PlaymatePublicationResult.cancelled) {
                  return;
                }
                if (AuthService.instance.currentUser?.uid != uid) return;
                if (result == PlaymatePublicationResult.failed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_t('network_publish_failed')),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }
              } on SuspendedAccountException {
                if (mounted) await showAccountSuspendedNotice(context);
                return;
              }
              setState(() => _editingProfile = false);
              await _init();
            },
          ),
        ),
      ],
    );
  }

  /// Laedt echte Familien in der Naehe ueber das bestehende Matching-Backend.
  Future<void> _loadMatches() async {
    if (_profile == null || _profileStatus != PlaymateProfileStatus.active) {
      return;
    }
    final request = _profileRequest;
    final matchRequest = ++_matchRequest;
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
      if (mounted &&
          _profile != null &&
          request == _profileRequest &&
          matchRequest == _matchRequest &&
          AuthService.instance.currentUser?.uid == uid &&
          _profileStatus == PlaymateProfileStatus.active) {
        setState(() {
          _matches = visible;
          _matchScope = result.scope;
          _loadingMatches = false;
          _matchesErrorKey = null;
        });
      }
    } catch (e) {
      debugPrint('ElternNetzwerkScreen discovery failed: $e');
      if (mounted &&
          request == _profileRequest &&
          matchRequest == _matchRequest &&
          AuthService.instance.currentUser?.uid == uid) {
        setState(() {
          _loadingMatches = false;
          _matchesErrorKey =
              e is BackendApiException && (e.isUnauthorized || e.isForbidden)
              ? 'network_discovery_auth_failed'
              : 'network_discovery_failed';
        });
      }
    }
  }

  Widget _discoveryView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileStatusPanel(),
            // ── Eigenes Profil (Header) ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  const Text('\u{1F46A}', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(
                            'network_family_name',
                          ).replaceAll('{name}', _profile!.displayName),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _profile!.bio.isNotEmpty
                              ? _profile!.bio
                              : _t('network_profile_active'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _deletingProfile
                            ? null
                            : () => setState(() => _editingProfile = true),
                        child: Text(
                          AppStringsManager.getString(
                            languageService.currentLanguage,
                            'edit_btn',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _deletingProfile
                            ? null
                            : () => _confirmDeleteProfile(theme),
                        child: Text(
                          _t('delete'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Titelzeile Discovery ─────────────────────────────────────────
            Row(
              children: [
                const Text('\u{1F50D}', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('network_families_nearby'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_loadingMatches)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _loadMatches,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            if (!_loadingMatches &&
                _matchesErrorKey == null &&
                _matches.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _matchScope == '10km'
                    ? _t('network_radius').replaceAll('{distance}', '10')
                    : _matchScope == '50km'
                    ? _t('network_radius').replaceAll('{distance}', '50')
                    : _matchScope == '100km'
                    ? _t('network_radius').replaceAll('{distance}', '100')
                    : _t('network_wide_radius'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ── Ergebnis: Liste, Loading oder ehrlicher Empty-State ──────────
            if (_loadingMatches)
              _matchesLoadingSkeleton(theme)
            else if (_matchesErrorKey != null)
              PlaymateDiscoveryError(
                messageKey: _matchesErrorKey!,
                onRetry: _loadMatches,
              )
            else if (_matches.isEmpty)
              PlaymateDiscoveryEmptyState(tabs: _tabs)
            else
              ..._matches.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _matchCard(theme, m),
                ),
              ),
          ],
        ),
      ),
    );
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
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  /// Karte einer echten gematchten Familie mit Verbinden-Aktion.
  Widget _matchCard(ThemeData theme, MatchResult m) {
    final p = m.profile;
    final kids = p.childAges.isEmpty
        ? ''
        : '\u{1F9D2} ${p.childAges.map((tag) => networkChildAgeLabel(languageService.currentLanguage, tag)).join(' \u{2022} ')}';
    final distanceKm = m.breakdown['distanceKm'];
    final reasonCodes = (m.breakdown['reasons'] as List? ?? const [])
        .map((reason) => reason.toString())
        .take(3);
    final meta = <String>[
      if (distanceKm != null) '\u{1F4CD} $distanceKm km',
      if (distanceKm == null && m.breakdown['locationLabel'] == 'same_city')
        _t('network_copy_same_city'),
      if (p.languages.isNotEmpty)
        p.languages
            .take(3)
            .map(
              (code) => networkWizardOptionLabel(
                languageService.currentLanguage,
                'language',
                code,
                code,
              ),
            )
            .join(', '),
    ].join('  \u{2022}  ');
    final tags = <String>[
      ...p.valuesFocus
          .take(2)
          .map(
            (code) => networkWizardOptionLabel(
              languageService.currentLanguage,
              'values',
              code,
              code,
            ),
          ),
      ...p.interests
          .take(2)
          .map(
            (code) => networkWizardOptionLabel(
              languageService.currentLanguage,
              'looking',
              code,
              code,
            ),
          ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Text('\u{1F46A}', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (p.city.isNotEmpty)
                      Text(
                        p.city,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (m.score > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _t(
                      'network_match_score',
                    ).replaceAll('{score}', '${m.score}'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
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
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(_t('network_report')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded, size: 18),
                        const SizedBox(width: 10),
                        Text(_t('network_block')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (kids.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              kids,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (reasonCodes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reasonCodes
                  .map(
                    (code) => Text(
                      networkMatchReasonLabel(
                        languageService.currentLanguage,
                        code,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF0E7F77),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _connectWithMatch(m),
              icon: const Icon(Icons.waving_hand_rounded, size: 16),
              label: Text(_t('network_say_hello')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? _t(
                  'network_copy_request_sent',
                ).replaceAll('{name}', m.profile.name)
              : _t('network_copy_request_failed'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF16A34A) : errorColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _t('network_blocked').replaceAll('{name}', m.profile.name),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: NETZWERK (Freunde, Anfragen, Vorschläge, Einladen)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _netzwerkTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Einladungs-Karte: verbinden per Link/QR (1 Tap) ────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5B21B6),
                  Color(0xFF7C3AED),
                  Color(0xFF8B5CF6),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.group_add_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  _t('network_copy_invite_hero_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t('network_copy_invite_hero_description'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _shareActionBtn(
                        Icons.ios_share_rounded,
                        _t('network_copy_share'),
                        () async {
                          final box = context.findRenderObject() as RenderBox?;
                          // Frischen Einladungslink erzeugen (1-Tap-Verbinden).
                          final link = await FriendshipService.instance
                              .createInviteLink();
                          if (link == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _t('network_link_create_failed'),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            return;
                          }
                          await Share.share(
                            _t(
                              'network_share_message',
                            ).replaceAll('{link}', link),
                            sharePositionOrigin: box != null
                                ? box.localToGlobal(Offset.zero) & box.size
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _shareActionBtn(
                        Icons.qr_code_2_rounded,
                        _t('network_qr_code'),
                        () async {
                          final link = await FriendshipService.instance
                              .createInviteLink();
                          if (!mounted) return;
                          if (link == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_t('network_qr_create_failed')),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          _showFriendQR(theme, link);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _suggestedParentsSection(theme),
          const SizedBox(height: 32),

          // NEUES UID-Fundament: offene Anfragen + Freundesliste vom Server.
          _friendRequestsSection(theme),
          _uidFriendsSection(theme),
        ],
      ),
    );
  }

  // ── Eingehende Freundschaftsanfragen (annehmen/ablehnen) ──────────────────
  Widget _friendRequestsSection(ThemeData theme) {
    final incoming = FriendshipService.instance.incoming;
    if (incoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            'network_requests_count',
          ).replaceAll('{count}', '${incoming.length}'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...incoming.map(
          (f) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _avatarColor(f.name),
                  backgroundImage: f.avatarUrl != null
                      ? NetworkImage(f.avatarUrl!)
                      : null,
                  child: f.avatarUrl == null
                      ? Text(
                          f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t('network_wants_to_connect').replaceAll('{name}', f.name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                  ),
                  tooltip: context.tr('tooltip_accept'),
                  onPressed: () async {
                    await FriendshipService.instance.accept(f.uid);
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.cancel_rounded,
                    color: theme.colorScheme.outline,
                  ),
                  tooltip: context.tr('tooltip_reject'),
                  onPressed: () async {
                    await FriendshipService.instance.remove(f.uid);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Bestätigte Freunde (UID-basiert) ──────────────────────────────────────
  Widget _uidFriendsSection(ThemeData theme) {
    final friends = FriendshipService.instance.friends;
    final outgoing = FriendshipService.instance.outgoing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStringsManager.getString(
                languageService.currentLanguage,
                'my_friends',
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (friends.isNotEmpty)
              Text(
                _t(
                  'network_connected_count',
                ).replaceAll('{count}', '${friends.length}'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF7C3AED),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (friends.isEmpty)
          _emptyFriendsState(theme)
        else
          ...friends.map((f) => _uidFriendCard(theme, f)),
        if (outgoing.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _t('network_outgoing_requests'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          ...outgoing.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t(
                        'network_waiting_confirmation',
                      ).replaceAll('{name}', f.name),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => FriendshipService.instance.remove(f.uid),
                    child: Text(_t('network_withdraw')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
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
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: _avatarColor(f.name),
            backgroundImage: f.avatarUrl != null
                ? NetworkImage(f.avatarUrl!)
                : null,
            child: f.avatarUrl == null
                ? Text(
                    f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              f.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
            label: Text(
              AppStringsManager.getString(
                languageService.currentLanguage,
                'chat_btn',
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            onSelected: (v) async {
              if (v == 'remove') {
                await FriendshipService.instance.remove(f.uid);
              } else if (v == 'block') {
                await BlockReportService.instance.blockUser(f.uid, f.name);
                await FriendshipService.instance.remove(f.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _t('network_blocked').replaceAll('{name}', f.name),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else if (v == 'report') {
                showReportSheet(
                  context,
                  userId: f.uid,
                  userName: f.name,
                  contentType: 'profile',
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'report', child: Text(_t('network_report'))),
              PopupMenuItem(value: 'block', child: Text(_t('network_block'))),
              PopupMenuItem(value: 'remove', child: Text(_t('remove_btn'))),
            ],
          ),
        ],
      ),
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
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.group_add_rounded,
                size: 28,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'no_friends_yet',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t('network_share_code_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestedParentsSection(ThemeData theme) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null ||
        uid.isEmpty ||
        _profileStatus != PlaymateProfileStatus.active) {
      return const SizedBox.shrink();
    }
    if (_loadingMatches) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_matchesErrorKey != null) {
      return PlaymateDiscoveryError(
        messageKey: _matchesErrorKey!,
        onRetry: _loadMatches,
      );
    }
    final suggestions = selectPlaymateSuggestions(
      matches: _matches,
      userId: uid,
      friendIds: FriendshipService.instance.friends.map((f) => f.uid).toSet(),
      dismissedIds: _dismissedSuggestions,
      isBlocked: BlockReportService.instance.isBlocked,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'maybe_you_know',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'network_matching_suggestions',
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _t(
                'network_suggestions_count',
              ).replaceAll('{count}', '${suggestions.length}'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: suggestions.length,
            itemBuilder: (ctx, i) => _suggestionCard(theme, suggestions[i]),
          ),
        ),
      ],
    );
  }

  Widget _suggestionCard(ThemeData theme, PlaymateSuggestion s) {
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
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (s.childAgeTags.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              s.childAgeTags
                  .map(
                    (tag) => networkChildAgeLabel(
                      languageService.currentLanguage,
                      tag,
                    ),
                  )
                  .join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          if (s.city.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.city,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final account = AuthService.instance.currentUser?.uid;
                    final ok = await FriendshipService.instance.sendRequest(
                      s.userId,
                    );
                    if (mounted &&
                        AuthService.instance.currentUser?.uid == account) {
                      if (ok) {
                        setState(() => _dismissedSuggestions.add(s.userId));
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? _t(
                                    'network_copy_request_sent',
                                  ).replaceAll('{name}', s.name)
                                : _t('network_copy_request_failed'),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: ok ? const Color(0xFF16A34A) : null,
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'connect_btn',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  final account = AuthService.instance.currentUser?.uid;
                  final prefs = await SharedPreferences.getInstance();
                  if (mounted &&
                      AuthService.instance.currentUser?.uid == account) {
                    setState(() {
                      _dismissedSuggestions.add(s.userId);
                    });
                    await prefs.setStringList(
                      'friends.dismissed',
                      _dismissedSuggestions.toList(),
                    );
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStringsManager.getString(
                languageService.currentLanguage,
                'show_this_code',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _t('network_scan_to_connect'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
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
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _t('network_scan_to_connect'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'done_btn',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProfile(ThemeData theme) async {
    if (_deletingProfile) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppStringsManager.getString(
            languageService.currentLanguage,
            'delete_profile',
          ),
        ),
        content: Text(_t('network_delete_profile_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _deletingProfile) return;
    if (AuthService.instance.currentUser?.uid != uid) return;
    setState(() => _deletingProfile = true);
    try {
      final deleted = await PlaymateProfileService(
        matchingService: _matching,
      ).deleteProfile(uid);
      if (!mounted || AuthService.instance.currentUser?.uid != uid) return;
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('network_delete_failed')),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        return;
      }
      setState(() {
        _profile = null;
        _profileStatus = PlaymateProfileStatus.draft;
        _editingProfile = false;
        _profileRequest++;
        _matches = [];
        _loadingMatches = false;
      });
    } catch (e) {
      debugPrint('ElternNetzwerkScreen profile deletion failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('network_delete_failed')),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingProfile = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFIL-WIZARD (5 Schritte)
// ═══════════════════════════════════════════════════════════════════════════════

class PlaymateProfileForm extends StatefulWidget {
  final Future<void> Function(FamilyMatchProfile) onSave;
  final FamilyMatchProfile? initialProfile;
  final VoidCallback? onCancel;
  const PlaymateProfileForm({
    super.key,
    required this.onSave,
    this.initialProfile,
    this.onCancel,
  });
  @override
  State<PlaymateProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<PlaymateProfileForm> {
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
  final List<_ChildData> _children = [];

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
    final initial = widget.initialProfile;
    if (initial != null) {
      _nameCtrl.text = initial.displayName;
      _districtCtrl.text = initial.district;
      if (initial.latitude != null && initial.longitude != null) {
        _pickedLocation = PickedLocation(
          displayName: initial.district,
          city: initial.city ?? initial.district,
          postcode: '',
          lat: initial.latitude!,
          lon: initial.longitude!,
        );
      }
      _familyForm = initial.familyForm;
      _familyFormCustomCtrl.text = initial.familyFormCustom ?? '';
      _children.addAll(initial.children.map((c) => _ChildData(initial: c)));
      _values.addAll(initial.values);
      _valuesCustomCtrl.text = initial.valuesCustom ?? '';
      _lookingFor.addAll(initial.lookingFor);
      _lookingForCustomCtrl.text = initial.lookingForCustom ?? '';
      _availDays.addAll(initial.availDays);
      _availTimes.addAll(initial.availTimes);
      _availCustomCtrl.text = initial.availCustom ?? '';
      _langs
        ..clear()
        ..addAll(initial.languages);
      _bioCtrl.text = initial.bio;
      _specials.addAll(initial.specials);
      _specialsCustomCtrl.text = initial.specialsCustom ?? '';
      return;
    }
    _children.add(_ChildData());
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
          .map(
            (c) => ChildEntry(
              name: c.nameCtrl.text.trim(),
              birthDate: c.birthDate,
              ageMonths: c.ageMonths,
              gender: c.gender,
              interests: c.interests.toList(),
              interestsCustom: c.interestsCustomCtrl.text.trim().isEmpty
                  ? null
                  : c.interestsCustomCtrl.text.trim(),
            ),
          )
          .toList();

      final profile = FamilyMatchProfile(
        displayName: _nameCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        city: _pickedLocation?.city ?? widget.initialProfile?.city,
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
        hasPhoto: widget.initialProfile?.hasPhoto ?? false,
        createdAt: widget.initialProfile?.createdAt ?? DateTime.now(),
      );
      await widget.onSave(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('network_save_error').replaceAll('{error}', '$e')),
          ),
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
    return Column(
      children: [
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
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
        ),
        // Step label
        Text(
          _stepLabel(_step),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF8B5CF6),
          ),
        ),
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
              _step5(theme),
            ],
          ),
        ),
        // Navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (widget.onCancel != null)
                TextButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: Text(_t('cancel')),
                ),
              if (_step > 0)
                TextButton.icon(
                  onPressed: _saving ? null : _prev,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(_t('network_back')),
                )
              else
                const Spacer(),
              const Spacer(),
              if (_step < _totalSteps - 1)
                FilledButton.icon(
                  onPressed: _saving ? null : _next,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'next_btn_wizard',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _saving
                        ? _t('network_copy_save')
                        : widget.initialProfile != null
                        ? _t('save')
                        : _t('network_copy_create_profile'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _stepLabel(int step) => _t('network_copy_step_${step + 1}');

  // ─── SCHRITT 1: Grundinfos ─────────────────────────────────────────────────
  Widget _step1(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _inputField(
            _nameCtrl,
            _t('network_copy_name_hint'),
            _t('network_copy_name_example'),
            Icons.person_rounded,
          ),
          const SizedBox(height: 14),
          LocationPickerWidget(
            initialLocation: _pickedLocation,
            hint: _t('network_copy_location_hint'),
            onLocationPicked: (loc) => setState(() {
              _pickedLocation = loc;
              _districtCtrl.text = loc.displayName;
            }),
          ),
          if (_pickedLocation == null && _districtCtrl.text.isNotEmpty)
            Text(_districtCtrl.text),
          const SizedBox(height: 20),
          _sectionTitle(theme, '\u{1F46A} ${_t('network_copy_family_form')}'),
          const SizedBox(height: 8),
          Text(
            _t('network_wizard_choose'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...MatchOptions.familyForms.map(
                (f) => ChoiceChip(
                  label: Text(
                    networkWizardOptionLabel(
                      languageService.currentLanguage,
                      'family',
                      f,
                      MatchOptions.familyFormLabels[f] ?? f,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _familyForm == f,
                  onSelected: (_) => setState(() => _familyForm = f),
                  avatar: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              ActionChip(
                label: Text(
                  '\u{2795} ${_t('network_copy_custom')}',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => setState(() => _familyForm = 'custom'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
              ),
            ],
          ),
          if (_familyForm == 'custom') ...[
            const SizedBox(height: 10),
            _inputField(
              _familyFormCustomCtrl,
              _t('network_copy_custom_family'),
              _t('network_copy_custom_example'),
              Icons.edit_rounded,
            ),
          ],
        ],
      ),
    );
  }

  // ─── SCHRITT 2: Kinder ─────────────────────────────────────────────────────
  Widget _step2(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            _t('network_wizard_for_whom'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ..._children.asMap().entries.map(
            (entry) => _childCard(theme, entry.key, entry.value),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _children.add(_ChildData())),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'add_child_btn',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _childCard(ThemeData theme, int index, _ChildData child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '\u{1F476} ${_t('network_child_number').replaceAll('{number}', '${index + 1}')}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_children.length > 1)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => setState(() {
                    _children[index].dispose();
                    _children.removeAt(index);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: child.nameCtrl,
            decoration: InputDecoration(
              labelText: _t('network_child_name_local'),
              hintText: _t('network_child_example'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          // Alter Slider
          Row(
            children: [
              Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'age_label',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: child.ageMonths.toDouble(),
                  min: 0,
                  max: child.maxAgeMonths.toDouble(),
                  divisions: child.maxAgeMonths,
                  label: _ageLabel(child.ageMonths),
                  onChanged: (v) => setState(() => child.ageMonths = v.round()),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ageLabel(child.ageMonths),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Geschlecht
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'gender_optional',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [null, ...MatchOptions.genderLabels.keys]
                .map(
                  (g) => ChoiceChip(
                    label: Text(
                      g == null
                          ? _t('network_copy_no_gender')
                          : networkWizardOptionLabel(
                              languageService.currentLanguage,
                              'gender',
                              g,
                              g,
                            ),
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: child.gender == g,
                    onSelected: (_) => setState(() => child.gender = g),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          // Interessen
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'interests_label',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...MatchOptions.childInterests.map(
                (i) => FilterChip(
                  label: Text(
                    networkWizardOptionLabel(
                      languageService.currentLanguage,
                      'child',
                      i,
                      MatchOptions.childInterestLabels[i] ?? i,
                    ),
                    style: const TextStyle(fontSize: 10),
                  ),
                  selected: child.interests.contains(i),
                  onSelected: (s) => setState(
                    () =>
                        s ? child.interests.add(i) : child.interests.remove(i),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ActionChip(
                label: Text(
                  '\u{2795} ${_t('network_custom_add')}',
                  style: const TextStyle(fontSize: 10),
                ),
                onPressed: () => _showCustomInput(
                  child.interestsCustomCtrl,
                  _t('network_child_custom_hint'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (child.interestsCustomCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '\u{2728} ${child.interestsCustomCtrl.text}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _ageLabel(int months) {
    if (months < 12) {
      return _t('network_age_months').replaceAll('{months}', '$months');
    }
    final y = months ~/ 12;
    final m = months % 12;
    return m == 0
        ? _t('network_age_years').replaceAll('{years}', '$y')
        : _t(
            'network_age_mixed',
          ).replaceAll('{years}', '$y').replaceAll('{months}', '$m');
  }

  // ─── SCHRITT 3: Werte & Erziehungsstil ─────────────────────────────────────
  Widget _step3(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Text('\u{1F49A}', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t('network_copy_values_tip'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '\u{2728} ${_t('network_values_heading')}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...MatchOptions.valueOptions.map(
                (v) => FilterChip(
                  label: Text(
                    networkWizardOptionLabel(
                      languageService.currentLanguage,
                      'values',
                      v,
                      MatchOptions.valueLabels[v] ?? v,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _values.contains(v),
                  onSelected: (s) =>
                      setState(() => s ? _values.add(v) : _values.remove(v)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  selectedColor: v == 'gfk'
                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                      : null,
                  checkmarkColor: v == 'gfk' ? const Color(0xFF16A34A) : null,
                ),
              ),
              ActionChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'custom_value',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _showCustomInput(
                  _valuesCustomCtrl,
                  _t('network_values_custom_hint'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ],
          ),
          if (_valuesCustomCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '\u{2728} ${_valuesCustomCtrl.text}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SCHRITT 4: Aktivitaeten + Verfügbarkeit ──────────────────────────────
  Widget _step4(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F3AF} ${_t('network_looking_heading')}'),
          const SizedBox(height: 6),
          Text(
            _t('network_wizard_activities'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...MatchOptions.lookingForOptions.map(
                (l) => FilterChip(
                  label: Text(
                    networkWizardOptionLabel(
                      languageService.currentLanguage,
                      'looking',
                      l,
                      MatchOptions.lookingForLabels[l] ?? l,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _lookingFor.contains(l),
                  onSelected: (s) => setState(
                    () => s ? _lookingFor.add(l) : _lookingFor.remove(l),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              ActionChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'custom_idea',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _showCustomInput(
                  _lookingForCustomCtrl,
                  _t('network_looking_custom_hint'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ],
          ),
          if (_lookingForCustomCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '\u{2728} ${_lookingForCustomCtrl.text}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 22),
          _sectionTitle(
            theme,
            '\u{1F4C5} ${_t('network_availability_heading')}',
          ),
          const SizedBox(height: 10),
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'days_label',
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MatchOptions.dayOptions
                .map(
                  (d) => FilterChip(
                    label: Text(
                      networkWizardOptionLabel(
                        languageService.currentLanguage,
                        'days',
                        d,
                        MatchOptions.dayLabels[d] ?? d,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _availDays.contains(d),
                    onSelected: (s) => setState(
                      () => s ? _availDays.add(d) : _availDays.remove(d),
                    ),
                    shape: const CircleBorder(),
                    showCheckmark: false,
                    padding: const EdgeInsets.all(4),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'times_label',
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...MatchOptions.timeOptions.map(
                (t) => FilterChip(
                  label: Text(
                    networkWizardOptionLabel(
                      languageService.currentLanguage,
                      'times',
                      t,
                      MatchOptions.timeLabels[t] ?? t,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _availTimes.contains(t),
                  onSelected: (s) => setState(
                    () => s ? _availTimes.add(t) : _availTimes.remove(t),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              ActionChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'other_time',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _showCustomInput(
                  _availCustomCtrl,
                  _t('network_availability_hint'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ],
          ),
          if (_availCustomCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '\u{2728} ${_availCustomCtrl.text}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SCHRITT 5: Sprachen + Bio + Besonderheiten ────────────────────────────
  Widget _step5(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F30D} ${_t('network_languages_heading')}'),
          const SizedBox(height: 6),
          Text(
            _t('network_wizard_languages'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MatchOptions.languageLabels.entries
                .map(
                  (e) => FilterChip(
                    label: Text(
                      networkWizardOptionLabel(
                        languageService.currentLanguage,
                        'language',
                        e.key,
                        e.value,
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _langs.contains(e.key),
                    onSelected: (s) => setState(
                      () => s ? _langs.add(e.key) : _langs.remove(e.key),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    avatar: e.key == 'ku'
                        ? const AlaRenginFlag(width: 20, height: 14)
                        : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F4AC} ${_t('network_copy_bio_title')}'),
          const SizedBox(height: 6),
          TextField(
            controller: _bioCtrl,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _t('network_copy_bio_hint'),
              hintStyle: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.outline,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F49C} ${_t('network_specials_heading')}'),
          const SizedBox(height: 6),
          Text(
            _t('network_specials_local'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...MatchOptions.specialOptions.map(
                (s) => FilterChip(
                  label: Text(
                    networkWizardOptionLabel(
                      languageService.currentLanguage,
                      'specials',
                      s,
                      MatchOptions.specialLabels[s] ?? s,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _specials.contains(s),
                  onSelected: (sel) => setState(
                    () => sel ? _specials.add(s) : _specials.remove(s),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              ActionChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'custom_entry',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _showCustomInput(
                  _specialsCustomCtrl,
                  _t('network_specials_hint'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ],
          ),
          if (_specialsCustomCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '\u{2728} ${_specialsCustomCtrl.text}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Hilfsmethoden ─────────────────────────────────────────────────────────
  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
      ),
    );
  }

  void _showCustomInput(TextEditingController ctrl, String hint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
                    child: Text(_t('done')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Kind-Daten Helfer ───────────────────────────────────────────────────────
class _ChildData {
  final nameCtrl = TextEditingController();
  final interestsCustomCtrl = TextEditingController();
  late int _ageMonths;
  final int maxAgeMonths;
  DateTime? birthDate;
  String? gender;
  final Set<String> interests = {};

  _ChildData({ChildEntry? initial})
    : maxAgeMonths = (initial?.ageMonths ?? 36).clamp(216, 240) {
    _ageMonths = initial?.ageMonths ?? 36;
    birthDate = initial?.birthDate;
    nameCtrl.text = initial?.name ?? '';
    interestsCustomCtrl.text = initial?.interestsCustom ?? '';
    gender = initial?.gender;
    interests.addAll(initial?.interests ?? []);
  }

  int get ageMonths => _ageMonths;
  set ageMonths(int value) {
    _ageMonths = value;
    birthDate = null;
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: _t('network_district_label'),
            hintText: _t('network_district_hint'),
            prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {
                        _suggestions = [];
                        _showSuggestions = false;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.5,
              ),
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
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 44,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
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
                    child: const Icon(
                      Icons.place_rounded,
                      size: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  title: Text(
                    s.shortLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: s.postcode.isNotEmpty
                      ? Text(
                          s.postcode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        )
                      : null,
                  onTap: () {
                    widget.controller.text = s.shortLabel;
                    widget.controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: s.shortLabel.length),
                    );
                    setState(() => _showSuggestions = false);
                    widget.onSelected(s);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
