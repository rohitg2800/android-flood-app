// lib/services/media_service.dart
// OpsFlood — Module 6: Media, Image Attachments & Export
//
// fix (2026-06-13): `import 'package:flutter/material.dart'` was placed after
// the class declaration for MediaService (line 157) — Dart forbids directives
// after declarations. Moved all imports to the top of the file. Also removed
// the local `typedef Uint8List = List<int>` that shadowed dart:typed_data and
// replaced it with a proper import.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ── MediaFile result type ─────────────────────────────────────────────────────

class MediaFile {
  final String path;
  Uint8List? bytes;
  final double sizeKb;
  final String name;

  MediaFile({
    required this.path,
    required this.sizeKb,
    required this.name,
    this.bytes,
  });

  File get file => File(path);

  Future<Uint8List> loadBytes() async {
    bytes ??= await file.readAsBytes();
    return bytes!;
  }
}

// ── MediaService ──────────────────────────────────────────────────────────────

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  final _picker = ImagePicker();

  Future<MediaFile?> pickImageFromCamera({
    int quality = 75,
    double? maxWidth,
    double? maxHeight,
  }) async {
    final xFile = await _picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: quality,
      maxWidth:     maxWidth,
      maxHeight:    maxHeight,
    );
    return _toMediaFile(xFile);
  }

  Future<MediaFile?> pickImageFromGallery({
    int quality = 75,
    double? maxWidth,
    double? maxHeight,
  }) async {
    final xFile = await _picker.pickImage(
      source:       ImageSource.gallery,
      imageQuality: quality,
      maxWidth:     maxWidth,
      maxHeight:    maxHeight,
    );
    return _toMediaFile(xFile);
  }

  Future<List<MediaFile>> pickMultipleImages({
    int quality = 70,
    int limit   = 3,
  }) async {
    final xFiles = await _picker.pickMultiImage(
      imageQuality: quality,
      limit:        limit,
    );
    final results = <MediaFile>[];
    for (final x in xFiles) {
      final mf = await _toMediaFile(x);
      if (mf != null) results.add(mf);
    }
    return results;
  }

  Future<MediaFile?> pickWithChooser(
    BuildContext context, {
    int quality = 75,
  }) async {
    MediaFile? result;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaChooserSheet(
        onCamera: () async {
          Navigator.of(context).pop();
          result = await pickImageFromCamera(quality: quality);
        },
        onGallery: () async {
          Navigator.of(context).pop();
          result = await pickImageFromGallery(quality: quality);
        },
      ),
    );
    return result;
  }

  Future<MediaFile?> _toMediaFile(XFile? xFile) async {
    if (xFile == null) return null;
    final file  = File(xFile.path);
    final bytes = await file.readAsBytes();
    final sizeKb = bytes.length / 1024.0;
    return MediaFile(
      path:   xFile.path,
      name:   xFile.name,
      sizeKb: sizeKb,
      bytes:  bytes,
    );
  }
}

// ── _MediaChooserSheet ────────────────────────────────────────────────────────

class _MediaChooserSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _MediaChooserSheet(
      {required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: Colors.white70),
            title: const Text('Take Photo',
                style: TextStyle(color: Colors.white)),
            onTap: onCamera,
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: Colors.white70),
            title: const Text('Choose from Gallery',
                style: TextStyle(color: Colors.white)),
            onTap: onGallery,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
