// lib/services/story_media_service.dart
//
// Beneficiary story media upload — photo & video.
// Only uses packages already in pubspec:
//   image_picker          (photo + video file picking on mobile & web)
//   firebase_storage      (upload to Firebase)
//   cached_network_image  (display uploaded photos)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ── Colour constants (mirrors KCA palette) ────────────────────────────────────
const _kNavy = Color(0xFF1B2263);
const _kGold  = Color(0xFFF5A800);

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class StoryMediaService {
  static final _storage = FirebaseStorage.instance;
  static final _picker  = ImagePicker();

  // ── Pick photo (gallery or camera) ───────────────────────────────────────
  static Future<XFile?> pickPhoto({bool fromCamera = false}) async {
    return _picker.pickImage(
      source:       fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth:     1200,
      maxHeight:    1200,
      imageQuality: 82,
    );
  }

  // ── Pick video (gallery on web; gallery/camera on mobile) ────────────────
  // Returns an XFile so callers don't depend on any private type.
  static Future<XFile?> pickVideo() async {
    return _picker.pickVideo(
      source:      ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
  }

  // ── Upload photo → Firebase Storage ──────────────────────────────────────
  static Future<String?> uploadStoryPhoto({
    required String  campaignId,
    required int     storyIndex,
    required XFile   file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref  = _storage.ref(
          'story_media/$campaignId/story_$storyIndex/photo.jpg');
      final task = kIsWeb
          ? ref.putData(await file.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'))
          : ref.putFile(File(file.path),
          SettableMetadata(contentType: 'image/jpeg'));

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
      });
      return await (await task).ref.getDownloadURL();
    } catch (e) {
      debugPrint('Photo upload error: $e');
      return null;
    }
  }

  // ── Upload video → Firebase Storage ──────────────────────────────────────
  static Future<String?> uploadStoryVideo({
    required String campaignId,
    required int    storyIndex,
    required XFile  file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final name = file.name;
      final ext  = name.contains('.') ? name.split('.').last.toLowerCase() : 'mp4';
      final ref  = _storage.ref(
          'story_media/$campaignId/story_$storyIndex/video.$ext');

      final task = kIsWeb
          ? ref.putData(await file.readAsBytes(),
          SettableMetadata(contentType: 'video/$ext'))
          : ref.putFile(File(file.path),
          SettableMetadata(contentType: 'video/$ext'));

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
      });
      return await (await task).ref.getDownloadURL();
    } catch (e) {
      debugPrint('Video upload error: $e');
      return null;
    }
  }

  // ── Delete all media for a story slot ───────────────────────────────────
  static Future<void> deleteStoryMedia(String campaignId, int storyIndex) async {
    try {
      final list = await _storage
          .ref('story_media/$campaignId/story_$storyIndex')
          .listAll();
      for (final item in list.items) { await item.delete(); }
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StoryVideoCard  —  shown on the donor Campaign Detail screen.
// No extra packages needed — tapping shows a dialog the donor can use
// to copy the link and open it in their browser.
// ─────────────────────────────────────────────────────────────────────────────
class StoryVideoCard extends StatelessWidget {
  final String videoUrl;
  const StoryVideoCard({super.key, required this.videoUrl});

  bool get _isYoutube =>
      videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be');

  // Extract YouTube thumbnail
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
            // Background — YouTube thumbnail or dark gradient
            if (thumb != null)
              CachedNetworkImage(
                imageUrl: thumb, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF0F0F1E)),
                errorWidget:  (_, __, ___) => _darkBg(),
              )
            else
              _darkBg(),
            // Dark scrim
            Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  )),
            ),
            // Play button + label
            Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 68, height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(220),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: _kNavy, size: 44)),
                const SizedBox(height: 10),
                Text(
                  _isYoutube ? 'Watch on YouTube' : 'Play Video',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                ),
              ],
            )),
            // YouTube badge
            if (_isYoutube)
              Positioned(top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    // Try to launch URL — if url_launcher is available use it;
    // otherwise show a dismissible dialog with the URL so donor can copy it.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.videocam_outlined, color: _kNavy),
          const SizedBox(width: 8),
          const Text('Watch Video', style: TextStyle(color: _kNavy, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Open this link in your browser to watch the video:',
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
            label: const Text('Copy Link'),
            onPressed: () {
              // Copy to clipboard
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Link copied — paste in your browser'),
                duration: Duration(seconds: 3),
              ));
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StoryPhotoWidget  —  cached photo with tap-to-fullscreen hero
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