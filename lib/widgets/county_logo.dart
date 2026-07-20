import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../providers/providers.dart';
import 'logo_file_io_stub.dart'
    if (dart.library.io) 'logo_file_io.dart' as logo_io;

/// Round county logo — custom upload or default asset.
class CountyLogoImage extends ConsumerWidget {
  const CountyLogoImage({
    super.key,
    this.secondary = false,
    this.fit = BoxFit.contain,
  });

  final bool secondary;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(countyProfileProvider).valueOrNull;
    final path = secondary
        ? (profile?.secondaryLogoPath ?? profile?.logoPath)
        : profile?.logoPath;

    if (path != null && path.startsWith('web://')) {
      return FutureBuilder<Uint8List?>(
        future: ref.read(countySettingsServiceProvider).loadWebLogoBytes(
              secondary: secondary || path == 'web://logo2',
            ),
        builder: (context, snap) {
          if (snap.data != null) {
            return Image.memory(
              snap.data!,
              fit: fit,
              filterQuality: FilterQuality.high,
            );
          }
          return _asset(fit);
        },
      );
    }

    if (path != null && !kIsWeb && logo_io.fileLogoExists(path)) {
      return logo_io.fileLogoImage(path, fit);
    }

    return _asset(fit);
  }

  Widget _asset(BoxFit fit) {
    return Image.asset(
      AppConstants.logoAsset,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.black26,
        child: Center(
          child: Icon(Icons.account_balance, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}

/// Circular clip around [CountyLogoImage].
class RoundCountyLogo extends StatelessWidget {
  const RoundCountyLogo({
    super.key,
    this.secondary = false,
    this.size,
  });

  final bool secondary;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final child = ClipOval(
      child: CountyLogoImage(secondary: secondary, fit: BoxFit.cover),
    );
    if (size == null) return child;
    return SizedBox(width: size, height: size, child: child);
  }
}

/// Persistent top-right corner logo after landing animation.
class CornerLogoOverlay extends StatelessWidget {
  const CornerLogoOverlay({super.key});

  static const double size = 60;
  static const double top = 20;
  static const double right = 20;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top + MediaQuery.paddingOf(context).top,
      right: right,
      child: Material(
        elevation: 4,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: RoundCountyLogo(secondary: true, size: size),
      ),
    );
  }
}
