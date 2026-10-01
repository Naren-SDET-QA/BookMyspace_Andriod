import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../venue_sections/presentation/venue_section_providers.dart';
import '../../domain/catalog_content.dart';
import '../../domain/catalog_validation.dart';
import '../../domain/cms_icon.dart';
import '../../domain/cms_localized_text.dart';
import '../../domain/cms_media_ref.dart';
import '../catalog_content_providers.dart';
import '../owner_facility_controller.dart';
import '../widgets/capability_render.dart';

/// A local working copy is kept for the lifetime of this route. Network
/// failures never replace it with a provider refresh or an empty fallback.
class OwnerFacilityBuilderScreen extends ConsumerStatefulWidget {
  const OwnerFacilityBuilderScreen(
      {super.key, required this.venueId, required this.venueName});
  final String venueId;
  final String venueName;
  @override
  ConsumerState<OwnerFacilityBuilderScreen> createState() =>
      _OwnerFacilityBuilderScreenState();
}

class _OwnerFacilityBuilderScreenState
    extends ConsumerState<OwnerFacilityBuilderScreen> {
  late final OwnerFacilityController _editor;
  int _step = 0;
  String? _facilityKey;
  String? _sectionKey;
  bool _allowExit = false;
  String? _notice;
  bool _lastPublish = false;
  static const _steps = [
    'Facility types',
    'Sections',
    'Subsections',
    'Preview'
  ];

  @override
  void initState() {
    super.initState();
    _editor = OwnerFacilityController(
        ref.read(venueSectionRepositoryProvider), widget.venueId);
    _editor.addListener(_refresh);
    _editor.load();
  }

  void _refresh() {
    if (mounted)
      setState(() {
        if (_editor.dirty) _notice = null;
      });
  }

  @override
  void dispose() {
    _editor.removeListener(_refresh);
    _editor.dispose();
    super.dispose();
  }

  CatalogFacilityType? get _facility =>
      _editor.content.facilityTypeFor(_facilityKey ?? '') ??
      _editor.content.facilityTypes.firstOrNull;
  CatalogSection? get _section =>
      _facility?.sections.where((s) => s.key == _sectionKey).firstOrNull ??
      _facility?.sections.firstOrNull;

  Future<void> _leave() async {
    if (_editor.busy) return;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Leave without saving?'),
              content: const Text(
                  'Your unsaved changes will be lost. Stay here to save your draft.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard and leave'))
              ],
            ));
    if (discard == true && mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _save({bool publish = false}) async {
    if (publish) {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Publish venue sections?'),
                content: const Text(
                    'This saves your facility draft and publishes ALL current section drafts for this venue, including edits made in the section manager. The server checks your publishing access.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Publish all sections'))
                ],
              ));
      if (accepted != true || !mounted) return;
    }
    _lastPublish = publish;
    final success = publish ? await _editor.publish() : await _editor.save();
    if (!mounted) return;
    if (success) {
      ref.invalidate(ownerVenueSectionsProvider(widget.venueId));
      if (publish)
        ref.invalidate(publishedVenueSectionsProvider(widget.venueId));
      setState(() =>
          _notice = publish ? 'Venue sections published.' : 'Draft saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit || (!_editor.dirty && !_editor.busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Facility builder')),
        body: !_editor.loaded
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _editor.busy
                        ? const CircularProgressIndicator()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_editor.error ?? ''),
                            TextButton(
                                onPressed: _editor.load,
                                child: const Text('Retry'))
                          ])))
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(children: [
                      if (_editor.busy) const LinearProgressIndicator(),
                      Expanded(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(widget.venueName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 8),
                                  Text(_editor.dirty
                                      ? 'Unsaved changes'
                                      : 'Draft • Only published content is visible to customers'),
                                  if (_notice != null)
                                    Semantics(
                                        liveRegion: true,
                                        child: Text(_notice!)),
                                  const SizedBox(height: 16),
                                  Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: List.generate(
                                          4,
                                          (i) => ChoiceChip(
                                                label: Text(
                                                    '${i + 1}. ${_steps[i]}'),
                                                selected: _step == i,
                                                onSelected: _editor.busy
                                                    ? null
                                                    : (_) => setState(
                                                        () => _step = i),
                                              ))),
                                  const SizedBox(height: 20),
                                  if (_editor.error != null)
                                    Card(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer,
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(children: [
                                              Semantics(
                                                  liveRegion: true,
                                                  child: Text(_editor.error!)),
                                              TextButton(
                                                  onPressed: _editor.busy
                                                      ? null
                                                      : () => _save(
                                                          publish:
                                                              _lastPublish),
                                                  child: const Text('Retry')),
                                            ]))),
                                  AbsorbPointer(
                                      absorbing: _editor.busy, child: _body()),
                                ],
                              ))),
                      SafeArea(
                          top: false,
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (_step > 0)
                                    TextButton(
                                        onPressed: _editor.busy
                                            ? null
                                            : () => setState(() => _step--),
                                        child: const Text('Back')),
                                  if (_step < 3)
                                    OutlinedButton(
                                        onPressed: _editor.busy
                                            ? null
                                            : () => setState(() => _step++),
                                        child: const Text('Next')),
                                  FilledButton(
                                      onPressed:
                                          _editor.busy ? null : () => _save(),
                                      child: const Text('Save draft')),
                                  if (_step == 3)
                                    FilledButton.tonal(
                                        onPressed: _editor.busy
                                            ? null
                                            : () => _save(publish: true),
                                        child: const Text('Publish')),
                                ],
                              ))),
                    ]))),
      ),
    );
  }

  Widget _body() {
    if (_step == 3) return _preview();
    final facility = _facility;
    final section = _section;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(_steps[_step], style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      // The facility is already selected when editing its sections. Keeping
      // this selector on step 2 only avoids pushing section actions below the
      // phone viewport while retaining explicit selection for subsections.
      if (_step > 1 && facility != null)
        DropdownButtonFormField<String>(
          initialValue: facility.key,
          decoration: const InputDecoration(labelText: 'Facility type'),
          items: [
            for (final f in _editor.content.facilityTypes)
              DropdownMenuItem(value: f.key, child: Text(f.title.base))
          ],
          onChanged: (key) => setState(() {
            _facilityKey = key;
            _sectionKey = null;
          }),
        ),
      if (_step == 2 && section != null)
        DropdownButtonFormField<String>(
          key: ValueKey(facility!.key),
          initialValue: section.key,
          decoration: const InputDecoration(labelText: 'Section'),
          items: [
            for (final s in facility.sections)
              DropdownMenuItem(value: s.key, child: Text(s.title.base))
          ],
          onChanged: (key) => setState(() => _sectionKey = key),
        ),
      const SizedBox(height: 12),
      if (_step == 0) ...[
        for (final f in _editor.content.facilityTypes)
          _row(f, _editor.content.facilityTypes),
        OutlinedButton.icon(
            onPressed: () => _editNode(),
            icon: const Icon(Icons.add),
            label: const Text('Add facility type')),
      ] else if (facility == null)
        const Text('Add a facility type in step 1 first.')
      else if (_step == 1) ...[
        for (final s in facility.sections) _row(s, facility.sections),
        OutlinedButton.icon(
            onPressed: () => _editNode(),
            icon: const Icon(Icons.add),
            label: const Text('Add section')),
      ] else if (section == null)
        const Text('Add a section in step 2 first.')
      else ...[
        for (final sub in section.subsections) _row(sub, section.subsections),
        OutlinedButton.icon(
            onPressed: () => _editNode(),
            icon: const Icon(Icons.add),
            label: const Text('Add subsection')),
      ],
    ]);
  }

  Widget _row(CatalogNode node, List<CatalogNode> siblings) {
    final index = siblings.indexOf(node);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(CmsIcon.resolve(node.iconId)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(node.title.base,
                            style: Theme.of(context).textTheme.titleMedium))
                  ]),
                  if (node.description.isNotEmpty) Text(node.description.base),
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        TextButton(
                            onPressed: () => _editNode(node),
                            child: const Text('Edit')),
                        IconButton(
                            tooltip: 'Move ${node.title.base} up',
                            onPressed: index == 0
                                ? null
                                : () => _move(siblings, index, -1),
                            icon: const Icon(Icons.arrow_upward)),
                        IconButton(
                            tooltip: 'Move ${node.title.base} down',
                            onPressed: index == siblings.length - 1
                                ? null
                                : () => _move(siblings, index, 1),
                            icon: const Icon(Icons.arrow_downward)),
                        IconButton(
                            tooltip: 'Delete ${node.title.base}',
                            onPressed: () => _delete(node),
                            icon: const Icon(Icons.delete_outline)),
                        Switch(
                            value: node.enabled,
                            onChanged: (value) =>
                                _replace(node, enabled: value)),
                        Text(node.enabled ? 'Enabled' : 'Disabled'),
                      ]),
                ])));
  }

  void _move(List<CatalogNode> nodes, int index, int delta) {
    final moved = [...nodes];
    moved.insert(index + delta, moved.removeAt(index));
    var content = _editor.content;
    for (var i = 0; i < moved.length; i++) {
      final n = moved[i];
      if (n is CatalogFacilityType)
        content = content.upsertFacilityType(n.copyWith(order: i));
      if (n is CatalogSection)
        content = content.upsertSection(_facility!.key, n.copyWith(order: i));
      if (n is CatalogSubsection)
        content = content.upsertSubsection(
            _facility!.key, _section!.key, n.copyWith(order: i));
    }
    // The same order is used by the editing list and the published preview.
    content = CatalogContent([
      for (final f in content.facilityTypes)
        f.copyWith(sections: [
          for (final s
              in (f.sections.toList()
                ..sort((a, b) => a.order.compareTo(b.order))))
            s.copyWith(
                subsections: s.subsections.toList()
                  ..sort((a, b) => a.order.compareTo(b.order)))
        ])
    ]..sort((a, b) => a.order.compareTo(b.order)));
    _editor.edit(content);
  }

  /// Removes a node from the working copy only. Nothing reaches the server
  /// until the owner saves a draft or publishes, so a mistaken delete is
  /// recoverable by leaving without saving.
  Future<void> _delete(CatalogNode node) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Delete "${node.title.base}"?'),
              content: const Text(
                  'This removes it from your draft. Customers are not affected until you publish.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    var content = _editor.content;
    if (node is CatalogFacilityType) {
      content = content.removeFacilityType(node.key);
    } else if (node is CatalogSection) {
      content = content.removeSection(_facility!.key, node.key);
    } else if (node is CatalogSubsection) {
      content =
          content.removeSubsection(_facility!.key, _section!.key, node.key);
    }
    // Drop any pointer that now names a node which no longer exists, so the
    // wizard falls back to the first remaining entry instead of a dead key.
    if (_facilityKey == node.key) _facilityKey = null;
    if (_sectionKey == node.key) _sectionKey = null;
    _editor.edit(content);
  }

  void _replace(CatalogNode node, {bool? enabled}) {
    var content = _editor.content;
    if (node is CatalogFacilityType)
      content = content.upsertFacilityType(node.copyWith(enabled: enabled));
    if (node is CatalogSection)
      content = content.upsertSection(
          _facility!.key, node.copyWith(enabled: enabled));
    if (node is CatalogSubsection)
      content = content.upsertSubsection(
          _facility!.key, _section!.key, node.copyWith(enabled: enabled));
    _editor.edit(content);
  }

  Future<void> _editNode([CatalogNode? node]) async {
    final result = await showDialog<_NodeFields>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _NodeDialog(node: node));
    if (result == null || !mounted) return;
    final key = node?.key ?? 'owner-${const Uuid().v4()}';
    final title = CmsLocalizedText(
        base: result.name, overrides: node?.title.overrides ?? const {});
    final description = CmsLocalizedText(
        base: result.description,
        overrides: node?.description.overrides ?? const {});
    var content = _editor.content;
    if (_step == 0) {
      final f = node as CatalogFacilityType? ??
          CatalogFacilityType(key: key, order: content.facilityTypes.length);
      content = content.upsertFacilityType(f.copyWith(
          title: title,
          description: description,
          iconId: result.icon,
          media: result.media));
      _facilityKey = key;
    } else if (_step == 1) {
      final s = node as CatalogSection? ??
          CatalogSection(key: key, order: _facility!.sections.length);
      content = content.upsertSection(
          _facility!.key,
          s.copyWith(
              title: title,
              description: description,
              iconId: result.icon,
              media: result.media));
      _sectionKey = key;
    } else {
      final s = node as CatalogSubsection? ??
          CatalogSubsection(key: key, order: _section!.subsections.length);
      content = content.upsertSubsection(
          _facility!.key,
          _section!.key,
          s.copyWith(
              title: title,
              description: description,
              iconId: result.icon,
              media: result.media));
    }
    _editor.edit(content);
  }

  Widget _preview() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Preview draft', style: Theme.of(context).textTheme.headlineSmall),
        const Text(
            'Only enabled items are shown. Saving a draft does not publish it.'),
        if (_editor.content.visible.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No enabled facilities. Publishing will hide the facility section.')),
        for (final f in _editor.content.visible)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _previewNode(f),
                      for (final s in f.visibleSections)
                        Padding(
                            padding: const EdgeInsets.only(left: 12, top: 12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _previewNode(s),
                                  for (final sub in s.visibleSubsections)
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            left: 12, top: 8),
                                        child: _previewNode(sub)),
                                ])),
                    ],
                  ))),
        const SizedBox(height: 12),
        const Text(
            'The current venue page displays the facility names and descriptions as a text section. Icons and images are saved in the CMS document and shown in this builder preview.'),
      ]);

  Widget _previewNode(CatalogNode node) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(CmsIcon.resolve(node.iconId)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(node.title.base,
                  style: Theme.of(context).textTheme.titleMedium))
        ]),
        if (node.description.isNotEmpty) Text(node.description.base),
        if (node.media.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(node.media.url,
                  height: 120,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (_, error, stack) => const Text(
                      'Image unavailable. Check the image address.'))),
        if (node.capabilities != null && !node.capabilities!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CapabilityRender(
              capabilities: node.capabilities!,
              compact: true,
            ),
          ),
      ]);
}

