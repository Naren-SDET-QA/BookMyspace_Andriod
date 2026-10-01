import 'package:flutter/foundation.dart';

import 'cms_media_ref.dart';

/// A metadata-only entry in the existing `category-media` Storage bucket.
@immutable
class CmsMediaAsset {
  const CmsMediaAsset({
    required this.ref,
    required this.name,
    this.sizeBytes = 0,
    this.contentType = '',
    this.createdAt,
  });

  final CmsMediaRef ref;
  final String name;
  final int sizeBytes;
  final String contentType;
  final DateTime? createdAt;

  bool get isImage =>
      contentType.startsWith('image/') ||
      CmsMediaRules.isAllowedExtension(name.split('.').last);

  CmsMediaAsset copyWith({String? name, int? sizeBytes, String? contentType}) =>
      CmsMediaAsset(
        ref: ref,
        name: name ?? this.name,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        contentType: contentType ?? this.contentType,
        createdAt: createdAt,
      );
}

/// Shared client-side constraints. Storage policies remain authoritative.
class CmsMediaRules {
  const CmsMediaRules._();

  static const bucket = 'category-media';
  static const namespace = 'cms';
  static const maxBytes = 10 * 1024 * 1024;
  static const allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif'
  };

  static String normalizeExtension(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool isAllowedExtension(String value) =>
      allowedExtensions.contains(normalizeExtension(value));

  static String? validateFile({required String name, required int bytes}) {
    if (bytes <= 0) return 'Choose an image file.';
    if (bytes > maxBytes) return 'Images must be 10 MB or smaller.';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || !isAllowedExtension(name.substring(dot + 1))) {
      return 'Use JPG, PNG, WEBP, or GIF images.';
    }
    return null;
  }

  static String safeName(String name) {
    final raw = name.split(RegExp(r'[\\/]')).last;
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? 'image.jpg' : cleaned;
  }

  static String objectPath({required String fileName, required int stamp}) =>
      '$namespace/$stamp-${safeName(fileName)}';

  static bool isManagedPath(String path) =>
      path.startsWith('$namespace/') &&
      !path.contains('..') &&
      !path.startsWith('/') &&
      path.length > namespace.length + 1;
}
