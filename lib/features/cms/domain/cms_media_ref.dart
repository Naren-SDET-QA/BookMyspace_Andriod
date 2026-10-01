import 'package:flutter/foundation.dart';

/// A reference to one piece of admin-managed media.
///
/// Stores both halves the app already keeps for category artwork:
///
/// * [url]  - what the widget loads. For Supabase Storage this is the public
///            URL produced by `getPublicUrl`.
/// * [path] - the object path inside the bucket (`home/category_matrix/...`).
///            Kept because a URL cannot be turned back into an object path
///            reliably, and a later media library needs the path to show
///            what is referenced, to de-duplicate uploads, and to avoid
///            deleting an object another object still points at.
///
/// This mirrors `venue_categories.image_url` / `image_path`, so a category
/// row and a CMS document describe media the same way.
///
/// Only `http`/`https` URLs are accepted. Anything else — a `javascript:`
/// URL, a `file:` path, a half-typed string — is dropped at parse time and
/// the reference reads as [isEmpty], so a bad value renders the built-in
/// artwork instead of reaching an image loader.
@immutable
class CmsMediaRef {
  const CmsMediaRef({this.url = '', this.path = ''});

  final String url;
  final String path;

  static const CmsMediaRef none = CmsMediaRef();

  bool get isEmpty => url.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// True when [value] is a well-formed absolute http(s) URL.
  static bool isUsableUrl(Object? value) {
    if (value is! String) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// Reads either a bare URL string or `{"url": ..., "path": ...}`.
  ///
  /// Returns [none] for anything unusable rather than throwing.
  factory CmsMediaRef.fromJson(Object? json) {
    if (json is String) {
      return isUsableUrl(json) ? CmsMediaRef(url: json.trim()) : none;
    }
    if (json is! Map) return none;
    final rawUrl = json['url'];
    if (!isUsableUrl(rawUrl)) return none;
    final rawPath = json['path'];
    return CmsMediaRef(
      url: (rawUrl as String).trim(),
      path: rawPath is String ? rawPath.trim() : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (path.isNotEmpty) 'path': path,
      };

  @override
  bool operator ==(Object other) =>
      other is CmsMediaRef && other.url == url && other.path == path;

  @override
  int get hashCode => Object.hash(url, path);

  @override
  String toString() => 'CmsMediaRef(url: $url, path: $path)';
}
