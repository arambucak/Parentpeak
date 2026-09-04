import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:parentpeak/logic/fridge_recipe_service.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/shopping_item.dart';
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
  final _picker = ImagePicker();
  final _addCtrl = TextEditingController();

  _Phase _phase = _Phase.start;
  XFile? _photo;
  List<String> _ingredients = [];
  FamilyRecipe? _recipe;
  List<String> _missing = [];

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Ich konnte keine Zutaten sicher erkennen. Du kannst sie unten '
              'einfach selbst ergänzen.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _Phase.start);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto konnte nicht verarbeitet werden.'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitte füge mindestens eine Zutat hinzu.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _phase = _Phase.generating);
    final recipe = await _service.generateFromIngredients(_ingredients);
    if (!mounted) return;
    if (recipe == null) {
      setState(() => _phase = _Phase.ingredients);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Konnte gerade kein Rezept erstellen — bitte erneut versuchen.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _recipe = recipe;
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
          ? '1 Zutat auf die Einkaufsliste gesetzt. 🛒'
          : '${_missing.length} Zutaten auf die Einkaufsliste gesetzt. 🛒'),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aus dem, was da ist'),
        elevation: 0,
        actions: [
          if (_phase != _Phase.start)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Neu starten',
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
              _busy(theme, 'Ich schaue mir dein Foto an …'),
            if (_phase == _Phase.ingredients) _ingredientsSection(theme),
            if (_phase == _Phase.generating)
              _busy(theme, 'Ich zaubere ein Rezept …'),
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
                  Text('Was ist im Kühlschrank?',
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
          'Mach ein Foto von deinen Lebensmitteln – ich erkenne die Zutaten '
          'und schlage ein kindgerechtes Rezept vor.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Foto machen'),
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
                label: const Text('Auswählen'),
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
        Text('Erkannte Zutaten',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Tippe auf das ✕, um etwas zu entfernen, oder füge unten hinzu.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (_ingredients.isEmpty)
          Text('Noch keine Zutaten – füge unten welche hinzu.',
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
                      side: BorderSide(
                          color: _accent.withValues(alpha: 0.4)),
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
                  hintText: 'Zutat hinzufügen …',
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
            label: const Text('Rezept vorschlagen'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        Text('Zutaten',
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
        Text('Zubereitung',
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
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
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
                Text('Dafür fehlt noch',
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
                        ? 'Fehlende Zutat auf die Einkaufsliste'
                        : 'Fehlende Zutaten auf die Einkaufsliste'),
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
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
