import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../venues/domain/listing_template.dart';
import '../../../venues/domain/venue.dart';

Future<ListingTemplateConfig?> showListingTemplateEditor({
  required BuildContext context,
  required VenueCategory category,
}) {
  return showDialog<ListingTemplateConfig>(
    context: context,
    builder: (dialogContext) {
      return _ListingTemplateEditorDialog(category: category);
    },
  );
}

class _ListingTemplateEditorDialog extends StatefulWidget {
  const _ListingTemplateEditorDialog({required this.category});

  final VenueCategory category;

  @override
  State<_ListingTemplateEditorDialog> createState() =>
      _ListingTemplateEditorDialogState();
}

class _ListingTemplateEditorDialogState
    extends State<_ListingTemplateEditorDialog> {
  late ListingTemplateConfig _config;
  late final TextEditingController _ctaBook;
  late final TextEditingController _ctaAvailability;
  late final TextEditingController _accent;
  ListingPreviewDevice _device = ListingPreviewDevice.mobile;
  late List<ListingFilterGroup> _filterGroups;
  late List<String> _specKeys;

  @override
  void initState() {
    super.initState();
    _config = widget.category.listingTemplate;
    _filterGroups = _config.filterGroups;
    _specKeys = _config.specKeys;
    _ctaBook = TextEditingController(text: _config.ctaBook);
    _ctaAvailability = TextEditingController(text: _config.ctaAvailability);
    _accent = TextEditingController(text: _config.accentColor ?? '');
  }

  @override
  void dispose() {
    _ctaBook.dispose();
    _ctaAvailability.dispose();
    _accent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return AlertDialog(
      title: Text('Listing template · ${widget.category.name}'),
      content: SizedBox(
        width: wide ? 720 : 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _config.templateId,
                decoration: const InputDecoration(labelText: 'Template'),
                items: ListingTemplateConfig.templateIds
                    .map(
                      (id) => DropdownMenuItem(value: id, child: Text(id)),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _config =
                        ListingTemplateConfig.defaultsFor(slug: id).copyWith(
                      published: _config.published,
                      ctaBook: _ctaBook.text,
                      ctaAvailability: _ctaAvailability.text,
                    );
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text(
                  'Draft categories stay hidden on customer discovery.',
                ),
                value: _config.published,
                onChanged: (value) => setState(
                    () => _config = _config.copyWith(published: value)),
              ),
              TextField(
                controller: _ctaBook,
                decoration: const InputDecoration(labelText: 'Book CTA'),
              ),
              TextField(
                controller: _ctaAvailability,
                decoration:
                    const InputDecoration(labelText: 'Availability CTA'),
              ),
              TextField(
                controller: _accent,
                decoration: const InputDecoration(
                  labelText: 'Accent color',
                  hintText: '#8B5CF6',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Required / optional fields',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ..._config.fields.map((field) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(field.label),
                  subtitle: Text(
                    '${field.type.name}${field.required ? ' · required' : ''}',
                  ),
                  value: field.isActive,
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(
                        fields: _config.fields
                            .map(
                              (item) => item.key == field.key
                                  ? item.copyWith(isActive: value ?? true)
                                  : item,
                            )
                            .toList(),
                      );
                    });
                  },
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Filter groups',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _FilterGroupsEditor(
                initialFilterGroups: _filterGroups,
                onFilterGroupsChanged: (value) =>
                    setState(() => _filterGroups = value),
              ),
              const SizedBox(height: 16),
              Text(
                'Key specifications (sections)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _SpecKeysEditor(
                initialSpecKeys: _specKeys,
                onSpecKeysChanged: (value) => setState(() => _specKeys = value),
              ),
              const SizedBox(height: 16),
              Text(
                'Layout preview (wireframe)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<ListingPreviewDevice>(
                segments: const [
                  ButtonSegment(
                    value: ListingPreviewDevice.mobile,
                    icon: Icon(Icons.smartphone_rounded),
                    label: Text('Mobile'),
                  ),
                  ButtonSegment(
                    value: ListingPreviewDevice.tablet,
                    icon: Icon(Icons.tablet_rounded),
                    label: Text('Tablet'),
                  ),
                  ButtonSegment(
                    value: ListingPreviewDevice.desktop,
                    icon: Icon(Icons.desktop_windows_rounded),
                    label: Text('Desktop'),
                  ),
                ],
                selected: {_device},
                onSelectionChanged: (selection) =>
                    setState(() => _device = selection.first),
              ),
              const SizedBox(height: 8),
              ListingTemplatePreview(
                config: _effectiveConfig,
                categoryName: widget.category.name,
                device: _device,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _config.copyWith(
                ctaBook: _ctaBook.text.trim().isEmpty
                    ? _config.ctaBook
                    : _ctaBook.text.trim(),
                ctaAvailability: _ctaAvailability.text.trim().isEmpty
                    ? _config.ctaAvailability
                    : _ctaAvailability.text.trim(),
                accentColor:
                    _accent.text.trim().isEmpty ? null : _accent.text.trim(),
                clearAccent: _accent.text.trim().isEmpty,
                filterGroups: _filterGroups,
                specKeys: _specKeys,
              ),
            );
          },
          child: const Text('Save template'),
        ),
      ],
    );
  }

  /// Live config including unsaved CTA text, filter groups and spec keys
  /// so the preview reflects all edits.
  ListingTemplateConfig get _effectiveConfig => _config.copyWith(
        ctaBook: _ctaBook.text.trim().isEmpty ? _config.ctaBook : _ctaBook.text,
        ctaAvailability: _ctaAvailability.text.trim().isEmpty
            ? _config.ctaAvailability
            : _ctaAvailability.text,
        accentColor: _accent.text.trim().isEmpty ? null : _accent.text.trim(),
        clearAccent: _accent.text.trim().isEmpty,
        filterGroups: _filterGroups,
        specKeys: _specKeys,
      );
}

