import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PedagogicalCategory {
  gfk,
  inclusion,
  parentLeadership,
  milestones,
}

class WeeklyImpulse {
  final String id;
  final String title;
  final String contentBody;
  final String practicalTip;
  final String? audioScript;
  final PedagogicalCategory category;
  final DateTime publishDate;
  final String? heroHeadline;
  final String? heroDescription;
  final List<WeeklyImpulseCompanion> companionImpulses;
  final WeeklyImpulseDiscussionPrompt? discussionPrompt;
  final List<WeeklyImpulseCommunityPost> communityPosts;

  WeeklyImpulse({
    required this.id,
    required this.title,
    required this.contentBody,
    required this.practicalTip,
    this.audioScript,
    required this.category,
    required this.publishDate,
    this.heroHeadline,
    this.heroDescription,
    this.companionImpulses = const <WeeklyImpulseCompanion>[],
    this.discussionPrompt,
    this.communityPosts = const <WeeklyImpulseCommunityPost>[],
  });

  factory WeeklyImpulse.fromJson(Map json) {
    final rawCompanions = json['companion_impulses'] as List<dynamic>?;
    final rawCommunityPosts = json['community_posts'] as List<dynamic>?;

    return WeeklyImpulse(
      id: json['id'] as String,
      title: json['title'] as String,
      contentBody: json['content_body'] as String,
      practicalTip: json['practical_tip'] as String,
      audioScript: json['audio_script'] as String?,
      category: PedagogicalCategory.values.firstWhere(
        (entry) => entry.toString().split('.').last == json['category'],
        orElse: () => PedagogicalCategory.milestones,
      ),
      publishDate: DateTime.parse(json['publish_date'] as String),
      heroHeadline: json['hero_headline'] as String?,
      heroDescription: json['hero_description'] as String?,
      companionImpulses: rawCompanions == null
          ? const <WeeklyImpulseCompanion>[]
          : rawCompanions
              .whereType<Map<String, dynamic>>()
              .map(WeeklyImpulseCompanion.fromJson)
              .toList(),
      discussionPrompt: json['discussion_prompt'] is Map<String, dynamic>
          ? WeeklyImpulseDiscussionPrompt.fromJson(
              json['discussion_prompt'] as Map<String, dynamic>,
            )
          : null,
      communityPosts: rawCommunityPosts == null
          ? const <WeeklyImpulseCommunityPost>[]
          : rawCommunityPosts
              .whereType<Map<String, dynamic>>()
              .map(WeeklyImpulseCommunityPost.fromJson)
              .toList(),
    );
  }
}

class WeeklyImpulseCompanion {
  final String id;
  final String title;
  final String summary;
  final String durationLabel;
  final String formatLabel;

  const WeeklyImpulseCompanion({
    required this.id,
    required this.title,
    required this.summary,
    required this.durationLabel,
    required this.formatLabel,
  });

  factory WeeklyImpulseCompanion.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseCompanion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      durationLabel: json['duration_label'] as String? ?? '',
      formatLabel: json['format_label'] as String? ?? '',
    );
  }
}

class WeeklyImpulseDiscussionPrompt {
  final String id;
  final String title;
  final String body;

  const WeeklyImpulseDiscussionPrompt({
    required this.id,
    required this.title,
    required this.body,
  });

