import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../standard_buttons.dart';
import '../file_image_stub.dart'
    if (dart.library.io) '../file_image_io.dart' as file_img;

/// Member photo preview with upload / change / remove actions.
class MemberPhotoPanel extends StatelessWidget {
  const MemberPhotoPanel({
    super.key,
    required this.photoBytes,
    required this.photoUrl,
    required this.photoLocalPath,
    required this.busy,
    required this.readOnly,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? photoLocalPath;
  final bool busy;
  final bool readOnly;

  /// Must be invoked directly from the tap handler — on web the file picker is
  /// ignored unless it opens in the same user-gesture turn.
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (photoBytes != null) {
      image = MemoryImage(photoBytes!);
    } else if (photoUrl != null &&
        photoUrl!.isNotEmpty &&
        !photoUrl!.startsWith('data:')) {
      image = NetworkImage(photoUrl!);
    } else if (photoLocalPath != null &&
        !photoLocalPath!.startsWith('web-photo://') &&
        file_img.localFileExists(photoLocalPath!)) {
      image = file_img.localFileImage(photoLocalPath!);
    }

    const photoSize = 320.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: (busy || readOnly) ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: photoSize,
            height: photoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.forestGreen, width: 2),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const CircularProgressIndicator()
                      else ...[
                        const Icon(
                          Icons.add_a_photo_outlined,
                          size: 44,
                          color: AppTheme.bodyText,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Member Photo',
                          style: TextStyle(
                            color: AppTheme.bodyText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  )
                : busy
                    ? const ColoredBox(
                        color: Colors.black26,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : null,
          ),
        ),
        const SizedBox(height: 8),
        image == null
            ? AddButton(
                onPressed: (busy || readOnly) ? null : onPick,
                text: 'Upload Photo',
                icon: Icons.photo_camera_outlined,
                height: 35,
                backgroundColor: AppButtonColors.saveBg,
                foregroundColor: AppButtonColors.saveFg,
                borderColor: AppButtonColors.whiteRing,
              )
            : EditButton(
                onPressed: (busy || readOnly) ? null : onPick,
                text: 'Change Photo',
                icon: Icons.photo_camera_outlined,
                height: 35,
              ),
        if (image != null && !readOnly)
          DeleteButton(
            onPressed: busy ? null : onClear,
            text: 'Remove',
            height: 35,
          ),
      ],
    );
  }
}
