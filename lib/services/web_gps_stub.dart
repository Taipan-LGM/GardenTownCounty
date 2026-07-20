/// Non-web stub — GPS handled by Geolocator path.
import 'gps_fix.dart';

Future<GpsFix?> readBestWebPosition({
  required Duration sampleFor,
  required double targetAccuracyM,
}) async =>
    null;
