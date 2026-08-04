import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/county_video.dart';
import '../../providers/providers.dart';
import '../../services/web_media_pick_stub.dart'
    if (dart.library.html) '../../services/web_media_pick_web.dart'
    as web_pick;
import '../../widgets/standard_buttons.dart';

/// Member-facing Videos tab.
///
/// // NEW ADDITION - Delete this file to revert Videos tab UI.
class VideosContentScreen extends ConsumerWidget {
  const VideosContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(activeVideosProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final strings = ref.watch(appStringsProvider);

    return ColoredBox(
      color: Colors.black,
      child: videosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '${strings.errorLabel}: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (videos) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.countyVideos,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      AddButton(
                        onPressed: () async {
                          final ok = await showVideoEditorDialog(context, ref);
                          if (ok == true) {
                            ref.invalidate(activeVideosProvider);
                          }
                        },
                        text: strings.addVideo,
                        icon: Icons.add,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: videos.isEmpty
                    ? Center(
                        child: Text(
                          strings.noVideos,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cross = constraints.maxWidth > 900
                              ? 3
                              : constraints.maxWidth > 560
                              ? 2
                              : 1;
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            cacheExtent: 400,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 16 / 10,
                                ),
                            itemCount: videos.length,
                            itemBuilder: (context, index) {
                              final video = videos[index];
                              return _VideoCard(
                                video: video,
                                isAdmin: isAdmin,
                                onChanged: () =>
                                    ref.invalidate(activeVideosProvider),
                              );
                            },
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

class _VideoCard extends ConsumerWidget {
  const _VideoCard({
    required this.video,
    required this.isAdmin,
    required this.onChanged,
  });

  final CountyVideo video;
  final bool isAdmin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ImageProvider? thumb;
    if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty) {
      thumb = NetworkImage(video.thumbnailUrl!);
    }

    return GestureDetector(
      onTap: () async {
        final path = kIsWeb || video.videoLocalPath.isEmpty
            ? video.videoUrl
            : video.videoLocalPath;
        if (path == null || path.isEmpty) return;
        final uri = Uri.tryParse(path);
        if (kIsWeb) {
          await launchUrl(
            uri != null && uri.hasScheme ? uri : Uri.base.resolve(path),
            mode: LaunchMode.externalApplication,
          );
        } else if (uri != null && uri.hasScheme) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await OpenFile.open(path);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade700),
          image: thumb != null
              ? DecorationImage(image: thumb, fit: BoxFit.cover)
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (video.duration != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    video.duration!,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            if (isAdmin)
              Positioned(
                top: 4,
                left: 4,
                child: Row(
                  children: [
                    _miniBtn(Icons.edit, Colors.blue, () async {
                      final ok = await showVideoEditorDialog(
                        context,
                        ref,
                        video,
                      );
                      if (ok == true) onChanged();
                    }),
                    _miniBtn(Icons.delete_outline, Colors.red, () async {
                      await ref
                          .read(countyMediaServiceProvider)
                          .softDeleteVideo(video.id);
                      onChanged();
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

Future<bool?> showVideoEditorDialog(
  BuildContext context,
  WidgetRef ref, [
  CountyVideo? existing,
]) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _VideoEditorDialog(existing: existing),
  );
}

class _VideoEditorDialog extends ConsumerStatefulWidget {
  const _VideoEditorDialog({this.existing});
  final CountyVideo? existing;

  @override
  ConsumerState<_VideoEditorDialog> createState() => _VideoEditorDialogState();
}

class _VideoEditorDialogState extends ConsumerState<_VideoEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  String? _videoPath;
  String? _thumbPath;
  PlatformFile? _pickedVideo;
  PlatformFile? _pickedThumb;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _duration = TextEditingController(text: e?.duration ?? '');
    _videoPath = e == null
        ? null
        : (e.videoLocalPath.isNotEmpty ? e.videoLocalPath : e.videoUrl);
    _thumbPath = e?.thumbnailLocalPath ?? e?.thumbnailUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        final picked = await web_pick.pickMediaBytesWeb(accept: 'video/*');
        if (picked == null) return;
        final file = PlatformFile(
          name: picked.name,
          size: picked.bytes.length,
          bytes: picked.bytes,
        );
        setState(() {
          _pickedVideo = file;
          _videoPath = file.name;
        });
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: false,
      );
      if (result == null) return;
      final file = result.files.single;
      setState(() {
        _pickedVideo = file;
        _videoPath = file.path;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _pickThumb() async {
    try {
      if (kIsWeb) {
        final picked = await web_pick.pickMediaBytesWeb(accept: 'image/*');
        if (picked == null) return;
        final file = PlatformFile(
          name: picked.name,
          size: picked.bytes.length,
          bytes: picked.bytes,
        );
        setState(() {
          _pickedThumb = file;
          _thumbPath = file.name;
        });
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: false,
      );
      if (result == null) return;
      final file = result.files.single;
      setState(() {
        _pickedThumb = file;
        _thumbPath = file.path;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _save() async {
    final user = ref.read(authUserProvider);
    if (user == null || !user.isAdmin) {
      _showError('Only an administrator can publish videos.');
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      _showError('Enter a video title.');
      return;
    }
    if (_videoPath == null || _videoPath!.isEmpty) {
      _showError('Choose a video before publishing.');
      return;
    }

    setState(() => _saving = true);
    try {
      final media = ref.read(countyMediaServiceProvider);
      var videoPath = widget.existing?.videoLocalPath ?? '';
      var videoUrl = widget.existing?.videoUrl;
      if (kIsWeb && _pickedVideo != null) {
        videoUrl = await media.uploadPickedBytes(
          bytes: _pickedVideo!.bytes!,
          subfolder: 'county_videos',
          fileName: _pickedVideo!.name,
          contentType: _contentType(_pickedVideo!.extension, video: true),
        );
        videoPath = '';
      } else if (_pickedVideo?.path != null) {
        videoPath = await media.persistPickedFile(
          sourcePath: _pickedVideo!.path!,
          subfolder: 'county_videos',
          fileName: _pickedVideo!.name,
        );
      }
      String? thumbPath = widget.existing?.thumbnailLocalPath;
      var thumbUrl = widget.existing?.thumbnailUrl;
      if (kIsWeb && _pickedThumb != null) {
        thumbUrl = await media.uploadPickedBytes(
          bytes: _pickedThumb!.bytes!,
          subfolder: 'county_videos/thumbs',
          fileName: _pickedThumb!.name,
          contentType: _contentType(_pickedThumb!.extension),
        );
        thumbPath = null;
      } else if (_pickedThumb?.path != null) {
        thumbPath = await media.persistPickedFile(
          sourcePath: _pickedThumb!.path!,
          subfolder: 'county_videos/thumbs',
          fileName: _pickedThumb!.name,
        );
      }

      final video = widget.existing == null
          ? CountyVideo.create(
              title: title,
              description: _description.text.trim(),
              videoLocalPath: videoPath,
              videoUrl: videoUrl,
              uploadedBy: user.id,
              thumbnailLocalPath: thumbPath,
              thumbnailUrl: thumbUrl,
              duration: _duration.text.trim().isEmpty
                  ? null
                  : _duration.text.trim(),
            )
          : widget.existing!.copyWith(
              title: title,
              description: _description.text.trim(),
              videoLocalPath: videoPath,
              videoUrl: videoUrl,
              thumbnailLocalPath: thumbPath,
              thumbnailUrl: thumbUrl,
              duration: _duration.text.trim().isEmpty
                  ? null
                  : _duration.text.trim(),
              clearDuration: _duration.text.trim().isEmpty,
              clearThumbnail: thumbPath == null && thumbUrl == null,
            );

      await media.upsertVideo(video);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _contentType(String? extension, {bool video = false}) {
    final ext = extension?.toLowerCase();
    if (video) {
      return switch (ext) {
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'avi' => 'video/x-msvideo',
        'mkv' => 'video/x-matroska',
        _ => 'video/mp4',
      };
    }
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error.toString().replaceFirst(
      RegExp(r'^(Exception|Bad state): '),
      '',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: Text(
        widget.existing == null ? 'Add Video' : 'Edit Video',
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
                decoration: _dec('Video Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: _dec('Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _duration,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Duration (e.g. 3:45)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _videoPath != null
                          ? 'Video: ${_videoPath!.split(RegExp(r"[/\\\\]")).last}'
                          : 'No video selected',
                      style: TextStyle(
                        color: _videoPath != null
                            ? Colors.green.shade300
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  AddButton(onPressed: _pickVideo, text: 'Upload Video'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _thumbPath != null
                          ? 'Thumb: ${_thumbPath!.split(RegExp(r"[/\\\\]")).last}'
                          : 'No thumbnail',
                      style: TextStyle(
                        color: _thumbPath != null
                            ? Colors.green.shade300
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  AddButton(onPressed: _pickThumb, text: 'Thumbnail'),
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
        SaveButton(
          onPressed: _saving ? null : _save,
          text: widget.existing == null ? 'Publish' : 'Save',
          isLoading: _saving,
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
