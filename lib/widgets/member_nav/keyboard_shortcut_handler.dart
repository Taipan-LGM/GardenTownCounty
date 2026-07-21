import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop/web keyboard shortcuts for Member Info navigation.
class KeyboardShortcutHandler extends StatelessWidget {
  const KeyboardShortcutHandler({
    super.key,
    required this.child,
    this.enabled = true,
    this.onNext,
    this.onPrevious,
    this.onPageNext,
    this.onPagePrevious,
    this.onSearch,
    this.onEdit,
    this.onSave,
    this.onDelete,
    this.onUpload,
    this.onBack,
    this.onNew,
    this.onRefresh,
    this.onHome,
    this.onEnd,
    this.onOpenHighlighted,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onPageNext;
  final VoidCallback? onPagePrevious;
  final VoidCallback? onSearch;
  final VoidCallback? onEdit;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onUpload;
  final VoidCallback? onBack;
  final VoidCallback? onNew;
  final VoidCallback? onRefresh;
  final VoidCallback? onHome;
  final VoidCallback? onEnd;
  final VoidCallback? onOpenHighlighted;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!enabled || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final isCtrl = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;

        if (key == LogicalKeyboardKey.arrowUp) {
          onPrevious?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          onNext?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          onPagePrevious?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          onPageNext?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          onBack?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          onOpenHighlighted?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.home) {
          onHome?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.end) {
          onEnd?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyF && isCtrl) {
          onSearch?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyE && isCtrl) {
          onEdit?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyS && isCtrl) {
          onSave?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyN && isCtrl) {
          onNew?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyD && isCtrl) {
          onDelete?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyU && isCtrl) {
          onUpload?.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyR && isCtrl) {
          onRefresh?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
