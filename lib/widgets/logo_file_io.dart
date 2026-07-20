import 'dart:io';

import 'package:flutter/material.dart';

Widget fileLogoImage(String path, BoxFit fit) {
  return Image.file(
    File(path),
    fit: fit,
    filterQuality: FilterQuality.high,
  );
}

bool fileLogoExists(String path) => File(path).existsSync();
