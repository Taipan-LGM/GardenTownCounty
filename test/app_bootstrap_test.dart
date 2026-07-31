import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/app.dart';
import 'package:garden_town_county/main.dart';

void main() {
  testWidgets('bootstrap uses the real app widget', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byType(GardenTownCountyApp), findsOneWidget);
    expect(find.text('Garden Town County app is loading...'), findsNothing);
  });
}