  factory WeeklyImpulseDiscussionPrompt.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseDiscussionPrompt(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class WeeklyImpulseCommunityPost {
  final String id;
  final String authorName;
  final String role;
  final bool verifiedExpert;
  final String verificationLabel;
  final String title;
  final String body;
  final int seedLikeCount;
  final List<String> seedComments;
  final bool viewerHasLiked;

  const WeeklyImpulseCommunityPost({
    required this.id,
    required this.authorName,
    required this.role,
    required this.verifiedExpert,
    required this.verificationLabel,
    required this.title,
    required this.body,
    required this.seedLikeCount,
    required this.seedComments,
    this.viewerHasLiked = false,
  });

  factory WeeklyImpulseCommunityPost.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseCommunityPost(
      id: json['id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      verifiedExpert: json['verified_expert'] as bool? ?? false,
      verificationLabel: json['verification_label'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      seedLikeCount: json['seed_like_count'] as int? ?? 0,
      seedComments:
          (json['seed_comments'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      viewerHasLiked: json['viewer_has_liked'] as bool? ?? false,
    );
  }
}

class WeeklyImpulseCard extends StatefulWidget {
  final WeeklyImpulse impulse;
  final VoidCallback? onAudioPressed;
  final Future<void> Function(String title, String body, String role)?
      onCreateCommunityPost;
  final Future<void> Function(String postId, bool currentlyLiked)?
      onToggleLikePost;
  final Future<void> Function(String postId, String comment)? onAddComment;
  final Future<void> Function(String postId, String reason)? onReportPost;

  const WeeklyImpulseCard({
    super.key,
    required this.impulse,
    this.onAudioPressed,
    this.onCreateCommunityPost,
    this.onToggleLikePost,
    this.onAddComment,
    this.onReportPost,
  });

  @override
  State<WeeklyImpulseCard> createState() => _WeeklyImpulseCardState();
}

class _WeeklyImpulseCardState extends State<WeeklyImpulseCard> {
  static const String _roleParent = 'Elternteil';
  static const String _roleEducator = 'Paedagog:in';

  Set<String> _likedPostIds = <String>{};
  Set<String> _savedCompanionIds = <String>{};
  Set<String> _hiddenPostIds = <String>{};
  Set<String> _reportedPostIds = <String>{};
  Map<String, String> _reportReasonByPostId = <String, String>{};
  Map<String, List<String>> _extraCommentsByPostId = <String, List<String>>{};
  String? _selectedResonance;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _restoreLocalState();
  }

  Color _getCategoryColor(PedagogicalCategory category) {
    switch (category) {
      case PedagogicalCategory.gfk:
        return const Color(0xFF1F9D55);
      case PedagogicalCategory.inclusion:
        return const Color(0xFF3157D5);
      case PedagogicalCategory.parentLeadership:
        return const Color(0xFFF08C24);
      case PedagogicalCategory.milestones:
        return const Color(0xFF0F766E);
    }
  }

  String _getCategoryName(PedagogicalCategory category) {
    switch (category) {
      case PedagogicalCategory.gfk:
        return 'Gewaltfreie Kommunikation';
      case PedagogicalCategory.inclusion:
        return 'Inklusion & Vielfalt';
      case PedagogicalCategory.parentLeadership:
        return 'Elterliche Fuehrung';
      case PedagogicalCategory.milestones:
        return 'Entwicklungsschritt';
    }
  }

  String get _prefsPrefix => 'weekly_impulse_hub.${widget.impulse.id}';

  Future<void> _restoreLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final liked =
          prefs.getStringList('$_prefsPrefix.liked') ?? const <String>[];
      final saved =
          prefs.getStringList('$_prefsPrefix.saved') ?? const <String>[];
      final hidden =
          prefs.getStringList('$_prefsPrefix.hidden') ?? const <String>[];
      final reported =
          prefs.getStringList('$_prefsPrefix.reported') ?? const <String>[];
      final rawReportReasons = prefs.getString('$_prefsPrefix.reportReasons');
      final resonance = prefs.getString('$_prefsPrefix.resonance');
      final rawComments = prefs.getString('$_prefsPrefix.comments');

      if (!mounted) {
        return;
      }

      setState(() {
        _likedPostIds = liked.toSet();
        _savedCompanionIds = saved.toSet();
        _hiddenPostIds = hidden.toSet();
        _reportedPostIds = reported.toSet();
        _reportReasonByPostId = _decodeReportReasons(rawReportReasons);
        _selectedResonance = resonance;
        _extraCommentsByPostId = _decodeComments(rawComments);
        _isLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoaded = true);
    }
  }

  Map<String, List<String>> _decodeComments(String? rawComments) {
    if (rawComments == null || rawComments.isEmpty) {
      return <String, List<String>>{};
    }

    final decoded = jsonDecode(rawComments);
    if (decoded is! Map<String, dynamic>) {
      return <String, List<String>>{};
    }

    return decoded.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).map((item) => item.toString()).toList(),
      ),
    );
  }

