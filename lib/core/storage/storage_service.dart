import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exceptions.dart';

/// The kind of media being uploaded. Determines allowed extensions and the
/// maximum byte size, so an admin can never upload an unexpected file type or
/// an oversized asset through the education (or any) upload surface.
enum UploadKind {
  image(
    maxBytes: 8 * 1024 * 1024,
    extensions: {'jpg', 'jpeg', 'png', 'webp', 'gif'},
  ),
  video(
    maxBytes: 100 * 1024 * 1024,
    extensions: {'mp4', 'mov', 'webm', 'm4v'},
  ),
  document(
    maxBytes: 15 * 1024 * 1024,
    extensions: {'pdf', 'doc', 'docx', 'txt'},
  );

  const UploadKind({required this.maxBytes, required this.extensions});

  final int maxBytes;
  final Set<String> extensions;

  String get label => switch (this) {
        UploadKind.image => 'image',
        UploadKind.video => 'video',
        UploadKind.document => 'document',
      };
}

/// Outcome of a validated upload: the storage [path] and a resolvable [url].
class UploadedFile {
  const UploadedFile({required this.path, required this.url});

  final String path;
  final String url;
}

/// Shared Supabase Storage helper for education and other media uploads.
///
/// Centralizes file-type/size validation, path generation, public vs. signed
/// URL resolution and error mapping so every upload surface behaves the same
/// and never hardcodes a URL. Callers drive progress/retry UI; this service is
/// a single attempt that either returns an [UploadedFile] or throws an
/// [AppException]-mapped error.
class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  /// Default education media bucket. Private buckets resolve through signed
  /// URLs; pass [publicBucket] false for access-controlled assets.
  static const String educationBucket = 'education-media';

  String _extension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '';
    return filename
        .substring(dot + 1)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Validates and uploads [bytes] under [folder]/[entityId]. Returns the stored
  /// path and a URL (public or time-limited signed for private buckets).
  Future<UploadedFile> upload({
    required UploadKind kind,
    required List<int> bytes,
    required String filename,
    required String folder,
    required String entityId,
    String bucket = educationBucket,
    bool publicBucket = true,
    Duration signedUrlTtl = const Duration(hours: 1),
  }) async {
    final extension = _extension(filename);
    if (!kind.extensions.contains(extension)) {
      throw BusinessException(
        'Unsupported ${kind.label} type. Allowed: '
        '${kind.extensions.join(', ')}.',
        code: 'unsupported_file_type',
      );
    }
    if (bytes.length > kind.maxBytes) {
      final limitMb = (kind.maxBytes / (1024 * 1024)).round();
      throw BusinessException(
        'File is too large. Maximum size is ${limitMb}MB.',
        code: 'file_too_large',
      );
    }
    if (bytes.isEmpty) {
      throw const BusinessException(
        'The selected file is empty.',
        code: 'empty_file',
      );
    }

    final path =
        '$folder/$entityId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: false,
            ),
          );
      final url = publicBucket
          ? _client.storage.from(bucket).getPublicUrl(path)
          : await _client.storage
              .from(bucket)
              .createSignedUrl(path, signedUrlTtl.inSeconds);
      return UploadedFile(path: path, url: url);
    } on StorageException catch (e) {
      throw mapError(e);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Removes a previously uploaded object. Safe to call with an empty path.
  Future<void> remove({
    required String path,
    String bucket = educationBucket,
  }) async {
    if (path.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw mapError(e);
    }
  }

  String _contentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'm4v' => 'video/x-m4v',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }
}
