class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
}
