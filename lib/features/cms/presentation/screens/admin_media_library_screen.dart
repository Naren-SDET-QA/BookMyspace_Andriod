import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cms_media_asset.dart';
import '../../domain/cms_media_ref.dart';
import '../cms_media_providers.dart';

/// Admin-only media browser for the existing category-media bucket.
///
/// The screen returns a [CmsMediaRef] when [onAssign] is provided. Callers
/// store only that reference in their existing CMS document.
class AdminMediaLibraryScreen extends ConsumerStatefulWidget {
  const AdminMediaLibraryScreen({super.key, this.onAssign});
  final ValueChanged<CmsMediaRef>? onAssign;

  @override
  ConsumerState<AdminMediaLibraryScreen> createState() =>
      _AdminMediaLibraryScreenState();
}

class _AdminMediaLibraryScreenState
    extends ConsumerState<AdminMediaLibraryScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _uploading = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: CmsMediaRules.allowedExtensions.toList(),
      withData: true,
    );
    if (result == null || result.files.single.bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref.read(cmsMediaRepositoryProvider).upload(
            name: result.files.single.name,
            bytes: result.files.single.bytes!,
          );
      ref.invalidate(cmsMediaAssetsProvider(_query));
      _message('Image uploaded.');
    } catch (error) {
      _message('Upload failed. Your file was not added. Check it and retry.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(CmsMediaAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete image?'),
        content: const Text(
          'Existing CMS assignments keep their fallback artwork. Delete only if this image is no longer needed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(cmsMediaRepositoryProvider).delete(asset);
      ref.invalidate(cmsMediaAssetsProvider(_query));
      _message('Image deleted.');
    } catch (_) {
      _message(
          'Delete failed. The image is still available. Retry when connected.');
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(cmsMediaAssetsProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media library'),
        actions: [
          IconButton(
            tooltip: 'Upload image',
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Search images',
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.filter_list),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        Expanded(
          child: assets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Could not load images.'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(cmsMediaAssetsProvider(_query)),
                  child: const Text('Retry'),
                ),
              ]),
            ),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text(
                        'No images found. Upload a JPG, PNG, WEBP, or GIF.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 250,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _MediaTile(
                      asset: items[index],
                      onAssign: widget.onAssign == null
                          ? null
                          : () => widget.onAssign!(items[index].ref),
                      onDelete: () => _delete(items[index]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile(
      {required this.asset, this.onAssign, required this.onDelete});
  final CmsMediaAsset asset;
  final VoidCallback? onAssign;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Image.network(
              asset.ref.url,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, error, stack) => const Center(
                  child: Icon(Icons.image_not_supported_outlined, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
            child:
                Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Row(children: [
            if (onAssign != null)
              Expanded(
                  child: TextButton(
                      onPressed: onAssign, child: const Text('Use'))),
            IconButton(
                tooltip: 'Delete ${asset.name}',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline)),
          ]),
        ]),
      );
}
