import 'package:flutter/material.dart';

/// Shared colors for Garden Town County standard buttons.
abstract final class AppButtonColors {
  static Color get cancelBg => Colors.black;
  static Color get cancelFg => Colors.white;
  static Color get cancelBorder => Colors.red.shade700;

  static Color get saveBg => Colors.green.shade700;
  static Color get saveFg => Colors.white;
  static Color get saveBorder => Colors.green.shade700;

  static Color get deleteBg => Colors.red.shade700;
  static Color get deleteFg => Colors.white;
  static Color get deleteBorder => Colors.red.shade700;

  static Color get addBg => Colors.blue.shade700;
  static Color get addFg => Colors.white;
  static Color get addBorder => Colors.blue.shade700;

  static Color get editBg => Colors.amber.shade600;
  static Color get editFg => Colors.black;
  static Color get editBorder => Colors.amber.shade600;

  static Color get viewBg => Colors.grey.shade700;
  static Color get viewFg => Colors.white;
  static Color get viewBorder => Colors.grey.shade600;

  static Color get actionBg => Colors.blue.shade700;
  static Color get actionFg => Colors.white;
  static Color get actionBorder => Colors.blue.shade700;
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
  Color? progressColor,
}) {
  if (isLoading) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: progressColor ?? color,
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

// ============================================================
// 1. CANCEL — Black + white text + red border
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
    return _wrapSize(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppButtonColors.cancelBg,
          foregroundColor: AppButtonColors.cancelFg,
          disabledForegroundColor: Colors.white54,
          disabledBackgroundColor: Colors.grey.shade900,
          side: BorderSide(color: AppButtonColors.cancelBorder, width: 2),
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
// 2. SAVE — Green + white text + green border
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
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppButtonColors.saveBg,
          foregroundColor: AppButtonColors.saveFg,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.grey.shade500,
          side: BorderSide(color: AppButtonColors.saveBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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
// 3. DELETE — Red + white text
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
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppButtonColors.deleteBg,
          foregroundColor: AppButtonColors.deleteFg,
          side: BorderSide(color: AppButtonColors.deleteBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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
// 4. ADD — Blue + white text
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
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppButtonColors.addBg,
          foregroundColor: AppButtonColors.addFg,
          side: BorderSide(color: AppButtonColors.addBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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
// 5. EDIT — Amber + BLACK text
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
    return _wrapSize(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppButtonColors.editBg,
          foregroundColor: AppButtonColors.editFg,
          side: BorderSide(color: AppButtonColors.editBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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
// 6. VIEW — Grey + white text
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
    return _wrapSize(
      width: width,
      height: height,
      defaultHeight: 35,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppButtonColors.viewBg,
          foregroundColor: AppButtonColors.viewFg,
          side: BorderSide(color: AppButtonColors.viewBorder, width: 1),
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
// 7. ACTION / GO — Blue + white text
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
    return _wrapSize(
      width: width,
      height: height,
      defaultHeight: 40,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppButtonColors.actionBg,
          foregroundColor: AppButtonColors.actionFg,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.grey.shade500,
          side: BorderSide(color: AppButtonColors.actionBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
// 8. SUBMIT — same as Save (green)
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
// 9. BACKUP — Blue + white text
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
    return ActionButton(
      onPressed: onPressed,
      text: text,
      width: width,
      height: height ?? 45,
      icon: icon,
    );
  }
}

// ============================================================
// 10. RESTORE — Amber + BLACK text (same as Edit)
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
    return EditButton(
      onPressed: onPressed,
      text: text,
      width: width,
      height: height,
      icon: icon,
    );
  }
}

// ============================================================
// 11. ENABLE — Green + white text (same as Save)
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
    return SaveButton(
      onPressed: onPressed,
      text: text,
      width: width,
      height: height,
      icon: icon,
    );
  }
}
