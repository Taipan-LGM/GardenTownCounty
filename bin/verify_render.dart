import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../lib/services/lro_notice_renderer.dart';
import '../lib/models/lro_notice_template.dart';
import '../lib/models/lro_status_correction.dart' as sc;

void main() {
  final style = const LroNoticeTemplateStyle();
  final sample = const [
    sc.LroStatusCorrection(description: 'Voter Deregistration', isChecked: true),
    sc.LroStatusCorrection(description: 'BIO Pages', isChecked: true),
    sc.LroStatusCorrection(description: '2 x Witness Testimonies', isChecked: true),
    sc.LroStatusCorrection(description: 'Universal Declaration', isChecked: true),
  ];
  final bytes = LroNoticeRenderer.render(
    style: style,
    countyName: 'Garden Town County',
    memberName: 'John Doe',
    recordingNumber: '0241501251234567',
    paymentDate: DateTime.now(),
    statusCorrections: sample,
    sealBytes: null,
  );
  File('bin/verify_notice.png').writeAsBytesSync(bytes);

  // Build a 2x-upscaled crop so the 1mm/2mm shifts are visible to the eye.
  final image = img.decodeImage(bytes)!;
  // Crop the region around the header + status corrections.
  // Header is near the top; status corrections a bit lower.
  final crop = img.copyCrop(image,
      x: 0, y: 0, width: image.width, height: image.height);
  final scaled = img.copyResize(crop, width: image.width * 2, height: image.height * 2);
  File('bin/verify_notice_2x.png').writeAsBytesSync(img.encodePng(scaled));
  print('wrote bin/verify_notice.png (${image.width}x${image.height}) and bin/verify_notice_2x.png');
}
