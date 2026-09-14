import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/family_recipe_share_service.dart';
import 'package:parentpeak/logic/fridge_recipe_service.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/ui/widgets/safe_image.dart';

/// Phase 3b: KI-Kühlschrank-Foto.
///
/// Ablauf: Foto machen/auswählen → Gemini erkennt Zutaten (editierbare Chips)
/// → kindgerechtes Rezept generieren → fehlende Zutaten mit einem Tap auf die
/// Einkaufsliste setzen.
class FridgeRecipeScreen extends StatefulWidget {
  const FridgeRecipeScreen({super.key});

  @override
  State<FridgeRecipeScreen> createState() => _FridgeRecipeScreenState();
}

enum _Phase { start, detecting, ingredients, generating, recipe }

class _FridgeRecipeScreenState extends State<FridgeRecipeScreen> {
  static const _accent = Color(0xFFE8543A);

  final _service = FridgeRecipeService.instance;
  final _shareService = FamilyRecipeShareService.instance;
  final _picker = ImagePicker();
  final _addCtrl = TextEditingController();

  _Phase _phase = _Phase.start;
  XFile? _photo;
  List<String> _ingredients = [];
  FamilyRecipe? _recipe;
  List<String> _missing = [];
  bool _sharing = false;
  bool _shared = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 80,
      );
      if (img == null || !mounted) return;
      setState(() {
        _photo = img;
        _phase = _Phase.detecting;
      });
      final bytes = await img.readAsBytes();
      final detected = await _service.detectIngredients(bytes);
      if (!mounted) return;
      setState(() {
        _ingredients = detected;
        _phase = _Phase.ingredients;
      });
      if (detected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('fridge_no_ingredients_detected')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on AiRateLimitException catch (e) {
      if (mounted) {
        setState(() => _phase = _Phase.start);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _Phase.start);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('fridge_photo_processing_failed')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _removeIngredient(String ing) {
    setState(() => _ingredients.remove(ing));
  }

  void _addIngredient() {
    final v = _addCtrl.text.trim();
    if (v.isEmpty) return;
    if (!_ingredients.any((e) => e.toLowerCase() == v.toLowerCase())) {
      setState(() => _ingredients.add(v));
    }
    _addCtrl.clear();
  }

  Future<void> _generate() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('fridge_ingredients_required')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _phase = _Phase.generating);
    FamilyRecipe? recipe;
    try {
      recipe = await _service.generateFromIngredients(_ingredients);
    } on AiRateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.ingredients);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    if (!mounted) return;
    if (recipe == null) {
      setState(() => _phase = _Phase.ingredients);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('fridge_recipe_generation_failed')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _recipe = recipe!;
      _missing = _service.missingIngredients(recipe, _ingredients);
      _phase = _Phase.recipe;
    });
  }

  Future<void> _addMissingToShoppingList() async {
    if (_missing.isEmpty) return;
    HapticFeedback.lightImpact();
    await ShoppingListService.instance.load();
    await ShoppingListService.instance.addItemsFromRecipe(_missing);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_missing.length == 1
          ? context.tr('fridge_shopping_added_one')
          : context.tr('fridge_shopping_added_many',
            values: {'count': _missing.length})),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF16A34A),
    ));
  }

  void _restart() {
    setState(() {
      _phase = _Phase.start;
      _photo = null;
      _ingredients = [];
      _recipe = null;
      _missing = [];
      _sharing = false;
      _shared = false;
    });
  }

  /// Speichert das generierte KI-Rezept in den Familien-Rezepten (Phase 3a).
  /// Der Nutzer wählt zuerst die Sichtbarkeit (Standard: Nur meine Freunde).
  Future<void> _saveToFamilyRecipes(FamilyRecipe r) async {
    final visibility = await _chooseVisibility();
    if (visibility == null) return; // abgebrochen
    setState(() => _sharing = true);
    try {
      final created = await _shareService.createRecipe(
        title: r.title,
        description: r.description,
        ingredients: r.ingredients,
        steps: r.steps,
        prepMinutes: r.prepMinutes,
        visibility: visibility,
      );
      if (!mounted) return;
      if (created != null) {
        setState(() {
          _sharing = false;
          _shared = true;
        });
        final destination = visibility == 'private'
          ? context.tr('fridge_saved_private')
          : visibility == 'public'
            ? context.tr('fridge_saved_public')
            : context.tr('fridge_saved_friends');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('fridge_save_success',
            values: {'destination': destination})),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF16A34A),
        ));
      } else {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('family_recipe_save_failed')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on SuspendedAccountException {
      if (mounted) {
        setState(() => _sharing = false);
        await showAccountSuspendedNotice(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('family_recipe_save_failed')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Kleine Auswahl der Sichtbarkeit. Gibt 'friends' | 'public' | 'private'
  /// zurück, oder null bei Abbruch.
  Future<String?> _chooseVisibility() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        Widget option(
            String value, String title, String subtitle, IconData icon) {
          return ListTile(
            leading: Icon(icon, color: _accent),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle, style: theme.textTheme.labelSmall),
            onTap: () => Navigator.pop(ctx, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(context.tr('family_recipe_visibility_title'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              option(
                  'friends',
                  context.tr('family_recipe_visibility_friends'),
                  context.tr('family_recipe_visibility_friends_hint'),
                  Icons.group_rounded),
              option(
                  'public',
                  context.tr('family_recipe_visibility_public'),
                  context.tr('family_recipe_visibility_public_hint'),
                  Icons.public_rounded),
              option(
                  'private',
                  context.tr('family_recipe_visibility_private'),
                  context.tr('family_recipe_visibility_private_hint'),
                  Icons.lock_outline_rounded),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('fridge_title')),
        elevation: 0,
        actions: [
          if (_phase != _Phase.start)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.tr('fridge_restart'),
              onPressed: _restart,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoArea(theme),
            const SizedBox(height: 20),
            if (_phase == _Phase.start) _startHint(theme),
            if (_phase == _Phase.detecting)
              _busy(theme, context.tr('fridge_inspecting_photo')),
            if (_phase == _Phase.ingredients) _ingredientsSection(theme),
            if (_phase == _Phase.generating)
              _busy(theme, context.tr('fridge_generating_recipe')),
            if (_phase == _Phase.recipe && _recipe != null)
              _recipeSection(theme, _recipe!),
          ],
        ),
      ),
    );
  }

  Widget _photoArea(ThemeData theme) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _photo != null
          ? SafeXFileImage(
              file: _photo!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 180,
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📸🥕', style: TextStyle(fontSize: 34)),
                  const SizedBox(height: 8),
                  Text(context.tr('fridge_photo_question'),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
    );
  }

  Widget _startHint(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('fridge_intro'),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(context.tr('fridge_take_photo')),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(context.tr('fridge_choose_photo')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _busy(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: _accent),
            const SizedBox(height: 16),
            Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _ingredientsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('fridge_detected_ingredients'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(context.tr('fridge_edit_ingredients_hint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (_ingredients.isEmpty)
          Text(context.tr('fridge_no_ingredients'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ingredients
                .map((ing) => Chip(
                      label: Text(ing),
                      onDeleted: () => _removeIngredient(ing),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      backgroundColor: _accent.withValues(alpha: 0.10),
                      side: BorderSide(color: _accent.withValues(alpha: 0.4)),
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ))
                .toList(),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _addIngredient(),
                decoration: InputDecoration(
                  hintText: context.tr('fridge_add_ingredient_hint'),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addIngredient,
              style: IconButton.styleFrom(backgroundColor: _accent),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(context.tr('fridge_suggest_recipe')),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recipeSection(ThemeData theme, FamilyRecipe r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.schedule_rounded,
                size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(r.timeLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(width: 12),
            Icon(Icons.child_care_rounded,
                size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(r.ageLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        if (r.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(r.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
        ],
        const SizedBox(height: 16),
        Text(context.tr('fridge_ingredients_title'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...r.ingredients.map((ing) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(ing, style: theme.textTheme.bodyMedium)),
                ],
              ),
            )),
        const SizedBox(height: 16),
        Text(context.tr('fridge_preparation_title'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...List.generate(r.steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: _accent)),
                Expanded(
                    child: Text(r.steps[i],
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
              ],
            ),
          );
        }),
        if (r.tip.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 '),
                Expanded(
                    child: Text(r.tip,
                        style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4, fontStyle: FontStyle.italic))),
              ],
            ),
          ),
        ],
        if (_missing.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('fridge_missing_title'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _missing
                      .map((m) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: theme.colorScheme.outlineVariant),
                            ),
                            child: Text(m, style: theme.textTheme.labelSmall),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addMissingToShoppingList,
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(_missing.length == 1
                      ? context.tr('fridge_add_missing_one')
                      : context.tr('fridge_add_missing_many')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        // Brücke zu Phase 3a: dieses KI-Rezept in den Familien-Rezepten
        // speichern/teilen (1 Tap, mit Sichtbarkeits-Auswahl).
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _sharing || _shared ? null : () => _saveToFamilyRecipes(r),
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _shared ? Icons.check_rounded : Icons.bookmark_add_rounded),
            label: Text(_shared
                ? 'In Familien-Rezepten gespeichert'
                : 'In Familien-Rezepten teilen'),
            style: FilledButton.styleFrom(
              backgroundColor: _shared ? const Color(0xFF16A34A) : _accent,
              disabledBackgroundColor: _shared ? const Color(0xFF16A34A) : null,
              disabledForegroundColor: _shared ? Colors.white : null,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Neues Foto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accent),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