class _NodeFields {
  const _NodeFields(this.name, this.description, this.icon, this.media);
  final String name;
  final String description;
  final String icon;
  final CmsMediaRef media;
}

class _NodeDialog extends ConsumerStatefulWidget {
  const _NodeDialog({this.node});
  final CatalogNode? node;
  @override
  ConsumerState<_NodeDialog> createState() => _NodeDialogState();
}

class _NodeDialogState extends ConsumerState<_NodeDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.node?.title.base);
  late final TextEditingController _description =
      TextEditingController(text: widget.node?.description.base);
  late final TextEditingController _image =
      TextEditingController(text: widget.node?.media.url);
  late String _icon = widget.node?.iconId ?? 'category';
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.node == null ? 'Add details' : 'Edit details'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Name'),
                          maxLength: 80,
                          validator: CatalogValidator.fieldTitle),
                      TextFormField(
                          controller: _description,
                          decoration: const InputDecoration(
                              labelText: 'Description (optional)'),
                          maxLength: 200,
                          minLines: 2,
                          maxLines: 4,
                          validator: CatalogValidator.fieldDescription),
                      DropdownButtonFormField<String>(
                        initialValue: _icon,
                        decoration: const InputDecoration(labelText: 'Icon'),
                        items: [
                          for (final id in {
                            ...[
                              'category',
                              'hall',
                              'home',
                              'business',
                              'garden',
                              'gym',
                              'turf',
                              'star',
                              'info'
                            ],
                            _icon
                          })
                            DropdownMenuItem(
                                value: id,
                                child: Row(children: [
                                  Icon(CmsIcon.resolve(id)),
                                  const SizedBox(width: 8),
                                  Text(id)
                                ]))
                        ],
                        onChanged: (value) => setState(() => _icon = value!),
                      ),
                      TextFormField(
                          controller: _image,
                          decoration: const InputDecoration(
                              labelText: 'Image address (optional)'),
                          keyboardType: TextInputType.url,
                          validator: CatalogValidator.fieldMediaUrl),
                      TextButton(
                          onPressed: _chooseImage,
                          child: const Text('Choose catalog image')),
                    ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                    context,
                    _NodeFields(
                        _name.text.trim(),
                        _description.text.trim(),
                        _icon,
                        CmsMediaRef(
                            url: _image.text.trim(),
                            path: _image.text.trim() == widget.node?.media.url
                                ? widget.node!.media.path
                                : '')));
              },
              child: const Text('Done'))
        ],
      );

  Future<void> _chooseImage() async {
    final catalog = ref.read(catalogContentProvider);
    final images = <String, CatalogNode>{};
    for (final f in catalog.facilityTypes) {
      for (final n in <CatalogNode>[
        f,
        ...f.sections,
        for (final s in f.sections) ...s.subsections
      ]) {
        if (n.media.isNotEmpty) images[n.media.url] = n;
      }
    }
    final chosen = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
              title: const Text('Choose catalog image'),
              children: [
                if (images.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'No catalog images available. You can enter an image address instead.')),
                for (final entry in images.entries)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, entry.key),
                      child: Text(entry.value.title.base)),
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'))
              ],
            ));
    if (chosen != null && mounted) setState(() => _image.text = chosen);
  }
}
