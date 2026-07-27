import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../home/info_content_screen.dart';
import '../home/videos_content_screen.dart';

/// Admin management for Info articles + Videos.
///
/// // NEW ADDITION - Delete this file to revert Video & Info Management.
class VideoInfoManagementScreen extends ConsumerWidget {
  const VideoInfoManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Video & Info Management'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Admin access required.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Video & Info Management',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Articles', icon: Icon(Icons.article)),
              Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            ],
          ),
        ),
        body: const ColoredBox(
          color: Colors.black,
          child: TabBarView(
            children: [
              InfoContentScreen(),
              VideosContentScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
