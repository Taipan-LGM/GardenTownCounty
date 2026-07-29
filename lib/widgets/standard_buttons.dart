import 'package:flutter/material.dart';

/// Shared colors for Garden Town County standard buttons.
///
/// Rings:
/// - Dark fills → white ring
/// - Light fills → black ring
///
/// Each button *type* has a unique fill so neighbors never share a colour.
abstract final class AppButtonColors {
  static const Color whiteRing = Colors.white;
  static const Color blackRing = Colors.black;

  // Dark fills (white ring)
  static Color get cancelBg => Colors.black;
  static Color get cancelFg => Colors.white;

  static Color get saveBg => Colors.green.shade700;
  static Color get saveFg => Colors.white;

  static Color get deleteBg => Colors.red.shade700;
  static Color get deleteFg => Colors.white;

  static Color get addBg => Colors.blue.shade700;
  static Color get addFg => Colors.white;

  /// Distinct from Add (blue) and Backup (teal).
  static Color get actionBg => Colors.indigo.shade700;
  static Color get actionFg => Colors.white;

  /// Distinct from Add (blue) and Action (indigo).
  static Color get backupBg => Colors.teal.shade700;
  static Color get backupFg => Colors.white;

  /// Distinct from Save (green.shade700).
  static Color get enableBg => Colors.lightGreen.shade800;
  static Color get enableFg => Colors.white;

  static Color get viewBg => Colors.grey.shade700;
  static Color get viewFg => Colors.white;

  // Light fills (black ring)
  static Color get editBg => Colors.amber.shade600;
  static Color get editFg => Colors.black;

  /// Distinct from Edit (amber.shade600) — lighter peach.
  static Color get restoreBg => const Color(0xFFFFCC80);
  static Color get restoreFg => Colors.black;

  static BorderSide ringFor(Color bg) {
    final dark = bg.computeLuminance() < 0.45;
    return BorderSide(
      color: dark ? whiteRing : blackRing,
      width: 2.5,
    );
  }
}

Widget _wrapSize({
  required Widget child,
  double? width,
  double? height,
  double defaultHeight = 45,
}) {
  return SizedBox(
    width: width,
    height: height ?? defaultHeight,
    child: child,
  );
}

TextStyle _labelStyle({
  required Color color,
  double fontSize = 14,
}) {
  return TextStyle(
    color: color,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
  );
}

Widget _buttonChild({
  required String text,
  required Color color,
  IconData? icon,
  bool isLoading = false,
  double fontSize = 14,
}) {
  if (isLoading) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
  final label = Text(text, style: _labelStyle(color: color, fontSize: fontSize));
  if (icon == null) return label;
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: fontSize + 4, color: color),
      const SizedBox(width: 8),
      Flexible(child: label),
    ],
  );
}

ButtonStyle _filledStyle({
  required Color bg,
  required Color fg,
}) {
  return ElevatedButton.styleFrom(
    backgroundColor: bg,
    foregroundColor: fg,
    disabledBackgroundColor: Colors.grey.shade700,
    disabledForegroundColor: Colors.grey.shade500,
    side: AppButtonColors.ringFor(bg),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}

// ============================================================
// 1. CANCEL — Black + white ring
// ============================================================
class CancelButton extends StatelessWidget {
  const CancelButton({
    super.key,
    required this.onPressed,
    this.text = 'Cancel',
    this.width,
    this.height,
    this.fontSize,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final double? fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.cancelBg;
    return _wrapSize(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: AppButtonColors.cancelFg,
          disabledForegroundColor: Colors.white54,
          disabledBackgroundColor: Colors.grey.shade900,
          side: AppButtonColors.ringFor(bg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.cancelFg,
          icon: icon,
          fontSize: fontSize ?? 14,
        ),
      ),
    );
  }
}

// ============================================================
// 2. SAVE — Green + white ring
// ============================================================
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.onPressed,
    this.text = 'Save',
    this.isLoading = false,
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.saveBg;
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.saveFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.saveFg,
          icon: icon,
          isLoading: isLoading,
        ),
      ),
    );
  }
}

// ============================================================
// 3. DELETE — Red + white ring
// ============================================================
class DeleteButton extends StatelessWidget {
  const DeleteButton({
    super.key,
    required this.onPressed,
    this.text = 'Delete',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.deleteBg;
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.deleteFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.deleteFg,
          icon: icon,
        ),
      ),
    );
  }
}

// ============================================================
// 4. ADD — Blue + white ring
// ============================================================
class AddButton extends StatelessWidget {
  const AddButton({
    super.key,
    required this.onPressed,
    this.text = 'Add',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.addBg;
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.addFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.addFg,
          icon: icon,
        ),
      ),
    );
  }
}

// ============================================================
// 5. EDIT — Amber (light) + black ring
// ============================================================
class EditButton extends StatelessWidget {
  const EditButton({
    super.key,
    required this.onPressed,
    this.text = 'Edit',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.editBg;
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.editFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.editFg,
          icon: icon,
        ),
      ),
    );
  }
}

// ============================================================
// 6. VIEW — Grey + white ring
// ============================================================
class ViewButton extends StatelessWidget {
  const ViewButton({
    super.key,
    required this.onPressed,
    this.text = 'View',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.viewBg;
    return _wrapSize(
      width: width,
      height: height,
      defaultHeight: 35,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: AppButtonColors.viewFg,
          side: AppButtonColors.ringFor(bg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.viewFg,
          icon: icon,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ============================================================
// 7. ACTION / GO — Indigo + white ring (not blue — distinct from Add)
// ============================================================
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.onPressed,
    this.text = 'Go',
    this.width,
    this.height,
    this.icon,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.actionBg;
    return _wrapSize(
      width: width,
      height: height,
      defaultHeight: 40,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.actionFg).copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.actionFg,
          icon: icon,
          isLoading: isLoading,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ============================================================
// 8. SUBMIT — same green as Save (never shown beside Save)
// ============================================================
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.onPressed,
    this.text = 'Submit',
    this.isLoading = false,
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SaveButton(
      onPressed: onPressed,
      text: text,
      isLoading: isLoading,
      width: width,
      height: height,
      icon: icon,
    );
  }
}

// ============================================================
// 9. BACKUP — Teal + white ring (distinct from Add / Action)
// ============================================================
class BackupButton extends StatelessWidget {
  const BackupButton({
    super.key,
    required this.onPressed,
    this.text = 'Create Backup',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.backupBg;
    return _wrapSize(
      width: width,
      height: height ?? 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.backupFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.backupFg,
          icon: icon,
        ),
      ),
    );
  }
}

// ============================================================
// 10. RESTORE — Light peach + black ring (distinct from Edit amber)
// ============================================================
class RestoreButton extends StatelessWidget {
  const RestoreButton({
    super.key,
    required this.onPressed,
    this.text = 'Restore Backup',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.restoreBg;
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.restoreFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.restoreFg,
          icon: icon,
        ),
      ),
    );
  }
}

// ============================================================
// 11. ENABLE — Light-green + white ring (distinct from Save)
// ============================================================
class EnableButton extends StatelessWidget {
  const EnableButton({
    super.key,
    required this.onPressed,
    this.text = 'Enable',
    this.width,
    this.height,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = AppButtonColors.enableBg;
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: _filledStyle(bg: bg, fg: AppButtonColors.enableFg),
        child: _buttonChild(
          text: text,
          color: AppButtonColors.enableFg,
          icon: icon,
        ),
      ),
    );
  }
}
