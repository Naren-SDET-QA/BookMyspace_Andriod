import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Path, size and content-type rules for admin-uploaded Home artwork.
///
/// Kept free of any network call so the rules that decide *where* an upload
/// lands and *what* may be uploaded can be tested without a backend.
class HomeMediaPath {
  const HomeMediaPath._();

  /// Deliberately reused rather than adding a bucket.
  ///
  /// This bucket already grants public read and gates every write through
  /// `private.is_category_manager()`, which is administrator /
  /// super_administrator only. Home artwork needs exactly those rules, so
  /// introducing a second bucket would duplicate the policy surface — and a
  /// mis-scoped storage policy is precisely how media buckets leak.
  static const String bucket = 'category-media';

  static const int maxBytes = 10 * 1024 * 1024;

  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];

  static String normalizeExtension(String extension) =>
      extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool isAllowedExtension(String extension) =>
      allowedExtensions.contains(normalizeExtension(extension));

  static String contentType(String extension) {
    return switch (normalizeExtension(extension)) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  /// Home artwork is namespaced under `home/` so it can never collide with the
  /// category and subsection media that share this bucket.
  ///
  /// The block id is stripped to `[a-z0-9_]` and the extension falls back to
  /// `jpg` unless it is an allowed image type, so no caller can write a
  /// traversing path or a non-image object into a publicly readable bucket.
  static String objectPath({
    required String blockKindId,
    required String extension,
    required int stamp,
  }) {
    final safeKind =
        blockKindId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final candidate = normalizeExtension(extension);
    final safeExtension = isAllowedExtension(candidate) ? candidate : 'jpg';
    return 'home/${safeKind.isEmpty ? 'block' : safeKind}/'
        '$stamp.$safeExtension';
  }
}

/// Uploads admin artwork for Home blocks.
///
/// Uploads only — removal is intentionally not automatic. A stored object may
/// be referenced by more than one block, so dropping a chip from the layout
/// must not destroy a file another block still points at.
class HomeMediaRepository {
  HomeMediaRepository(this._client);

  final SupabaseClient _client;

  /// Uploads [bytes] and returns the public URL to store in the block config.
  ///
  /// Throws on failure: the admin must never be told an image was added when
  /// the backend rejected it.
  Future<String> uploadArtwork({
    required String blockKindId,
    required List<int> bytes,
    required String extension,
  }) async {
    final path = HomeMediaPath.objectPath(
      blockKindId: blockKindId,
      extension: extension,
      stamp: DateTime.now().microsecondsSinceEpoch,
    );
    final storage = _client.storage.from(HomeMediaPath.bucket);
    await storage.uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(
        contentType: HomeMediaPath.contentType(extension),
        upsert: false,
      ),
    );
    return storage.getPublicUrl(path);
  }
}
