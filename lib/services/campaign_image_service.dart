// lib/services/campaign_image_service.dart
//
// Handles campaign image upload to Firebase Storage
// + admin_campaigns_screen changes to add image picking

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ── Service ───────────────────────────────────────────────────────────────────
class CampaignImageService {
  static final _storage = FirebaseStorage.instance;
  static final _picker  = ImagePicker();

  // ── Pick image (gallery or camera) ───────────────────────────────────────
  static Future<XFile?> pickImage({bool fromCamera = false}) async {
    return await _picker.pickImage(
      source:    fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth:  1200,
      maxHeight: 800,
      imageQuality: 85,
    );
  }

  // ── Upload to Firebase Storage → return download URL ─────────────────────
  static Future<String?> uploadCampaignImage({
    required XFile   imageFile,
    required String  campaignId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref  = _storage.ref('campaign_images/$campaignId.jpg');
      UploadTask task;

      if (kIsWeb) {
        // Web: use bytes
        final bytes = await imageFile.readAsBytes();
        task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        // Mobile: use file
        task = ref.putFile(File(imageFile.path),
            SettableMetadata(contentType: 'image/jpeg'));
      }

      // Track upload progress
      task.snapshotEvents.listen((snap) {
        final progress = snap.bytesTransferred / snap.totalBytes;
        onProgress?.call(progress);
      });

      final snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  // ── Delete campaign image ─────────────────────────────────────────────────
  static Future<void> deleteCampaignImage(String campaignId) async {
    try {
      await _storage.ref('campaign_images/$campaignId.jpg').delete();
    } catch (_) {} // Ignore if file doesn't exist
  }
}

// ── Reusable image picker widget ──────────────────────────────────────────────
class CampaignImagePicker extends StatefulWidget {
  final String?    currentImageUrl;
  final Function(XFile? file, String? url) onImageSelected;

  const CampaignImagePicker({
    super.key,
    this.currentImageUrl,
    required this.onImageSelected,
  });

  @override
  State<CampaignImagePicker> createState() => _CampaignImagePickerState();
}

class _CampaignImagePickerState extends State<CampaignImagePicker> {
  XFile?  _selectedFile;
  Uint8List? _previewBytes;
  bool   _uploading = false;
  double _progress  = 0;

  static const _navy = Color(0xFF1B2263);
  static const _gold = Color(0xFFF5A800);

  Future<void> _pick({bool camera = false}) async {
    final file = await CampaignImageService.pickImage(fromCamera: camera);
    if (file == null) return;
    _selectedFile  = file;
    _previewBytes  = await file.readAsBytes();
    setState(() {});
    widget.onImageSelected(file, null);
  }

  void _remove() {
    setState(() { _selectedFile = null; _previewBytes = null; });
    widget.onImageSelected(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _previewBytes != null || widget.currentImageUrl != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Campaign Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _showPickOptions(context),
        child: Container(
          width: double.infinity, height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasImage ? _navy.withAlpha(60) : Colors.grey.shade300, width: 1.5),
          ),
          child: hasImage ? _imagePreview() : _placeholder(),
        ),
      ),
      if (_uploading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _progress, color: _navy, backgroundColor: Colors.grey[200]),
        Text('Uploading... ${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    ]);
  }

  Widget _imagePreview() {
    return Stack(fit: StackFit.expand, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _previewBytes != null
            ? Image.memory(_previewBytes!, fit: BoxFit.cover)
            : CachedNetworkImage(imageUrl: widget.currentImageUrl!, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey)),
      ),
      // Overlay buttons
      Positioned(top: 8, right: 8, child: Row(children: [
        _overlayBtn(Icons.edit, () => _showPickOptions(context)),
        const SizedBox(width: 6),
        _overlayBtn(Icons.delete, _remove, color: Colors.red),
      ])),
    ]);
  }

  Widget _overlayBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withAlpha(120), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18)));
  }

  Widget _placeholder() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey[400]),
      const SizedBox(height: 8),
      Text('Tap to add campaign image', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      const SizedBox(height: 4),
      Text('Recommended: 1200 × 800px', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
    ]);
  }

  void _showPickOptions(BuildContext context) {
    showModalBottomSheet(context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Select Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _optionBtn(Icons.photo_library, 'Gallery', () { Navigator.pop(context); _pick(); })),
                const SizedBox(width: 12),
                if (!kIsWeb) Expanded(child: _optionBtn(Icons.camera_alt, 'Camera', () { Navigator.pop(context); _pick(camera: true); })),
              ]),
            ])));
  }

  Widget _optionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F2F8), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: Column(children: [
              Icon(icon, color: _navy, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: _navy)),
            ])));
  }
}

// ── Campaign image display widget (for campaign cards/detail) ─────────────────
class CampaignImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final BorderRadius? borderRadius;

  const CampaignImageWidget({
    super.key,
    this.imageUrl,
    this.height = 180,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(12);
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
          height: height,
          decoration: BoxDecoration(
              color: const Color(0xFF1B2263).withAlpha(15),
              borderRadius: br),
          child: const Center(child: Icon(Icons.campaign, size: 48, color: Color(0xFF1B2263))));
    }
    return ClipRRect(
        borderRadius: br,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          height:   height,
          width:    double.infinity,
          fit:      BoxFit.cover,
          placeholder: (_, __) => Container(height: height, color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B2263)))),
          errorWidget: (_, __, ___) => Container(height: height,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: br),
              child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey))),
        ));
  }
}