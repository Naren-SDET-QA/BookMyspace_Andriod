import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/home_appearance.dart';
import '../home_appearance_providers.dart';

/// Admin editor for the customer Home composition.
///
/// Admins choose which blocks appear, their order, titles, artwork and paint
/// (background, border, glow). Writes go through the plug-and-play flag
/// repository, so a save reaches iOS, Android and web without a new build.
class AdminHomeAppearanceScreen extends ConsumerStatefulWidget {
  const AdminHomeAppearanceScreen({super.key});

  @override
  ConsumerState<AdminHomeAppearanceScreen> createState() =>
      _AdminHomeAppearanceScreenState();
}

class _AdminHomeAppearanceScreenState
    extends ConsumerState<AdminHomeAppearanceScreen> {
  /// Curated gradients so admins get attractive results without colour theory.
  static const _presets = <String, List<Color>>{
    'Brand': [Color(0xFF008F7A), Color(0xFF38BDF8)],
    'Sunset': [Color(0xFFF97316), Color(0xFFDB2777)],
    'Violet': [Color(0xFF7C3AED), Color(0xFF2563EB)],
    'Midnight': [Color(0xFF0F172A), Color(0xFF1E3A8A)],
    'Emerald': [Color(0xFF047857), Color(0xFF22D3EE)],
    'Rose': [Color(0xFFE11D48), Color(0xFFF59E0B)],
  };

  HomeAppearance? _draft;
  bool _saving = false;

  HomeAppearance _current(HomeAppearance source) => _draft ?? source;

  void _update(HomeBlockConfig block) {
    final HomeAppearance base = _draft ?? ref.read(homeAppearanceProvider);
    setState(() => _draft = base.copyWithBlock(block));
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(homeAppearanceControllerProvider).save(draft);
      if (!mounted) return;
      setState(() => _draft = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home layout published')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = _current(ref.watch(homeAppearanceProvider));
    final blocks = [...appearance.blocks]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home layout'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _draft = HomeAppearance.defaults),
            child: const Text('Reset'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving || _draft == null ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Choose which blocks appear on customer Home, in what order, and '
            'how each one is painted. Disabled blocks disappear instantly on '
            'every platform.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < blocks.length; i++)
            _BlockEditor(
              key: ValueKey(blocks[i].kind),
              block: blocks[i],
              isFirst: i == 0,
              isLast: i == blocks.length - 1,
              presets: _presets,
              onChanged: _update,
              onMove: (delta) => _reorder(blocks, i, delta),
            ),
        ],
      ),
    );
  }

  void _reorder(List<HomeBlockConfig> ordered, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return;
    final a = ordered[index];
    final b = ordered[target];
    _update(a.copyWith(order: b.order));
    _update(b.copyWith(order: a.order));
  }
}

class _BlockEditor extends StatelessWidget {
  const _BlockEditor({
    super.key,
    required this.block,
    required this.isFirst,
    required this.isLast,
    required this.presets,
    required this.onChanged,
    required this.onMove,
  });

  final HomeBlockConfig block;
  final bool isFirst;
  final bool isLast;
  final Map<String, List<Color>> presets;
  final ValueChanged<HomeBlockConfig> onChanged;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    block.kind.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: isFirst ? null : () => onMove(-1),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: isLast ? null : () => onMove(1),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                Switch(
                  value: block.enabled,
                  onChanged: (value) =>
                      onChanged(block.copyWith(enabled: value)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: block.title,
              decoration: const InputDecoration(
                labelText: 'Section title (optional)',
                isDense: true,
              ),
              onChanged: (value) => onChanged(block.copyWith(title: value)),
            ),
            const SizedBox(height: 12),
            Text('Background', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in presets.entries)
                  _Swatch(
                    label: entry.key,
                    colors: entry.value,
                    selected: _matches(block.style.backgroundColors,
                        entry.value),
                    onTap: () => onChanged(
                      block.copyWith(
                        style: block.style
                            .copyWith(backgroundColors: entry.value),
                      ),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.format_color_reset, size: 16),
                  label: const Text('Default'),
                  onPressed: () => onChanged(
                    block.copyWith(
                      style: block.style.copyWith(backgroundColors: const []),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Border highlight',
                      style: theme.textTheme.labelLarge),
                ),
                Switch(
                  value: block.style.borderWidth > 0,
                  onChanged: (value) => onChanged(
                    block.copyWith(
                      style: block.style.copyWith(
                        borderWidth: value ? 1.4 : 0,
                        borderColor: value ? const Color(0x66FFFFFF) : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Glow', style: theme.textTheme.labelLarge),
                ),
                Switch(
                  value: block.style.glow,
                  onChanged: (value) => onChanged(
                    block.copyWith(style: block.style.copyWith(glow: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ImageListEditor(
              images: block.images,
              onChanged: (images) => onChanged(block.copyWith(images: images)),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ImageListEditor extends StatefulWidget {
  const _ImageListEditor({required this.images, required this.onChanged});

  final List<String> images;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ImageListEditor> createState() => _ImageListEditorState();
}

class _ImageListEditorState extends State<_ImageListEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    widget.onChanged([...widget.images, url]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artwork (${widget.images.length}) — 4-6 images look best',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        if (widget.images.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                InputChip(
                  label: Text(
                    widget.images[i].split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: () {
                    final next = [...widget.images]..removeAt(i);
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'https://…/image.jpg',
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Add image',
              onPressed: _add,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
