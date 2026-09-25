import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../course_providers.dart';

/// A single media upload control with pick, validate, progress, retry and
/// replace/remove actions. Wraps the shared [StorageService] so every owner
/// upload surface (demo video, thumbnail, brochure) behaves identically and
/// never hardcodes a URL.
///
/// [onChanged] receives the resolved public URL on success, or an empty string
/// when the asset is removed.
class CourseUploadField extends ConsumerStatefulWidget {
  const CourseUploadField({
    super.key,
    required this.label,
    required this.kind,
    required this.folder,
    required this.entityId,
    required this.onChanged,
    this.initialUrl = '',
    this.icon = Icons.upload_file_rounded,
  });

  final String label;
  final UploadKind kind;
  final String folder;
  final String entityId;
  final ValueChanged<String> onChanged;
  final String initialUrl;
  final IconData icon;

  @override
  ConsumerState<CourseUploadField> createState() => _CourseUploadFieldState();
}

class _CourseUploadFieldState extends ConsumerState<CourseUploadField> {
  bool _busy = false;
  String? _error;
  late String _url = widget.initialUrl;

  Future<void> _pick() async {
    final fileType = switch (widget.kind) {
      UploadKind.image => FileType.image,
      UploadKind.video => FileType.video,
      UploadKind.document => FileType.custom,
    };
    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowMultiple: false,
      withData: true,
      allowedExtensions:
          fileType == FileType.custom ? widget.kind.extensions.toList() : null,
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() => _error = 'The selected file could not be read.');
      return;
    }
    await _upload(file.bytes!, file.name);
  }

  Future<void> _upload(List<int> bytes, String filename) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uploaded = await ref.read(storageServiceProvider).upload(
            kind: widget.kind,
            bytes: bytes,
            filename: filename,
            folder: widget.folder,
            entityId: widget.entityId,
          );
      if (!mounted) return;
      setState(() {
        _url = uploaded.url;
        _busy = false;
      });
      widget.onChanged(uploaded.url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _remove() async {
    setState(() {
      _url = '';
      _error = null;
    });
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = _url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: AppTheme.violet),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_busy)
            const LinearProgressIndicator()
          else if (hasFile)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Uploaded',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _pick,
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: _remove,
                  child: const Text('Remove'),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Choose file'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _pick,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
