import 'package:flutter/material.dart';

/// Space kept around a focused field when it is scrolled into view, so the
/// field plus a bit of context stays visible above the keyboard/navigation.
const EdgeInsets kFormFieldScrollPadding = EdgeInsets.fromLTRB(20, 20, 20, 48);

/// Below this available body height, decorative headers are collapsed even
/// without a keyboard (small phones, landscape, very large text scaling).
const double kCompactFormHeight = 420;

/// Whether the on-screen keyboard currently occupies space.
///
/// A [Scaffold] with `resizeToAvoidBottomInset` strips `viewInsets.bottom`
/// from its body's [MediaQuery], so inside a body that value is always 0.
/// The [View] still reports the real inset.
bool isSoftKeyboardVisible(BuildContext context) {
  final viewInset = View.maybeOf(context)?.viewInsets.bottom ?? 0;
  return viewInset > 0 || MediaQuery.viewInsetsOf(context).bottom > 0;
}

/// Rebuilds with `compact == true` while the keyboard is open or the
/// available height is small. Listens to window metrics directly because the
/// enclosing [Scaffold] hides keyboard insets from [MediaQuery].
class KeyboardAwareBuilder extends StatefulWidget {
  const KeyboardAwareBuilder({
    super.key,
    required this.builder,
    this.compactHeight = kCompactFormHeight,
  });

  final Widget Function(BuildContext context, bool compact) builder;
  final double compactHeight;

  @override
  State<KeyboardAwareBuilder> createState() => _KeyboardAwareBuilderState();
}

class _KeyboardAwareBuilderState extends State<KeyboardAwareBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = isSoftKeyboardVisible(context) ||
            (constraints.hasBoundedHeight &&
                constraints.maxHeight < widget.compactHeight);
        return widget.builder(context, compact);
      },
    );
  }
}

/// Hides [child] while [visible] is false.
///
/// Deliberately not animated: the body shrinks in the same frame the keyboard
/// inset arrives, so a size animation would overflow on intermediate frames.
class CollapsibleFormHeader extends StatelessWidget {
  const CollapsibleFormHeader({
    super.key,
    required this.visible,
    required this.child,
    this.maxHeight,
  });

  final bool visible;
  final Widget child;

  /// When set, the visible header never takes more than this height and
  /// scrolls internally instead (e.g. with very large text scaling).
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final limit = maxHeight;
    if (limit == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: limit),
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Tapping empty space outside a text field closes the keyboard.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
