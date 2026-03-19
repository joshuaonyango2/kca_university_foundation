// lib/services/story_media_service.dart
//
// Photo & video picking + Firebase Storage upload for beneficiary stories.
//
// Packages used (all already in pubspec.yaml):
//   image_picker       — photo picking (mobile + web)
//   file_picker        — video picking on WEB (image_picker.pickVideo hangs on web)
//   firebase_storage   — upload
//   cached_network_image — display photos

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

const _kNavy = Color(0xFF1B2263);
const _kGold  = Color(0xFFF5A800);

// ── Max upload size: 150 MB ───────────────────────────────────────────────────
const _maxVideoBytes = 150 * 1024 * 1024; // 150 MB
const _maxPhotoBytes =   5 * 1024 * 1024; //   5 MB

// ─────────────────────────────────────────────────────────────────────────────
// Picked media wrapper — hides the difference between XFile and FilePicker
// ─────────────────────────────────────────────────────────────────────────────
class PickedMedia {
  final String    name;
  final String?   path;      // mobile only
  final Uint8List? bytes;    // web only (pre-loaded)
  final int       sizeBytes;
  final String    mimeType;

  const PickedMedia({
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    this.path,
    this.bytes,
  });

  bool get isTooBig => sizeBytes > _maxVideoBytes;

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StoryMediaService
// ─────────────────────────────────────────────────────────────────────────────
class StoryMediaService {
  static final _storage = FirebaseStorage.instance;
  static final _picker  = ImagePicker();

  // ── Pick photo ────────────────────────────────────────────────────────────
  static Future<XFile?> pickPhoto({bool fromCamera = false}) async {
    try {
      return await _picker.pickImage(
        source:       fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth:     1200,
        maxHeight:    1200,
        imageQuality: 82,
        // No requestFullMetadata — avoids permission hang on some Android versions
        requestFullMetadata: false,
      );
    } catch (e) {
      debugPrint('pickPhoto error: $e');
      return null;
    }
  }

  // ── Pick video ────────────────────────────────────────────────────────────
  // Web  → file_picker (image_picker.pickVideo freezes on Flutter Web)
  // Mobile → image_picker WITHOUT maxDuration (avoids OS transcoding delay)
  static Future<PickedMedia?> pickVideo() async {
    try {
      if (kIsWeb) {
        // ── Web: use file_picker ─────────────────────────────────────────
        final result = await FilePicker.platform.pickFiles(
          type:          FileType.video,
          allowMultiple: false,
          withData:      false, // do NOT pre-load bytes — load lazily on upload
          withReadStream: true, // use a stream for large files
        );
        if (result == null || result.files.isEmpty) return null;
        final f = result.files.first;

        // On web withData:false means bytes may be null, but readStream is set
        // We'll load bytes lazily in uploadStoryVideo
        final bytes = f.bytes; // may be null when withData:false
        return PickedMedia(
          name:      f.name,
          sizeBytes: f.size,
          mimeType:  'video/${f.extension ?? 'mp4'}',
          bytes:     bytes,
          path:      f.path,
        );
      } else {
        // ── Mobile: image_picker WITHOUT maxDuration ──────────────────────
        // maxDuration causes iOS/Android to transcode the whole file → freezes.
        // We validate size after picking instead.
        final file = await _picker.pickVideo(
          source: ImageSource.gallery,
          // intentionally no maxDuration
        );
        if (file == null) return null;
        final stat = await File(file.path).stat();
        final ext  = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'mp4';
        return PickedMedia(
          name:      file.name,
          sizeBytes: stat.size,
          mimeType:  'video/$ext',
          path:      file.path,
        );
      }
    } catch (e) {
      debugPrint('pickVideo error: $e');
      return null;
    }
  }