  Map<String, String> _decodeReportReasons(String? rawReasons) {
    if (rawReasons == null || rawReasons.isEmpty) {
      return <String, String>{};
    }

    final decoded = jsonDecode(rawReasons);
    if (decoded is! Map<String, dynamic>) {
      return <String, String>{};
    }

    return decoded.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_prefsPrefix.liked', _likedPostIds.toList());
    await prefs.setStringList(
        '$_prefsPrefix.saved', _savedCompanionIds.toList());
    await prefs.setStringList('$_prefsPrefix.hidden', _hiddenPostIds.toList());
    await prefs.setStringList(
        '$_prefsPrefix.reported', _reportedPostIds.toList());
    await prefs.setString(
      '$_prefsPrefix.reportReasons',
      jsonEncode(_reportReasonByPostId),
    );

    if (_selectedResonance == null) {
      await prefs.remove('$_prefsPrefix.resonance');
    } else {
      await prefs.setString('$_prefsPrefix.resonance', _selectedResonance!);
    }

    await prefs.setString(
      '$_prefsPrefix.comments',
      jsonEncode(_extraCommentsByPostId),
    );
  }

  void _showActionError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _extractSentences(String text) {
    return text
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.length > 24)
        .toList();
  }

  List<_CompanionImpulse> _buildCompanionImpulses(Color accentColor) {
    if (widget.impulse.companionImpulses.isNotEmpty) {
      return widget.impulse.companionImpulses.asMap().entries.map((entry) {
        final companion = entry.value;
        return _CompanionImpulse(
          id: companion.id,
          title: companion.title,
          summary: companion.summary,
          durationLabel: companion.durationLabel,
          formatLabel: companion.formatLabel,
          icon: _iconForCompanion(companion.formatLabel, entry.key),
          accentColor:
              _colorForCompanion(companion.formatLabel, accentColor, entry.key),
        );
      }).toList();
    }

    final sentences = _extractSentences(widget.impulse.contentBody);
    final firstSentence = sentences.isNotEmpty
        ? sentences.first
        : widget.impulse.contentBody.trim();
    final secondSentence = sentences.length > 1
        ? sentences[1]
        : widget.impulse.practicalTip.trim();

    return <_CompanionImpulse>[
      _CompanionImpulse(
        id: '${widget.impulse.id}.quick',
        title: 'Heute in 2 Minuten',
        summary: widget.impulse.practicalTip,
        durationLabel: '2 Min',
        formatLabel: 'Sofort-Impuls',
        icon: Icons.flash_on_rounded,
        accentColor: accentColor,
      ),
      _CompanionImpulse(
        id: '${widget.impulse.id}.understand',
        title: 'Kurz verstanden',
        summary: firstSentence,
        durationLabel: '3 Min',
        formatLabel: 'Verstehen',
        icon: Icons.menu_book_rounded,
        accentColor: const Color(0xFF2563EB),
      ),
      _CompanionImpulse(
        id: '${widget.impulse.id}.practice',
        title: 'Für Alltag und Kita',
        summary:
            'Formuliere kurz, ruhig und klar. Ein Satz zum Gefühl, ein Satz zur Grenze, dann Präsenz statt Diskussion.',
        durationLabel: '4 Min',
        formatLabel: 'Praxis',
        icon: Icons.groups_rounded,
        accentColor: const Color(0xFF7C3AED),
      ),
      _CompanionImpulse(
        id: '${widget.impulse.id}.reflect',
        title: 'Abend-Reflexion',
        summary:
            'Wann war dein Kind heute besonders suchend oder angespannt? Was hat geholfen: erklären, spiegeln oder eine klare Grenze?',
        durationLabel: '2 Min',
        formatLabel: 'Reflexion',
        icon: Icons.self_improvement_rounded,
        accentColor: const Color(0xFFDB2777),
      ),
      _CompanionImpulse(
        id: '${widget.impulse.id}.deepdive',
        title: 'Tieferer Blick',
        summary: secondSentence,
        durationLabel: '5 Min',
        formatLabel: 'Artikel',
        icon: Icons.auto_stories_rounded,
        accentColor: const Color(0xFF0F766E),
      ),
    ];
  }

  List<_CommunityPost> _buildCommunityPosts() {
    if (widget.impulse.communityPosts.isNotEmpty) {
      return <_CommunityPost>[
        ...widget.impulse.communityPosts.map(
          (post) => _CommunityPost(
            id: post.id,
            authorName: post.authorName,
            role: post.role,
            verifiedExpert: post.verifiedExpert,
            verificationLabel: post.verificationLabel,
            title: post.title,
            body: post.body,
            seedLikeCount: post.seedLikeCount,
            seedComments: post.seedComments,
            viewerHasLiked: post.viewerHasLiked,
            isRemote: true,
          ),
        ),
      ];
    }

    return <_CommunityPost>[];
  }

  IconData _iconForCompanion(String formatLabel, int index) {
    final format = formatLabel.toLowerCase();
    if (format.contains('sofort')) return Icons.flash_on_rounded;
    if (format.contains('verstehen')) return Icons.menu_book_rounded;
    if (format.contains('praxis')) return Icons.groups_rounded;
    if (format.contains('reflex')) return Icons.self_improvement_rounded;
    if (format.contains('artikel')) return Icons.auto_stories_rounded;

    const fallbackIcons = <IconData>[
      Icons.flash_on_rounded,
      Icons.menu_book_rounded,
      Icons.groups_rounded,
      Icons.self_improvement_rounded,
      Icons.auto_stories_rounded,
    ];
    return fallbackIcons[index % fallbackIcons.length];
  }

  Color _colorForCompanion(
    String formatLabel,
    Color accentColor,
    int index,
  ) {
    final format = formatLabel.toLowerCase();
    if (format.contains('sofort')) return accentColor;
    if (format.contains('verstehen')) return const Color(0xFF2563EB);
    if (format.contains('praxis')) return const Color(0xFF7C3AED);
    if (format.contains('reflex')) return const Color(0xFFDB2777);
    if (format.contains('artikel')) return const Color(0xFF0F766E);

    const fallbackColors = <Color>[
      Color(0xFF1F9D55),
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF0F766E),
    ];
    return fallbackColors[index % fallbackColors.length];
  }

  Future<void> _toggleSaveCompanion(String companionId) async {
    setState(() {
      if (_savedCompanionIds.contains(companionId)) {
        _savedCompanionIds.remove(companionId);
      } else {
        _savedCompanionIds.add(companionId);
      }
    });
    await _persistState();
  }

  Future<void> _toggleLikePost(String postId) async {
    final currentlyLiked = _likedPostIds.contains(postId);
    if (widget.onToggleLikePost == null) {
      _showActionError('Like ist aktuell nicht verfügbar.');
      return;
    }

    try {
      await widget.onToggleLikePost!(postId, currentlyLiked);
    } catch (_) {
      _showActionError('Like konnte nicht gespeichert werden.');
    }
  }

  Future<void> _selectResonance(String label) async {
    setState(() {
      _selectedResonance = _selectedResonance == label ? null : label;
    });
    await _persistState();
  }

  Future<bool> _addComment(String postId, String comment) async {
    final trimmed = comment.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (widget.onAddComment == null) {
      _showActionError('Kommentare sind aktuell nicht verfügbar.');
      return false;
    }

    try {
      await widget.onAddComment!(postId, trimmed);
      return true;
    } catch (_) {
      _showActionError('Kommentar konnte nicht gesendet werden.');
      return false;
    }
  }

  Future<bool> _createCommunityPost({
    required String title,
    required String body,
    required String role,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      return false;
    }

    if (widget.onCreateCommunityPost == null) {
      _showActionError('Community-Posting ist aktuell nicht verfügbar.');
      return false;
    }

    try {
      await widget.onCreateCommunityPost!(trimmedTitle, trimmedBody, role);
      return true;
    } catch (_) {
      _showActionError('Beitrag konnte nicht veröffentlicht werden.');
      return false;
    }
  }

  Future<void> _hidePost(String postId) async {
    setState(() {
      _hiddenPostIds.add(postId);
    });
    await _persistState();
  }

  Future<void> _restorePost(String postId) async {
    setState(() {
      _hiddenPostIds.remove(postId);
      _reportedPostIds.remove(postId);
      _reportReasonByPostId.remove(postId);
    });
    await _persistState();
  }

  Future<bool> _reportPost(String postId, String reason) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      return false;
    }

    if (widget.onReportPost == null) {
      _showActionError('Melden ist aktuell nicht verfügbar.');
      return false;
    }

    try {
      await widget.onReportPost!(postId, trimmedReason);
      setState(() {
        _reportedPostIds.add(postId);
        _hiddenPostIds.add(postId);
        _reportReasonByPostId[postId] = trimmedReason;
      });
      await _persistState();
      return true;
    } catch (_) {
      _showActionError('Beitrag konnte nicht gemeldet werden.');
      return false;
    }
  }

  Future<void> _showComposeSheet() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var selectedRole = _roleParent;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Praxisimpuls teilen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Teile eine ruhige, konkrete Idee aus deinem Familien- oder Berufsalltag.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Ich teile als Elternteil'),
                        selected: selectedRole == _roleParent,
                        onSelected: (_) {
                          setModalState(() => selectedRole = _roleParent);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Ich teile als Paedagog:in'),
                        selected: selectedRole == _roleEducator,
                        onSelected: (_) {
                          setModalState(() => selectedRole = _roleEducator);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectedRole == _roleEducator)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Fachbeiträge sind möglich. Ein verifiziertes Fach-Badge wird jedoch nur für geprüfte Profile vergeben.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (selectedRole == _roleEducator) const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Ueberschrift',
                      hintText: 'Zum Beispiel: Was uns in Wutmomenten hilft',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Dein Impuls',
                      hintText:
                          'Beschreibe kurz, was du ausprobiert hast und warum es hilfreich war.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final created = await _createCommunityPost(
                          title: titleController.text,
                          body: bodyController.text,
                          role: selectedRole,
                        );
                        if (!created || !mounted) {
                          return;
                        }
                        Navigator.of(this.context).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Dein Impuls wurde hinzugefuegt.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Impuls teilen'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
  }

  Future<void> _showCommentsSheet(_CommunityPost post) async {
    final commentController = TextEditingController();
    final allComments = <String>[
      ...post.seedComments,
      ...(_extraCommentsByPostId[post.id] ?? const <String>[]),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Kommentare und Rückmeldungen',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (allComments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Noch keine Kommentare. Du kannst die erste hilfreiche Rückmeldung hinterlassen.',
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allComments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(allComments[index]),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Dein Kommentar',
                  hintText: 'Teile kurz, was bei euch geholfen hat.',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final sent =
                        await _addComment(post.id, commentController.text);
                    if (!sent || !context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: const Text('Kommentar senden'),
                ),
              ),
            ],
          ),
        );
      },
    );

    commentController.dispose();
  }

  Future<void> _showPostDetailSheet(_CommunityPost post) async {
    final theme = Theme.of(context);
    final likeCount = post.isRemote
        ? post.seedLikeCount
        : post.seedLikeCount + (_likedPostIds.contains(post.id) ? 1 : 0);
    final commentCount = post.isRemote
        ? post.seedComments.length
        : post.seedComments.length +
            (_extraCommentsByPostId[post.id]?.length ?? 0);
    final isLiked =
        post.isRemote ? post.viewerHasLiked : _likedPostIds.contains(post.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.94,
          minChildSize: 0.55,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Beitragsdetails',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: post.role == _roleEducator
                                  ? const Color(0xFFE0E7FF)
                                  : const Color(0xFFDCFCE7),
                              child: Icon(
                                post.role == _roleEducator
                                    ? Icons.school_rounded
                                    : Icons.favorite_outline_rounded,
                                color: post.role == _roleEducator
                                    ? const Color(0xFF4338CA)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    post.role,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _RoleBadge(
                              label: _roleBadgeLabel(post),
                              color: _roleBadgeColor(post),
                              icon: _roleBadgeIcon(post),
                            ),
                            if (post.verifiedExpert)
                              _RoleBadge(
                                label: post.verificationLabel.isEmpty
                                    ? 'Verifiziert'
                                    : post.verificationLabel,
                                color: const Color(0xFF0F766E),
                                icon: Icons.verified_rounded,
                              ),
                            if (!post.verifiedExpert &&
                                post.role == _roleEducator)
                              const _RoleBadge(
                                label: 'Fachbeitrag ohne Badge',
                                color: Color(0xFFB45309),
                                icon: Icons.pending_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    post.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: 18),
                  _buildDetailInfoCard(
                    theme,
                    title: 'Kontext',
                    lines: [
                      post.verifiedExpert
                          ? 'Dieser Beitrag stammt aus einer verifizierten Fachstimme.'
                          : post.role == _roleEducator
                              ? 'Dieser Beitrag ist als Fachbeitrag markiert, aber aktuell nicht verifiziert.'
                              : 'Dieser Beitrag teilt eine Erfahrung aus dem Familienalltag.',
                      'Reaktionen: $likeCount Likes  •  $commentCount Kommentare',
                    ],
                    accentColor: post.verifiedExpert
                        ? const Color(0xFF0F766E)
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailInfoCard(
                    theme,
                    title: 'Sicher und hilfreich nutzen',
                    lines: [
                      'Nimm Impulse als Orientierung, nicht als starre Vorschrift.',
                      'Wenn dir Ton oder Inhalt nicht passend erscheinen, kannst du den Beitrag melden oder ausblenden.',
                    ],
                    accentColor: const Color(0xFF475569),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: compact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 16) / 3,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await _toggleLikePost(post.id);
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(context).pop();
                              },
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: compact ? 17 : 18,
                              ),
                              label: Text(
                                isLiked ? 'Like rm.' : 'Like',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 16) / 3,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _showCommentsSheet(post);
                              },
                              icon: const Icon(Icons.mode_comment_outlined,
                                  size: 17),
                              label: Text(
                                compact
                                    ? 'Komm. ($commentCount)'
                                    : 'Kommentare ($commentCount)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 16) / 3,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _showReportSheet(post);
                              },
                              icon: const Icon(Icons.flag_outlined, size: 17),
                              label: const Text(
                                'Melden',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReportSheet(_CommunityPost post) async {
    final noteController = TextEditingController();
    String selectedReason = 'Unpassender Ton';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beitrag melden',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wir blenden den Beitrag für dich aus und markieren ihn für eine spätere Pruefung.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      'Unpassender Ton',
                      'Nicht hilfreich',
                      'Nicht elternfreundlich',
                      'Fachlich fragwuerdig',
                    ].map((reason) {
                      return ChoiceChip(
                        label: Text(reason),
                        selected: selectedReason == reason,
                        onSelected: (_) {
                          setModalState(() => selectedReason = reason);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Optionaler Hinweis',
                      hintText:
                          'Kurz erklären, was für dich problematisch war.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final note = noteController.text.trim();
                        final reason = note.isEmpty
                            ? selectedReason
                            : '$selectedReason: $note';
                        final reported = await _reportPost(post.id, reason);
                        if (!reported || !context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Beitrag gemeldet und ausgeblendet.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Melden und ausblenden'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Future<void> _showModerationSheet(List<_CommunityPost> posts) async {
    final moderatedPosts = posts
        .where(
          (post) =>
              _hiddenPostIds.contains(post.id) ||
              _reportedPostIds.contains(post.id),
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moderationsüberblick',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Hier siehst du Beitraege, die du ausgeblendet oder gemeldet hast. Du kannst sie bei Bedarf wieder einblenden.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (moderatedPosts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Im Moment hast du keine Beitraege ausgeblendet oder gemeldet.',
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: moderatedPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = moderatedPosts[index];
                      final reportReason = _reportReasonByPostId[post.id];
                      final isReported = _reportedPostIds.contains(post.id);
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    post.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _RoleBadge(
                                  label:
                                      isReported ? 'Gemeldet' : 'Ausgeblendet',
                                  color: isReported
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF64748B),
                                  icon: isReported
                                      ? Icons.flag_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${post.authorName}  •  ${post.role}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (reportReason != null &&
                                reportReason.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Grund: $reportReason',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _restorePost(post.id);
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('Wieder einblenden'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailInfoCard(
    ThemeData theme, {
    required String title,
    required List<String> lines,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getCategoryColor(widget.impulse.category);
    final theme = Theme.of(context);
    final companionImpulses = _buildCompanionImpulses(accentColor);
    final communityPosts = _buildCommunityPosts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(theme, accentColor),
        const SizedBox(height: 18),
        _buildFeaturedCard(theme, accentColor),
        const SizedBox(height: 18),
        _buildCompanionSection(theme, companionImpulses),
        const SizedBox(height: 18),
        _buildDiscussionPrompt(theme),
        const SizedBox(height: 18),
        _buildCommunitySection(theme, communityPosts),
        if (!_isLoaded) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
      ],
    );
  }

  Widget _buildHero(ThemeData theme, Color accentColor) {
    final weekLabel =
        'Woche vom ${widget.impulse.publishDate.day.toString().padLeft(2, '0')}.${widget.impulse.publishDate.month.toString().padLeft(2, '0')}';
    final companionCount = _buildCompanionImpulses(accentColor).length;
    final communityCount = _buildCommunityPosts().length;
    final heroHeadline =
        widget.impulse.heroHeadline ?? 'Dein Themenraum für diese Woche';
    final heroDescription = widget.impulse.heroDescription ??
        'Nicht nur ein einzelner Impuls: Du bekommst einen klaren Wochenfokus, kurze Praxisformate und Raum für hilfreiche Erfahrungen aus der Community.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withValues(alpha: 0.72),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$weekLabel  •  ${_getCategoryName(widget.impulse.category)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            heroHeadline,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            heroDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _HeroStat(label: '1 Fokus', value: 'Klar'),
              _HeroStat(label: 'Formate', value: '$companionCount'),
              _HeroStat(label: 'Community', value: '$communityCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(ThemeData theme, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Leitimpuls',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.impulse.audioScript != null)
                IconButton.filledTonal(
                  onPressed: widget.onAudioPressed,
                  icon: const Icon(Icons.volume_up_rounded),
                  tooltip: 'Audio-Impuls anhoeren',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.impulse.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.impulse.contentBody,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border(
                left: BorderSide(color: accentColor, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Heute direkt ausprobieren',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.impulse.practicalTip,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildResonanceChip(
                theme,
                label: 'Hilft mir gerade',
                icon: Icons.favorite_rounded,
              ),
              _buildResonanceChip(
                theme,
                label: 'Will ich ausprobieren',
                icon: Icons.play_circle_fill_rounded,
              ),
              _buildResonanceChip(
                theme,
                label: 'Merke ich mir',
                icon: Icons.bookmark_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResonanceChip(
    ThemeData theme, {
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedResonance == label;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      onSelected: (_) => _selectResonance(label),
    );
  }

  Widget _buildCompanionSection(
    ThemeData theme,
    List<_CompanionImpulse> companions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mehrere Impulse auf einmal',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Eltern können je nach Energielevel lesen, merken oder später vertiefen.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        ...companions.map((companion) {
          final isSaved = _savedCompanionIds.contains(companion.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: companion.accentColor.withValues(alpha: 0.14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: companion.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          companion.icon,
                          color: companion.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companion.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${companion.formatLabel}  •  ${companion.durationLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _toggleSaveCompanion(companion.id),
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                        tooltip: isSaved ? 'Gemerkt' : 'Merken',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    companion.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDiscussionPrompt(ThemeData theme) {
    final prompt = widget.impulse.discussionPrompt;
    final discussionPost = _CommunityPost(
      id: prompt?.id.isNotEmpty == true
          ? prompt!.id
          : '${widget.impulse.id}.discussion',
      authorName: 'Parentpeak Runde',
      role: 'Wochenthema',
      verifiedExpert: false,
      verificationLabel: '',
      title:
          prompt?.title.isNotEmpty == true ? prompt!.title : 'Frage der Woche',
      body: prompt?.body.isNotEmpty == true
          ? prompt!.body
          : 'Welche ruhige Formulierung hat euch in einer angespannten Situation zuletzt geholfen?',
      seedLikeCount: 0,
      seedComments: const <String>[],
    );

    final count =
        (_extraCommentsByPostId[discussionPost.id] ?? const <String>[]).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            discussionPost.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            discussionPost.body,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2,
                    child: FilledButton.icon(
                      onPressed: () => _showCommentsSheet(discussionPost),
                      icon: const Icon(Icons.forum_rounded),
                      label: Text(
                        count == 0 ? 'Antworten' : '$count Antw.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2,
                    child: OutlinedButton.icon(
                      onPressed: _showComposeSheet,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text(
                        compact ? 'Teilen' : 'Praxisimpuls teilen',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitySection(
    ThemeData theme,
    List<_CommunityPost> posts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Praxis aus Elternhaus und Paedagogik',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Echte Community-Reaktionen aus dem Live-Backend.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_hiddenPostIds.isNotEmpty || _reportedPostIds.isNotEmpty)
              IconButton.filledTonal(
                onPressed: () => _showModerationSheet(posts),
                icon: const Icon(Icons.shield_outlined),
                tooltip: 'Moderationsüberblick',
              ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _showComposeSheet,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Neuen Impuls teilen',
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_hiddenPostIds.isNotEmpty || _reportedPostIds.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF475569)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_hiddenPostIds.length} Beitrag/Beitraege geschuetzt ausgeblendet. Du kannst sie im Moderationsüberblick verwalten.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (posts.where((post) => !_hiddenPostIds.contains(post.id)).isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Noch keine Community-Beitraege vorhanden. Teile den ersten Praxisimpuls.',
            ),
          ),
        ...posts.where((post) => !_hiddenPostIds.contains(post.id)).map((post) {
          final likeCount = post.isRemote
              ? post.seedLikeCount
              : post.seedLikeCount + (_likedPostIds.contains(post.id) ? 1 : 0);
          final commentCount = post.isRemote
              ? post.seedComments.length
              : post.seedComments.length +
                  (_extraCommentsByPostId[post.id]?.length ?? 0);
          final isLiked = post.isRemote
              ? post.viewerHasLiked
              : _likedPostIds.contains(post.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: post.role == _roleEducator
                            ? const Color(0xFFE0E7FF)
                            : const Color(0xFFDCFCE7),
                        child: Icon(
                          post.role == _roleEducator
                              ? Icons.school_rounded
                              : Icons.favorite_outline_rounded,
                          color: post.role == _roleEducator
                              ? const Color(0xFF4338CA)
                              : const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.role,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RoleBadge(
                                  label: _roleBadgeLabel(post),
                                  color: _roleBadgeColor(post),
                                  icon: _roleBadgeIcon(post),
                                ),
                                if (post.verifiedExpert)
                                  _RoleBadge(
                                    label: post.verificationLabel.isEmpty
                                        ? 'Verifiziert'
                                        : post.verificationLabel,
                                    color: const Color(0xFF0F766E),
                                    icon: Icons.verified_rounded,
                                  ),
                                if (_reportedPostIds.contains(post.id))
                                  const _RoleBadge(
                                    label: 'Ausgeblendet',
                                    color: Color(0xFF64748B),
                                    icon: Icons.visibility_off_rounded,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'hide') {
                            await _hidePost(post.id);
                          }
                          if (value == 'report') {
                            await _showReportSheet(post);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'hide',
                            child: Text('Für mich ausblenden'),
                          ),
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Text('Melden'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    post.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showPostDetailSheet(post),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Details'),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => _toggleLikePost(post.id),
                        icon: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked ? const Color(0xFFDB2777) : null,
                        ),
                        label: Text('$likeCount'),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => _showCommentsSheet(post),
                        icon: const Icon(Icons.mode_comment_outlined),
                        label: Text('$commentCount'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _roleBadgeLabel(_CommunityPost post) {
    if (post.role == _roleEducator) {
      return 'Fachpraxis';
    }
    if (post.role == _roleParent) {
      return 'Elternalltag';
    }
    return 'Community';
  }

  Color _roleBadgeColor(_CommunityPost post) {
    if (post.role == _roleEducator) {
      return const Color(0xFF4338CA);
    }
    if (post.role == _roleParent) {
      return const Color(0xFF15803D);
    }
    return const Color(0xFF0F766E);
  }

  IconData _roleBadgeIcon(_CommunityPost post) {
    if (post.role == _roleEducator) {
      return Icons.school_rounded;
    }
    if (post.role == _roleParent) {
      return Icons.favorite_outline_rounded;
    }
    return Icons.forum_rounded;
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _RoleBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompanionImpulse {
  final String id;
  final String title;
  final String summary;
  final String durationLabel;
  final String formatLabel;
  final IconData icon;
  final Color accentColor;

  const _CompanionImpulse({
    required this.id,
    required this.title,
    required this.summary,
    required this.durationLabel,
    required this.formatLabel,
    required this.icon,
    required this.accentColor,
  });
}

class _CommunityPost {
  final String id;
  final String authorName;
  final String role;
  final bool verifiedExpert;
  final String verificationLabel;
  final String title;
  final String body;
  final int seedLikeCount;
  final List<String> seedComments;
  final bool viewerHasLiked;
  final bool isRemote;

  const _CommunityPost({
    required this.id,
    required this.authorName,
    required this.role,
    required this.verifiedExpert,
    required this.verificationLabel,
    required this.title,
    required this.body,
    required this.seedLikeCount,
    required this.seedComments,
    this.viewerHasLiked = false,
    this.isRemote = false,
  });
}
