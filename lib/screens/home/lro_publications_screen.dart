import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lro_publication.dart';
import '../../providers/providers.dart';

/// Displays all Land Recording Office (LRO) Public Notices published for the
/// County. Visible to every user of the app.
class LroPublicationsScreen extends ConsumerStatefulWidget {
  const LroPublicationsScreen({super.key});

  @override
  ConsumerState<LroPublicationsScreen> createState() =>
      _LroPublicationsScreenState();
}

class _LroPublicationsScreenState extends ConsumerState<LroPublicationsScreen> {
  List<LroPublication> _publications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final items = await db.getLroPublications();
      if (!mounted) return;
      setState(() {
        _publications = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 24),
            const SizedBox(width: 8),
            Text(strings.lroPublications),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: strings.refresh,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CountyConnect brand banner.
          Container(
            color: AppTheme.forestGreen,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/countyconnect_logo.png',
                  height: 44,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        strings.appSlogan,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : _publications.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book_outlined, size: 64),
                                  const SizedBox(height: 16),
                                  Text(
                                    strings.lroPublications,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    strings.lroPublicationsEmpty,
                                    style: TextStyle(color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _publications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final pub = _publications[index];
                              return _PublicationCard(pub: pub);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _PublicationCard extends StatefulWidget {
  const _PublicationCard({required this.pub});

  final LroPublication pub;

  @override
  State<_PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends State<_PublicationCard> {
  Uint8List? _imageBytes;
  bool _loadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final db = ProviderScope.containerOf(context).read(databaseServiceProvider);
      final bytes = await db.getLroNoticeImage(widget.pub.memberId);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _loadingImage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pub = widget.pub;
    final dateStr = DateFormat('dd/MM/yyyy').format(pub.publishedAt);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pub.memberName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Recording No: ${pub.recordingNumber}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Published: $dateStr',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_loadingImage)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('Notice image unavailable')),
              ),
          ],
        ),
      ),
    );
  }
}
