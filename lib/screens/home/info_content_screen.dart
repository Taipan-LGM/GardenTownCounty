import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';

import '../../models/county_article.dart';
import '../../providers/providers.dart';
import '../../widgets/cancel_button.dart';

/// Member-facing Info tab — published county articles.
///
/// // NEW ADDITION - Delete this file to revert Info tab UI.
class InfoContentScreen extends ConsumerWidget {
  const InfoContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(publishedArticlesProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return ColoredBox(
      color: Colors.black,
      child: articlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
        data: (articles) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'County Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ok =
                              await showArticleEditorDialog(context, ref);
                          if (ok == true) {
                            ref.invalidate(publishedArticlesProvider);
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Article'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: articles.isEmpty
                    ? Center(
                        child: Text(
                          'No articles available.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: articles.length,
                        itemBuilder: (context, index) {
                          return _ArticleCard(
                            article: articles[index],
                            isAdmin: isAdmin,
                            onChanged: () =>
                                ref.invalidate(publishedArticlesProvider),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArticleCard extends ConsumerWidget {
  const _ArticleCard({
    required this.article,
    required this.isAdmin,
    required this.onChanged,
  });

  final CountyArticle article;
  final bool isAdmin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = article.content.length > 200
        ? '${article.content.substring(0, 200)}...'
        : article.content;
    final date = article.createdAt.toLocal().toString().substring(0, 10);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              date,
              if (article.author != null) 'by ${article.author}',
              if (article.category != null) article.category!,
            ].join(' · '),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            preview,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (article.content.length > 200)
                TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        title: Text(
                          article.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        content: SingleChildScrollView(
                          child: Text(
                            article.content,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              height: 1.5,
                            ),
                          ),
                        ),
                        actions: [
                          CancelButton(
                            onPressed: () => Navigator.pop(ctx),
                            text: 'Cancel',
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Read More →'),
                ),
              if (article.pdfLocalPath != null || article.pdfUrl != null)
                TextButton(
                  onPressed: () async {
                    final path = article.pdfLocalPath ?? article.pdfUrl!;
                    await OpenFile.open(path);
                  },
                  child: const Text('Download PDF'),
                ),
              if (isAdmin) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  onPressed: () async {
                    final ok = await showArticleEditorDialog(
                      context,
                      ref,
                      article,
                    );
                    if (ok == true) onChanged();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  onPressed: () async {
                    await ref
                        .read(countyMediaServiceProvider)
                        .softDeleteArticle(article.id);
                    onChanged();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool?> showArticleEditorDialog(
  BuildContext context,
  WidgetRef ref, [
  CountyArticle? existing,
]) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _ArticleEditorDialog(existing: existing),
  );
}

class _ArticleEditorDialog extends ConsumerStatefulWidget {
  const _ArticleEditorDialog({this.existing});
  final CountyArticle? existing;

  @override
  ConsumerState<_ArticleEditorDialog> createState() =>
      _ArticleEditorDialogState();
}

class _ArticleEditorDialogState extends ConsumerState<_ArticleEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _author;
  late final TextEditingController _category;
  String? _pdfPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _author = TextEditingController(text: e?.author ?? '');
    _category = TextEditingController(text: e?.category ?? 'general');
    _pdfPath = e?.pdfLocalPath;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _author.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _pdfPath = path);
  }

  Future<void> _save() async {
    final user = ref.read(authUserProvider);
    if (user == null || !user.isAdmin) return;
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    setState(() => _saving = true);
    try {
      final media = ref.read(countyMediaServiceProvider);
      var pdfPath = _pdfPath;
      if (pdfPath != null && pdfPath != widget.existing?.pdfLocalPath) {
        pdfPath = await media.persistPickedFile(
          sourcePath: pdfPath,
          subfolder: 'county_articles',
          fileName: pdfPath.split(RegExp(r'[/\\]')).last,
        );
      }

      final article = widget.existing == null
          ? CountyArticle.create(
              title: title,
              content: content,
              createdBy: user.id,
              author: _author.text.trim().isEmpty ? null : _author.text.trim(),
              pdfLocalPath: pdfPath,
              category: _category.text.trim().isEmpty
                  ? null
                  : _category.text.trim(),
            )
          : widget.existing!.copyWith(
              title: title,
              content: content,
              author: _author.text.trim().isEmpty ? null : _author.text.trim(),
              pdfLocalPath: pdfPath,
              category: _category.text.trim().isEmpty
                  ? null
                  : _category.text.trim(),
              updatedAt: DateTime.now().toUtc(),
              clearAuthor: _author.text.trim().isEmpty,
            );

      await media.upsertArticle(article);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: Text(
        widget.existing == null ? 'Add Article' : 'Edit Article',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _content,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: _dec('Content'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _author,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Author (optional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _category,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Category'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _pdfPath != null
                          ? 'PDF: ${_pdfPath!.split(RegExp(r"[/\\\\]")).last}'
                          : 'No PDF selected',
                      style: TextStyle(
                        color: _pdfPath != null
                            ? Colors.green.shade300
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _pickPdf,
                    child: const Text('Upload PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        CancelButton(
          onPressed: () => Navigator.pop(context, false),
          text: 'Cancel',
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.existing == null ? 'Publish' : 'Save'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
      );
}