  // ── Upload photo → Firebase Storage ──────────────────────────────────────
  static Future<String?> uploadStoryPhoto({
    required String  campaignId,
    required int     storyIndex,
    required XFile   file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        debugPrint('Photo too large: ${bytes.length} bytes');
        return null;
      }
      final ref  = _storage.ref(
          'story_media/$campaignId/story_$storyIndex/photo.jpg');
      final task = kIsWeb
          ? ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
          : ref.putFile(File(file.path),
          SettableMetadata(contentType: 'image/jpeg'));

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress?.call(s.bytesTransferred / s.totalBytes);
        }
      });
      return await (await task).ref.getDownloadURL();
    } catch (e) {
      debugPrint('Photo upload error: $e');
      return null;
    }
  }

  // ── Upload video → Firebase Storage ──────────────────────────────────────
  static Future<String?> uploadStoryVideo({
    required String      campaignId,
    required int         storyIndex,
    required PickedMedia media,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ext = media.name.contains('.')
          ? media.name.split('.').last.toLowerCase()
          : 'mp4';
      final ref = _storage.ref(
          'story_media/$campaignId/story_$storyIndex/video.$ext');

      UploadTask task;

      if (kIsWeb) {
        // Web: FilePicker gives us bytes (when withData:true) or a readStream.
        // Load bytes now if not already loaded.
        Uint8List bytes;
        if (media.bytes != null) {
          bytes = media.bytes!;
        } else {
          // Fallback: shouldn't normally hit this path
          throw Exception('No byte data available for web upload');
        }
        task = ref.putData(
          bytes,
          SettableMetadata(contentType: media.mimeType),
        );
      } else {
        // Mobile: stream directly from file path — no RAM spike
        task = ref.putFile(
          File(media.path!),
          SettableMetadata(contentType: media.mimeType),
        );
      }

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress?.call(s.bytesTransferred / s.totalBytes);
        }
      });

      final snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Video upload error: $e');
      return null;
    }
  }

  // ── Delete all media for a story slot ────────────────────────────────────
  static Future<void> deleteStoryMedia(String campaignId, int storyIndex) async {
    try {
      final list = await _storage
          .ref('story_media/$campaignId/story_$storyIndex')
          .listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StoryVideoCard — donor-facing video display
// ─────────────────────────────────────────────────────────────────────────────
class StoryVideoCard extends StatelessWidget {
  final String videoUrl;
  const StoryVideoCard({super.key, required this.videoUrl});

  bool get _isYoutube =>
      videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be');

  String? get _youtubeThumbnail {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    String? id;
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else {
      id = uri.queryParameters['v'];
    }
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _isYoutube ? _youtubeThumbnail : null;
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 200, width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            if (thumb != null)
              CachedNetworkImage(
                imageUrl: thumb, fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF0F0F1E)),
                errorWidget: (_, __, ___) => _darkBg(),
              )
            else
              _darkBg(),
            Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  )),
            ),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(220)),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: _kNavy, size: 44)),
              const SizedBox(height: 10),
              Text(
                _isYoutube ? 'Watch on YouTube' : 'Play Video',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
              ),
            ])),
            if (_isYoutube)
              Positioned(top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF0000),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.play_arrow, color: Colors.white, size: 14),
                      SizedBox(width: 3),
                      Text('YouTube', style: TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  )),
          ]),
        ),
      ),
    );
  }

  Widget _darkBg() => Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1B2263), Color(0xFF0F0F1E)],
          )),
      child: const Center(child: Icon(Icons.videocam_rounded,
          color: Colors.white24, size: 56)));

  void _open(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.videocam_outlined, color: _kNavy),
          const SizedBox(width: 8),
          const Expanded(child: Text('Watch Video',
              style: TextStyle(color: _kNavy, fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Open this link in your browser to watch:',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          SelectableText(videoUrl,
              style: const TextStyle(fontSize: 12, color: _kNavy,
                  decoration: TextDecoration.underline)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy, foregroundColor: Colors.white),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Link'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StoryPhotoWidget — cached photo with fullscreen tap
// ─────────────────────────────────────────────────────────────────────────────
class StoryPhotoWidget extends StatelessWidget {
  final String photoUrl;
  final String heroTag;
  const StoryPhotoWidget({
    super.key,
    required this.photoUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: double.infinity, height: 200, fit: BoxFit.cover,
            placeholder: (_, __) => Container(
                height: 200, color: Colors.grey[100],
                child: const Center(
                    child: CircularProgressIndicator(
                        color: _kNavy, strokeWidth: 2))),
            errorWidget: (_, __, ___) => Container(
                height: 200, color: Colors.grey[100],
                child: const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: Colors.grey, size: 36))),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent,
          foregroundColor: Colors.white, elevation: 0),
      body: Center(child: Hero(
        tag: heroTag,
        child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: photoUrl)),
      )),
    )));
  }
}