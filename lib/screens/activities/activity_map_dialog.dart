import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_log.dart';

Future<void> showActivityMapDialog(
  BuildContext context,
  ActivityLog activity,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => ActivityMapDialog(activity: activity),
  );
}

class ActivityMapDialog extends StatelessWidget {
  const ActivityMapDialog({super.key, required this.activity});

  final ActivityLog activity;

  LatLng? get _point {
    final lat = activity.latitude;
    final lng = activity.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String get _mapsUrl {
    final p = _point!;
    return 'https://www.google.com/maps?q=${p.latitude},${p.longitude}';
  }

  String get _shareText {
    final p = _point!;
    return 'Garden Town County GPS\n'
        'User: ${activity.userName}\n'
        'Action: ${activity.action}\n'
        'Location: ${activity.locationLabel ?? '${p.latitude}, ${p.longitude}'}\n'
        'Map: $_mapsUrl';
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse(_mapsUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: _shareText));
  }

  Future<void> _whatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _printMap(BuildContext context) async {
    // Open printable map page; user can print from browser / Maps.
    await _openMaps();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map opened — use Print from the browser or Maps app.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    if (point == null) {
      return AlertDialog(
        title: const Text('GPS'),
        content: const Text('No GPS coordinates for this activity.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: AppTheme.forestGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GPS Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.forestGreen,
                          ),
                        ),
                        Text(
                          '${activity.userName} · ${activity.action}\n'
                          '${activity.locationLabel ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'garden_town_county',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_on,
                          color: AppTheme.brick,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _printMap(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save / Share'),
                  ),
                  FilledButton.icon(
                    onPressed: _whatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.map),
                    label: const Text('Open Maps'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
