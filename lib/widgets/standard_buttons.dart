import 'package:flutter/material.dart';

/// Shared colors for Garden Town County standard buttons.
///
/// Border rule (always):
/// - Dark fills → light borders
/// - Light fills → dark borders
///
/// Surprise: "Assembly Seal" — double ring (contrast outer + type accent
/// inner) with a hard offset stamp shadow and a gold county ribbon notch.
abstract final class AppButtonColors {
  /// Light rim for dark buttons (readable on black / green / red / blue / grey).
  static const Color lightBorder = Color(0xFFF2E6C8); // warm parchment

  /// Dark rim for light buttons (amber Edit / Restore).
  static const Color darkBorder = Color(0xFF1A1208); // near-black ink

  /// County gold used as the surprise accent ribbon / inner glint.
  static const Color sealGold = Color(0xFFD4A017);

  static Color get cancelBg => Colors.black;
  static Color get cancelFg => Colors.white;
  static Color get cancelAccent => Colors.red.shade400;

  static Color get saveBg => Colors.green.shade700;
  static Color get saveFg => Colors.white;
  static Color get saveAccent => Colors.green.shade300;

  static Color get deleteBg => Colors.red.shade700;
  static Color get deleteFg => Colors.white;
  static Color get deleteAccent => Colors.red.shade200;

  static Color get addBg => Colors.blue.shade700;
  static Color get addFg => Colors.white;
  static Color get addAccent => Colors.lightBlue.shade200;

  static Color get editBg => Colors.amber.shade600;
  static Color get editFg => Colors.black;
  static Color get editAccent => const Color(0xFF5C3B00);

  static Color get viewBg => Colors.grey.shade700;
  static Color get viewFg => Colors.white;
  static Color get viewAccent => Colors.grey.shade300;

  static Color get actionBg => Colors.blue.shade700;
  static Color get actionFg => Colors.white;
  static Color get actionAccent => Colors.lightBlue.shade200;

  /// True when the fill is dark enough to need a light border.
  static bool isDarkFill(Color bg) => bg.computeLuminance() < 0.45;

  static Color contrastBorderFor(Color bg) =>
      isDarkFill(bg) ? lightBorder : darkBorder;
}

/// Shared seal chrome: outer contrast border + inner accent + stamp shadow.
class _SealFrame extends StatelessWidget {
  const _SealFrame({
    required this.fill,
    required this.accent,
    required this.child,
    this.height,
    this.width,
    this.defaultHeight = 45,
  });

  final Color fill;
  final Color accent;
  final Widget child;
  final double? height;
  final double? width;
  final double defaultHeight;

  @override
  Widget build(BuildContext context) {
    final contrast = AppButtonColors.contrastBorderFor(fill);
    final h = height ?? defaultHeight;

    return SizedBox(
      width: width,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Asymmetric radius — like a pressed county seal / ticket stub.
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(12),
          ),
          border: Border.all(color: contrast, width: 2.5),
          boxShadow: [
            // Hard offset "ink stamp" — surprise tactile element.
            BoxShadow(
              color: contrast.withValues(alpha: 0.55),
              offset: const Offset(2, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(9),
                bottomRight: Radius.circular(2),
                bottomLeft: Radius.circular(9),
              ),
              border: Border.all(color: accent, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(1),
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(1),
                bottomLeft: Radius.circular(8),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Gold county ribbon along the leading edge.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      color: AppButtonColors.sealGold,
                    ),
                  ),
                  // Soft top parchment glint on dark fills.
                  if (AppButtonColors.isDarkFill(fill))
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppButtonColors.lightBorder.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _bareFillStyle({
  required Color fill,
  required Color fg,
}) {
  return ButtonStyle(
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.grey.shade800;
      }
      return Colors.transparent; // fill comes from _SealFrame
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.grey.shade500;
      }
      return fg;
    }),
    overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.12)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.fromLTRB(14, 10, 12, 10),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    side: const WidgetStatePropertyAll(BorderSide.none),
  );
}

TextStyle _labelStyle({
  required Color color,
  double fontSize = 14,
}) {
  return TextStyle(
    color: color,
    fontWeight: FontWeight.w600,
    fontSize: fontSize,
    letterSpacing: 0.3,
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
  final label = Text(
    text,
    textAlign: TextAlign.center,
    style: _labelStyle(color: color, fontSize: fontSize),
  );
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

Widget _sealedButton({
  required VoidCallback? onPressed,
  required Color fill,
  required Color fg,
  required Color accent,
  required String text,
  IconData? icon,
  bool isLoading = false,
  double? width,
  double? height,
  double defaultHeight = 45,
  double fontSize = 14,
}) {
  return _SealFrame(
    fill: fill,
    accent: accent,
    width: width,
    height: height,
    defaultHeight: defaultHeight,
    child: TextButton(
      onPressed: isLoading ? null : onPressed,
      style: _bareFillStyle(fill: fill, fg: fg),
      child: _buttonChild(
        text: text,
        color: fg,
        icon: icon,
        isLoading: isLoading,
        fontSize: fontSize,
      ),
    ),
  );
}

// ============================================================
// 1. CANCEL — Black fill, light outer border, red accent ring
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.cancelBg,
      fg: AppButtonColors.cancelFg,
      accent: AppButtonColors.cancelAccent,
      text: text,
      icon: icon,
      width: width,
      height: height,
      fontSize: fontSize ?? 14,
    );
  }
}

// ============================================================
// 2. SAVE — Green fill, light border, green accent
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.saveBg,
      fg: AppButtonColors.saveFg,
      accent: AppButtonColors.saveAccent,
      text: text,
      icon: icon,
      isLoading: isLoading,
      width: width,
      height: height,
    );
  }
}

// ============================================================
// 3. DELETE — Red fill, light border, soft red accent
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.deleteBg,
      fg: AppButtonColors.deleteFg,
      accent: AppButtonColors.deleteAccent,
      text: text,
      icon: icon,
      width: width,
      height: height,
    );
  }
}

// ============================================================
// 4. ADD — Blue fill, light border, sky accent
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.addBg,
      fg: AppButtonColors.addFg,
      accent: AppButtonColors.addAccent,
      text: text,
      icon: icon,
      width: width,
      height: height,
    );
  }
}

// ============================================================
// 5. EDIT — Amber (light) fill, DARK border, deep-bronze accent
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.editBg,
      fg: AppButtonColors.editFg,
      accent: AppButtonColors.editAccent,
      text: text,
      icon: icon,
      width: width,
      height: height,
    );
  }
}

// ============================================================
// 6. VIEW — Grey fill, light border, silver accent
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.viewBg,
      fg: AppButtonColors.viewFg,
      accent: AppButtonColors.viewAccent,
      text: text,
      icon: icon,
      width: width,
      height: height,
      defaultHeight: 35,
      fontSize: 12,
    );
  }
}

// ============================================================
// 7. ACTION / GO — Blue fill, light border
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
    return _sealedButton(
      onPressed: onPressed,
      fill: AppButtonColors.actionBg,
      fg: AppButtonColors.actionFg,
      accent: AppButtonColors.actionAccent,
      text: text,
      icon: icon,
      isLoading: isLoading,
      width: width,
      height: height,
      defaultHeight: 40,
      fontSize: 13,
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
// 9. BACKUP — Blue (Action)
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
// 10. RESTORE — Amber (Edit) — light fill → dark border
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
// 11. ENABLE — Green (Save)
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
