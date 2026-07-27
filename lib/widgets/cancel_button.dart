import 'package:flutter/material.dart';

/// Standard app Cancel control: black fill, white label, red border.
///
/// Use for every dismiss/abort action labeled "Cancel" (not "Cancel Membership").
class CancelButton extends StatelessWidget {
  const CancelButton({
    super.key,
    required this.onPressed,
    this.text = 'Cancel',
    this.width,
    this.height,
    this.fontSize,
  });

  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double? height;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 120,
      height: height ?? 45,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          disabledBackgroundColor: Colors.grey.shade900,
          side: BorderSide(
            color: Colors.red.shade700,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: fontSize ?? 14,
          ),
        ),
      ),
    );
  }
}