/// Which device frame the admin template preview renders.
enum ListingPreviewDevice { mobile, tablet, desktop }

/// Wireframe of the unified listing detail for the given template config.
///
/// Renders structure only: hero placeholder, badges, field chips from the
/// config, and CTA labels. It never fakes listing data such as prices or
/// ratings — placeholders are neutral bars.
class ListingTemplatePreview extends StatelessWidget {
  const ListingTemplatePreview({
    super.key,
    required this.config,
    required this.categoryName,
    required this.device,
  });

  final ListingTemplateConfig config;
  final String categoryName;
  final ListingPreviewDevice device;

  Size get designSize => switch (device) {
        ListingPreviewDevice.mobile => const Size(320, 440),
        ListingPreviewDevice.tablet => const Size(720, 340),
        ListingPreviewDevice.desktop => const Size(1024, 310),
      };

  bool get _twoColumn => device != ListingPreviewDevice.mobile;

  Color _accent(BuildContext context) {
    final hex = config.accentColor;
    if (hex != null && hex.length >= 7 && hex.startsWith('#')) {
      final value = int.tryParse(hex.substring(1, 7), radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return AppTheme.violet;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent(context);
    final bookCta = config.ctaBook;
    final availabilityCta = config.ctaAvailability;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: designSize.width,
          height: designSize.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero band with category + discount badge placeholders.
              Container(
                height: 64,
                color: accent.withValues(alpha: 0.82),
                padding: const EdgeInsets.all(10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _BadgePlaceholder(
                            label: 'Category',
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 6),
                          const _BadgePlaceholder(
                            label: '% OFF',
                            color: Color(0xFFB45309),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _twoColumn
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _WireContent(
                              config: config,
                              accent: accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: device == ListingPreviewDevice.desktop
                                ? 240
                                : 200,
                            child: _WireSummary(
                              config: config,
                              bookCta: bookCta,
                              availabilityCta: availabilityCta,
                              accent: accent,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WireContent(config: config, accent: accent),
                          const SizedBox(height: 10),
                          _WireSummary(
                            config: config,
                            bookCta: bookCta,
                            availabilityCta: availabilityCta,
                            accent: accent,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgePlaceholder extends StatelessWidget {
  const _BadgePlaceholder({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WireContent extends StatelessWidget {
  const _WireContent({required this.config, required this.accent});

  final ListingTemplateConfig config;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + rating placeholder bars.
        Container(
          height: 14,
          width: 150,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final field in config.activeFields.take(4))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  field.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WireSummary extends StatelessWidget {
  const _WireSummary({
    required this.config,
    required this.bookCta,
    required this.availabilityCta,
    required this.accent,
  });

  final ListingTemplateConfig config;
  final String bookCta;
  final String availabilityCta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Price placeholder bar.
          Container(
            height: 12,
            width: 70,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          _WireButton(label: availabilityCta, filled: false, accent: accent),
          const SizedBox(height: 6),
          _WireButton(label: bookCta, filled: true, accent: accent),
          if (config.showCall || config.showChat) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (config.showCall)
                  Expanded(
                    child: _WireButton(
                      label: config.ctaCall,
                      filled: false,
                      accent: accent,
                      icon: Icons.call_rounded,
                    ),
                  ),
                if (config.showCall && config.showChat)
                  const SizedBox(width: 6),
                if (config.showChat)
                  Expanded(
                    child: _WireButton(
                      label: config.ctaChat,
                      filled: false,
                      accent: accent,
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WireButton extends StatelessWidget {
  const _WireButton({
    required this.label,
    required this.filled,
    required this.accent,
    this.icon,
  });

  final String label;
  final bool filled;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: filled ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: filled ? accent : accent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: filled ? Colors.white : accent),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterGroupsEditor extends StatefulWidget {
  const _FilterGroupsEditor({
    required this.initialFilterGroups,
    required this.onFilterGroupsChanged,
  });

  final List<ListingFilterGroup> initialFilterGroups;
  final ValueChanged<List<ListingFilterGroup>> onFilterGroupsChanged;

  @override
  State<_FilterGroupsEditor> createState() => _FilterGroupsEditorState();
}

class _FilterGroupsEditorState extends State<_FilterGroupsEditor> {
  late List<ListingFilterGroup> _filterGroups;

  @override
  void initState() {
    super.initState();
    _filterGroups = widget.initialFilterGroups;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter groups',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ..._filterGroups.asMap().entries.map((entry) {
          final group = entry.value;
          return _FilterGroupEditor(
            group: group,
            onChanged: (value) => setState(() {
              _filterGroups = _filterGroups
                  .asMap()
                  .entries
                  .map((e) => e.key == entry.key ? value : e.value)
                  .toList();
              widget.onFilterGroupsChanged(_filterGroups);
            }),
          );
        }),
        const SizedBox(height: 8),
        _AddFilterGroupButton(
          onPressed: () => setState(() {
            _filterGroups = _filterGroups +
                [
                  ListingFilterGroup(
                    id: 'filter-${(widget.initialFilterGroups.length + 1)}',
                    label: 'New filter',
                    type: ListingFilterType.options,
                    options: ['Option 1', 'Option 2'],
                  ),
                ];
            widget.onFilterGroupsChanged(_filterGroups);
          }),
        ),
      ],
    );
  }
}

class _FilterGroupEditor extends StatelessWidget {
  const _FilterGroupEditor({
    required this.group,
    required this.onChanged,
  });

  final ListingFilterGroup group;
  final ValueChanged<ListingFilterGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: TextEditingController(text: group.id),
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'ID',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) => onChanged(ListingFilterGroup(
              id: value.trim(),
              label: group.label,
              type: group.type,
              options: group.options,
            )),
          ),
          TextField(
            controller: TextEditingController(text: group.label),
            decoration: InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) => onChanged(ListingFilterGroup(
              id: group.id,
              label: value.trim(),
              type: group.type,
              options: group.options,
            )),
          ),
          DropdownButtonFormField<String>(
            initialValue: group.type.name,
            decoration: InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              DropdownMenuItem(value: 'options', child: Text('Options')),
              DropdownMenuItem(value: 'range', child: Text('Range')),
              DropdownMenuItem(value: 'toggle', child: Text('Toggle')),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged(ListingFilterGroup(
                id: group.id,
                label: group.label,
                type:
                    ListingFilterType.values.firstWhere((t) => t.name == value),
                options: group.options,
              ));
            },
          ),
          TextField(
            controller: TextEditingController(text: group.options.join(', ')),
            textAlign: TextAlign.left,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Options',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              onChanged(ListingFilterGroup(
                id: group.id,
                label: group.label,
                type: group.type,
                options: value
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(),
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _SpecKeysEditor extends StatefulWidget {
  const _SpecKeysEditor({
    required this.initialSpecKeys,
    required this.onSpecKeysChanged,
  });

  final List<String> initialSpecKeys;
  final ValueChanged<List<String>> onSpecKeysChanged;

  @override
  State<_SpecKeysEditor> createState() => _SpecKeysEditorState();
}

class _SpecKeysEditorState extends State<_SpecKeysEditor> {
  late List<String> _specKeys;

  @override
  void initState() {
    super.initState();
    _specKeys = widget.initialSpecKeys;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key specifications (sections)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ..._specKeys.where((key) => key.isNotEmpty).map((key) {
          return _SpecKeyEditor(
            specKey: key,
            onChanged: (value) => setState(() {
              _specKeys = _specKeys.map((k) => k == key ? value : k).toList();
              widget.onSpecKeysChanged(_specKeys);
            }),
          );
        }),
        const SizedBox(height: 8),
        _AddSpecKeyButton(
          onPressed: () => setState(() {
            _specKeys =
                _specKeys + ['spec-${(widget.initialSpecKeys.length + 1)}'];
            widget.onSpecKeysChanged(_specKeys);
          }),
        ),
      ],
    );
  }
}

class _SpecKeyEditor extends StatelessWidget {
  const _SpecKeyEditor({
    required this.specKey,
    required this.onChanged,
  });

  final String specKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(text: specKey),
            decoration: InputDecoration(
              labelText: 'Key',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) =>
                onChanged(value.trim().isNotEmpty ? value.trim() : specKey),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete, size: 20),
          tooltip: 'Remove key',
          onPressed: () => onChanged(''),
        ),
      ],
    );
  }
}

class _AddFilterGroupButton extends StatelessWidget {
  const _AddFilterGroupButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: const Text('Add filter group'),
    );
  }
}

class _AddSpecKeyButton extends StatelessWidget {
  const _AddSpecKeyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: const Text('Add specification'),
    );
  }
}
