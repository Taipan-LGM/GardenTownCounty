import 'dart:io';

import 'package:flutter/material.dart';

bool localFileExists(String path) => File(path).existsSync();

ImageProvider localFileImage(String path) => FileImage(File(path));
