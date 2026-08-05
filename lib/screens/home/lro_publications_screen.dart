import 'package:flutter/material.dart';

class LroPublicationsScreen extends StatelessWidget {
  const LroPublicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'LRO Publications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Publications will be available here soon.'),
          ],
        ),
      ),
    );
  }
}
