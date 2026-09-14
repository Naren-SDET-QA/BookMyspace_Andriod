import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/cms_media_asset.dart';
import '../domain/cms_media_ref.dart';
import '../domain/cms_media_repository.dart';

class SupabaseCmsMediaRepository implements CmsMediaRepository {
  SupabaseCmsMediaRepository(this._client);
  final SupabaseClient _client;

  StorageFileApi get _storage => _client.storage.from(CmsMediaRules.bucket);

  @override
  Future<List<CmsMediaAsset>> list({String query = '', int limit = 100}) async {
    final boundedLimit = limit.clamp(1, 500);
    try {
      final files = await _storage.list(
        path: CmsMediaRules.namespace,
        searchOptions: SearchOptions(limit: boundedLimit),
      );
      final needle = query.trim().toLowerCase();
      return files
          .where((file) => CmsMediaRules.isManagedPath(
              '${CmsMediaRules.namespace}/${file.name}'))
          .where((file) =>
              needle.isEmpty || file.name.toLowerCase().contains(needle))
          .map((file) {
            final path = '${CmsMediaRules.namespace}/${file.name}';
            final metadata = file.metadata ?? const <String, dynamic>{};
            return CmsMediaAsset(
              ref: CmsMediaRef(
                path: path,
                url: _storage.getPublicUrl(path),
              ),
              name: file.name,
              sizeBytes: (metadata['size'] as num?)?.toInt() ?? 0,
              contentType: metadata['mimetype'] as String? ?? '',
              createdAt: DateTime.tryParse(file.createdAt ?? ''),
            );
          })
          .where((asset) => asset.isImage)
          .toList();
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<CmsMediaAsset> upload(
      {required String name, required List<int> bytes}) async {
    final problem = CmsMediaRules.validateFile(name: name, bytes: bytes.length);
    if (problem != null) throw ArgumentError(problem);
    final extension = name.substring(name.lastIndexOf('.') + 1);
    final path = CmsMediaRules.objectPath(
      fileName: name,
      stamp: DateTime.now().microsecondsSinceEpoch,
    );
    try {
      await _storage.uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          contentType: _contentType(extension),
          upsert: false,
        ),
      );
      return CmsMediaAsset(
        ref: CmsMediaRef(path: path, url: _storage.getPublicUrl(path)),
        name: path.substring(CmsMediaRules.namespace.length + 1),
        sizeBytes: bytes.length,
        contentType: _contentType(extension),
      );
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> delete(CmsMediaAsset asset) async {
    final path = asset.ref.path;
    if (!CmsMediaRules.isManagedPath(path)) {
      throw ArgumentError('This media item is not managed by the CMS library.');
    }
    try {
      await _storage.remove([path]);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  String _contentType(String extension) =>
      switch (CmsMediaRules.normalizeExtension(extension)) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
}
