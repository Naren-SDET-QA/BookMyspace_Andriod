import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/settings_controller.dart';
import '../../domain/catalog_content.dart';
import '../../domain/cms_icon.dart';
import '../../domain/cms_localized_text.dart';
import '../../domain/cms_media_ref.dart';
import '../../domain/catalog_validation.dart';
import '../../domain/facility_capabilities.dart';
import '../catalog_content_providers.dart';
import '../widgets/capability_editor.dart';

/// Languages an admin can translate content into.
///
/// Mirrors `AppLocalizations.supportedLocales`. `''` is the base text used for
/// every language without its own translation.
const Map<String, String> catalogEditorLanguages = <String, String>{
  '': 'Default',
  'en': 'English',
  'te': 'Telugu',
  'hi': 'Hindi',
  'kn': 'Kannada',
  'ta': 'Tamil',
};

/// Which node in the catalogue tree the editor is pointed at.
@immutable
class CatalogSelection {
  const CatalogSelection(this.typeKey, [this.sectionKey, this.subsectionKey]);

  final String typeKey;
  final String? sectionKey;
  final String? subsectionKey;

  bool get isSubsection => subsectionKey != null;
  bool get isSection => sectionKey != null && subsectionKey == null;
  bool get isFacilityType => sectionKey == null;

  /// Stable identity for widget keys, so switching nodes gives text fields a
  /// fresh state instead of carrying the previous node's text across.
  String get path => [typeKey, sectionKey ?? '', subsectionKey ?? ''].join('/');
}

/// Web admin editor for the customer discovery catalogue.
///
/// Facility Type -> Section -> Subsection, backed by the Batch 1 models and
/// published through the existing feature-flag config store. No new table, no
/// second CMS: writes go through [CatalogContentController], which is the same
/// `saveFlag` path `/admin/home-layout` and `/admin/nav-tabs` already use, and
/// inherits the same RLS, validation trigger and audit row.
///
/// ## What an admin can and cannot do
///
/// They can edit wording (per language), pick an icon from the icons compiled
/// into this build, point at an image, reorder, show and hide, and add or
/// delete sections and subsections. They cannot enter code, markup, widgets,
/// arbitrary icons or arbitrary URLs: every field is either a bounded text
/// value rendered through `Text`, a choice from a fixed list, or an
/// `http(s)` URL.
///
/// Ids are set once at creation and never editable afterwards. An id is the
/// stable identity a saved document and live `venue_categories` rows join on,
/// so renaming one would orphan content rather than move it.
///
/// Shipped facility types can be hidden but not deleted:
/// [CatalogContent.fromJson] re-adds any default a payload omits, so a delete
/// would reappear on the next load. Only types an admin created can be
/// removed.
class AdminCatalogScreen extends ConsumerStatefulWidget {
  const AdminCatalogScreen({super.key});

  @override
  ConsumerState<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends ConsumerState<AdminCatalogScreen> {
  CatalogContent? _draft;
  CatalogSelection? _selection;
  String _language = '';
  bool _saving = false;

  /// Desktop threshold. Matches the existing category console so the two admin
  /// screens switch layout at the same width.
  static const double _wideBreakpoint = 1000;

  CatalogContent _current() => _draft ?? ref.read(catalogContentProvider);

  bool get _isDirty => _draft != null;

  void _mutate(CatalogContent Function(CatalogContent) change) {
    setState(() => _draft = change(_current()));
  }

  void _select(CatalogSelection? selection) {
    setState(() => _selection = selection);
  }

  // -------------------------------------------------------------------------
  // Publishing
  // -------------------------------------------------------------------------

  Future<void> _publish() async {
    final draft = _draft;
    if (draft == null) return;

    final issues = CatalogValidator.validate(draft);
    if (issues.any((issue) => issue.isError)) {
      _showIssues(issues);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(catalogContentControllerProvider).save(draft);
      if (!mounted) return;
      setState(() => _draft = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catalogue published')),
      );
    } catch (error) {
      if (!mounted) return;
      // The backend rejected the write. Never clear the draft here: the
      // admin's work must survive a failed publish.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not publish: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    final confirmed = await _confirm(
      title: 'Discard changes?',
      message: 'Your unpublished edits will be lost. What customers currently '
          'see is not affected.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _draft = null;
      _selection = null;
    });
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await _confirm(
      title: 'Restore the built-in catalogue?',
      message: 'This replaces the whole catalogue with the one built into the '
          'app. It is applied to your draft, so nothing changes for customers '
          'until you publish.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _draft = CatalogContent.defaults;
      _selection = null;
    });
  }

  void _showIssues(List<CatalogIssue> issues) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix these before publishing'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final issue in issues)
                ListTile(
                  dense: true,
                  leading: Icon(
                    issue.isError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color: issue.isError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(issue.message),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // -------------------------------------------------------------------------
  // Adding nodes
  // -------------------------------------------------------------------------

  Future<void> _addFacilityType() async {
    final created = await _promptNewNode(
      title: 'New facility type',
      hint: 'for example stays',
    );
    if (created == null) return;
    _mutate((content) => content.upsertFacilityType(
          CatalogFacilityType(
            key: created.key,
            title: CmsLocalizedText(base: created.title),
            order: _nextOrder(content.facilityTypes),
          ),
        ));
    _select(CatalogSelection(created.key));
  }

  Future<void> _addSection(String typeKey) async {
    final created = await _promptNewNode(
      title: 'New section',
      hint: 'for example rooftop_venues',
    );
    if (created == null) return;
    final type = _current().facilityTypeFor(typeKey);
    if (type == null) return;
    _mutate((content) => content.upsertSection(
          typeKey,
          CatalogSection(
            key: created.key,
            title: CmsLocalizedText(base: created.title),
            order: _nextOrder(type.sections),
          ),
        ));
    _select(CatalogSelection(typeKey, created.key));
  }

  Future<void> _addSubsection(String typeKey, String sectionKey) async {
    final created = await _promptNewNode(
      title: 'New subsection',
      hint: 'for example rooftop_lounge',
    );
    if (created == null) return;
    final section = _current().sectionFor(sectionKey);
    if (section == null) return;
    _mutate((content) => content.upsertSubsection(
          typeKey,
          sectionKey,
          CatalogSubsection(
            key: created.key,
            title: CmsLocalizedText(base: created.title),
            order: _nextOrder(section.subsections),
          ),
        ));
    _select(CatalogSelection(typeKey, sectionKey, created.key));
  }

  static int _nextOrder(List<CatalogNode> nodes) {
    var highest = 0;
    for (final node in nodes) {
      if (node.order > highest) highest = node.order;
    }
    return highest + 10;
  }

  Future<_NewNode?> _promptNewNode({
    required String title,
    required String hint,
  }) {
    final formKey = GlobalKey<FormState>();
    var key = '';
    var label = '';
    final existing = _current();

    return showDialog<_NewNode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    helperText: 'What customers will read.',
                  ),
                  validator: CatalogValidator.fieldTitle,
                  onChanged: (value) => label = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Id',
                    helperText: 'Permanent, $hint. Cannot be changed later.',
                  ),
                  validator: (value) => CatalogValidator.fieldKey(
                    value,
                    existing: existing,
                  ),
                  onChanged: (value) => key = value,
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
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(
                context,
                _NewNode(key.trim().toLowerCase(), label.trim()),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(CatalogSelection selection) async {
    final label = selection.isSubsection
        ? 'subsection'
        : selection.isSection
            ? 'section'
            : 'facility type';
    final confirmed = await _confirm(
      title: 'Delete this $label?',
      message: selection.isSection
          ? 'Its subsections are deleted too. Nothing changes for customers '
              'until you publish.'
          : 'Nothing changes for customers until you publish.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    _mutate((content) {
      if (selection.isSubsection) {
        return content.removeSubsection(
          selection.typeKey,
          selection.sectionKey!,
          selection.subsectionKey!,
        );
      }
      if (selection.isSection) {
        return content.removeSection(selection.typeKey, selection.sectionKey!);
      }
      return content.removeFacilityType(selection.typeKey);
    });
    _select(null);
  }

  /// Swaps a node's order with its neighbour, the same approach the bottom-bar
  /// editor uses.
  void _reorder(List<CatalogNode> ordered, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return;
    final a = ordered[index];
    final b = ordered[target];
    _applyOrder(a, b.order);
    _applyOrder(b, a.order);
  }

  void _applyOrder(CatalogNode node, int order) {
    _mutate((content) {
      if (node is CatalogFacilityType) {
        return content.upsertFacilityType(node.copyWith(order: order));
      }
      if (node is CatalogSection) {
        final owner = content.facilityTypeOfSection(node.key);
        if (owner == null) return content;
        return content.upsertSection(owner.key, node.copyWith(order: order));
      }
      if (node is CatalogSubsection) {
        for (final type in content.facilityTypes) {
          for (final section in type.sections) {
            if (section.subsections.any((s) => s.key == node.key)) {
              return content.upsertSubsection(
                type.key,
                section.key,
                node.copyWith(order: order),
              );
            }
          }
        }
      }
      return content;
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final published = ref.watch(catalogContentProvider);
    final content = _draft ?? published;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _wideBreakpoint;
    final locale = ref.watch(localeProvider);
    final previewLanguage =
        _language.isEmpty ? locale.languageCode : _language;

    final tree = _CatalogTree(
      content: content,
      selection: _selection,
      language: _language,
      onSelect: _select,
      onAddFacilityType: _addFacilityType,
      onAddSection: _addSection,
      onAddSubsection: _addSubsection,
      onReorder: _reorder,
    );

    final editor = _selection == null
        ? const _EmptyEditorHint()
        : _NodeEditor(
            key: ValueKey('${_selection!.path}|$_language'),
            content: content,
            selection: _selection!,
            language: _language,
            onLanguageChanged: (value) => setState(() => _language = value),
            onChanged: _mutate,
            onDelete: () => _delete(_selection!),
          );

    final preview = _CatalogPreview(
      content: content,
      languageCode: previewLanguage,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovery catalogue'),
        actions: [
          if (!isWide)
            IconButton(
              tooltip: 'Preview',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => FractionallySizedBox(
                  heightFactor: 0.9,
                  child: preview,
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'restore') _restoreDefaults();
              if (value == 'discard') _discard();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'restore',
                child: Text('Restore built-in catalogue'),
              ),
              PopupMenuItem(
                value: 'discard',
                enabled: _isDirty,
                child: const Text('Discard changes'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: (_saving || !_isDirty) ? null : _publish,
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
      body: Column(
        children: [
          if (_isDirty)
            MaterialBanner(
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
              content: const Text(
                'You have unpublished changes. Customers still see the '
                'previously published catalogue.',
              ),
              actions: [
                TextButton(
                  onPressed: _discard,
                  child: const Text('Discard'),
                ),
              ],
            ),
          Expanded(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 320, child: tree),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 5, child: editor),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: width >= 1400 ? 380 : 320,
                        child: preview,
                      ),
                    ],
                  )
                : _selection == null
                    ? tree
                    : Column(
                        children: [
                          _BackToTreeBar(onBack: () => _select(null)),
                          Expanded(child: editor),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _NewNode {
  const _NewNode(this.key, this.title);
  final String key;
  final String title;
}

class _BackToTreeBar extends StatelessWidget {
  const _BackToTreeBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onBack,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.arrow_back_rounded, size: 18),
              SizedBox(width: 8),
              Text('Back to catalogue'),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyEditorHint extends StatelessWidget {
  const _EmptyEditorHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Pick something on the left to edit it.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tree
// ---------------------------------------------------------------------------

/// The catalogue tree: facility types, their sections, and each section's
/// subsections, with add / reorder / select controls.
class _CatalogTree extends StatelessWidget {
  const _CatalogTree({
    required this.content,
    required this.selection,
    required this.language,
    required this.onSelect,
    required this.onAddFacilityType,
    required this.onAddSection,
    required this.onAddSubsection,
    required this.onReorder,
  });

  final CatalogContent content;
  final CatalogSelection? selection;
  final String language;
  final ValueChanged<CatalogSelection?> onSelect;
  final VoidCallback onAddFacilityType;
  final ValueChanged<String> onAddSection;
  final void Function(String typeKey, String sectionKey) onAddSubsection;
  final void Function(List<CatalogNode>, int, int) onReorder;

  String _label(CatalogNode node) {
    final resolved = language.isEmpty
        ? node.title.base
        : node.title.resolve(language);
    return resolved.trim().isEmpty ? node.key : resolved;
  }

  @override
  Widget build(BuildContext context) {
    final types = [...content.facilityTypes]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      children: [
        for (var i = 0; i < types.length; i++)
          _FacilityTypeTile(
            type: types[i],
            label: _label(types[i]),
            selection: selection,
            labelOf: _label,
            canMoveUp: i > 0,
            canMoveDown: i < types.length - 1,
            onMove: (delta) => onReorder(types, i, delta),
            onSelect: onSelect,
            onAddSection: () => onAddSection(types[i].key),
            onAddSubsection: onAddSubsection,
            onReorder: onReorder,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddFacilityType,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add facility type'),
        ),
      ],
    );
  }
}

class _FacilityTypeTile extends StatelessWidget {
  const _FacilityTypeTile({
    required this.type,
    required this.label,
    required this.selection,
    required this.labelOf,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onSelect,
    required this.onAddSection,
    required this.onAddSubsection,
    required this.onReorder,
  });

  final CatalogFacilityType type;
  final String label;
  final CatalogSelection? selection;
  final String Function(CatalogNode) labelOf;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<int> onMove;
  final ValueChanged<CatalogSelection?> onSelect;
  final VoidCallback onAddSection;
  final void Function(String typeKey, String sectionKey) onAddSubsection;
  final void Function(List<CatalogNode>, int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    final sections = [...type.sections]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });
    final isSelected = selection?.typeKey == type.key &&
        selection?.sectionKey == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: selection?.typeKey == type.key,
        leading: Icon(CmsIcon.resolve(type.iconId)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: type.enabled ? null : TextDecoration.lineThrough,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!type.enabled)
              const Icon(Icons.visibility_off_outlined, size: 16),
          ],
        ),
        subtitle: Text('${sections.length} section(s)'),
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
        children: [
          _RowActions(
            isSelected: isSelected,
            onEdit: () => onSelect(CatalogSelection(type.key)),
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            onMove: onMove,
          ),
          for (var i = 0; i < sections.length; i++)
            _SectionTile(
              typeKey: type.key,
              section: sections[i],
              label: labelOf(sections[i]),
              labelOf: labelOf,
              selection: selection,
              canMoveUp: i > 0,
              canMoveDown: i < sections.length - 1,
              onMove: (delta) => onReorder(sections, i, delta),
              onSelect: onSelect,
              onAddSubsection: () => onAddSubsection(type.key, sections[i].key),
              onReorder: onReorder,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddSection,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add section'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.typeKey,
    required this.section,
    required this.label,
    required this.labelOf,
    required this.selection,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onSelect,
    required this.onAddSubsection,
    required this.onReorder,
  });

  final String typeKey;
  final CatalogSection section;
  final String label;
  final String Function(CatalogNode) labelOf;
  final CatalogSelection? selection;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<int> onMove;
  final ValueChanged<CatalogSelection?> onSelect;
  final VoidCallback onAddSubsection;
  final void Function(List<CatalogNode>, int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    final subs = [...section.subsections]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });
    final isSelected = selection?.sectionKey == section.key &&
        selection?.subsectionKey == null;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        initiallyExpanded: selection?.sectionKey == section.key,
        dense: true,
        leading: Icon(CmsIcon.resolve(section.iconId), size: 20),
        title: Text(
          label,
          style: TextStyle(
            decoration: section.enabled ? null : TextDecoration.lineThrough,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${subs.length} subsection(s)'),
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
        children: [
          _RowActions(
            isSelected: isSelected,
            onEdit: () => onSelect(CatalogSelection(typeKey, section.key)),
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            onMove: onMove,
          ),
          for (var i = 0; i < subs.length; i++)
            ListTile(
              dense: true,
              selected: selection?.subsectionKey == subs[i].key,
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              leading: Text(
                subs[i].emoji.isEmpty ? '•' : subs[i].emoji,
                style: const TextStyle(fontSize: 16),
              ),
              title: Text(
                labelOf(subs[i]),
                style: TextStyle(
                  decoration:
                      subs[i].enabled ? null : TextDecoration.lineThrough,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _MoveButtons(
                canMoveUp: i > 0,
                canMoveDown: i < subs.length - 1,
                onMove: (delta) => onReorder(subs, i, delta),
              ),
              onTap: () => onSelect(
                CatalogSelection(typeKey, section.key, subs[i].key),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddSubsection,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add subsection'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.isSelected,
    required this.onEdit,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
  });

  final bool isSelected;
  final VoidCallback onEdit;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(isSelected ? 'Editing' : 'Edit'),
        ),
        const Spacer(),
        _MoveButtons(
          canMoveUp: canMoveUp,
          canMoveDown: canMoveDown,
          onMove: onMove,
        ),
      ],
    );
  }
}

class _MoveButtons extends StatelessWidget {
  const _MoveButtons({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Move up',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
          onPressed: canMoveUp ? () => onMove(-1) : null,
        ),
        IconButton(
          tooltip: 'Move down',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
          onPressed: canMoveDown ? () => onMove(1) : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

/// Property editor for whichever node is selected.
///
/// Every input is bounded: text is length-checked and control characters are
/// rejected, icons come from a fixed list, images must be absolute `http(s)`
/// URLs, and position is an integer. Nothing here accepts markup, script or
/// widget definitions - the fields simply have nowhere to put them, because
/// content is rendered through `Text` and `Icon`, never interpreted.
class _NodeEditor extends StatelessWidget {
  const _NodeEditor({
    super.key,
    required this.content,
    required this.selection,
    required this.language,
    required this.onLanguageChanged,
    required this.onChanged,
    required this.onDelete,
  });

  final CatalogContent content;
  final CatalogSelection selection;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final void Function(CatalogContent Function(CatalogContent)) onChanged;
  final VoidCallback onDelete;

  CatalogNode? _node() {
    final type = content.facilityTypeFor(selection.typeKey);
    if (type == null) return null;
    if (selection.isFacilityType) return type;

    for (final section in type.sections) {
      if (section.key != selection.sectionKey) continue;
      if (selection.isSection) return section;
      for (final sub in section.subsections) {
        if (sub.key == selection.subsectionKey) return sub;
      }
    }
    return null;
  }

  /// Writes an edited node back into the document at the selected position.
  void _write(CatalogNode updated) {
    onChanged((doc) {
      if (updated is CatalogFacilityType) {
        return doc.upsertFacilityType(updated);
      }
      if (updated is CatalogSection) {
        return doc.upsertSection(selection.typeKey, updated);
      }
      if (updated is CatalogSubsection) {
        return doc.upsertSubsection(
          selection.typeKey,
          selection.sectionKey!,
          updated,
        );
      }
      return doc;
    });
  }

  void _setTitle(CatalogNode node, String value) {
    final next = language.isEmpty
        ? node.title.withBase(value)
        : node.title.withLanguage(language, value);
    _write(_copyTitle(node, next));
  }

  void _setDescription(CatalogNode node, String value) {
    final next = language.isEmpty
        ? node.description.withBase(value)
        : node.description.withLanguage(language, value);
    _write(_copyDescription(node, next));
  }

  static CatalogNode _copyTitle(CatalogNode node, CmsLocalizedText value) {
    if (node is CatalogFacilityType) return node.copyWith(title: value);
    if (node is CatalogSection) return node.copyWith(title: value);
    if (node is CatalogSubsection) return node.copyWith(title: value);
    return node;
  }

  static CatalogNode _copyDescription(
      CatalogNode node, CmsLocalizedText value) {
    if (node is CatalogFacilityType) return node.copyWith(description: value);
    if (node is CatalogSection) return node.copyWith(description: value);
    if (node is CatalogSubsection) return node.copyWith(description: value);
    return node;
  }

  static CatalogNode _copyScalars(
    CatalogNode node, {
    String? iconId,
    String? emoji,
    CmsMediaRef? media,
    int? order,
    bool? enabled,
  }) {
    if (node is CatalogFacilityType) {
      return node.copyWith(
          iconId: iconId,
          emoji: emoji,
          media: media,
          order: order,
          enabled: enabled);
    }
    if (node is CatalogSection) {
      return node.copyWith(
          iconId: iconId,
          emoji: emoji,
          media: media,
          order: order,
          enabled: enabled);
    }
    if (node is CatalogSubsection) {
      return node.copyWith(
          iconId: iconId,
          emoji: emoji,
          media: media,
          order: order,
          enabled: enabled);
    }
    return node;
  }

  static CatalogNode _copyWithCapabilities(
    CatalogNode node,
    FacilityCapabilities capabilities,
  ) {
    if (node is CatalogFacilityType) {
      return node.copyWith(capabilities: capabilities);
    }
    if (node is CatalogSection) {
      return node.copyWith(capabilities: capabilities);
    }
    if (node is CatalogSubsection) {
      return node.copyWith(capabilities: capabilities);
    }
    return node;
  }

  @override
  Widget build(BuildContext context) {
    final node = _node();
    if (node == null) {
      // The selected node was deleted underneath us.
      return const _EmptyEditorHint();
    }

    final theme = Theme.of(context);
    final isTranslating = language.isNotEmpty;
    final canDelete = !selection.isFacilityType ||
        !CatalogContent.isShippedFacilityType(node.key);

    final levelLabel = selection.isSubsection
        ? 'Subsection'
        : selection.isSection
            ? 'Section'
            : 'Facility type';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(levelLabel, style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(node.key,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(
          'Ids are permanent. Live venue categories are matched on them, so '
          'renaming one would disconnect content rather than move it.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Language selector
        Text('Language', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final entry in catalogEditorLanguages.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: language == entry.key,
                onSelected: (_) => onLanguageChanged(entry.key),
              ),
          ],
        ),
        if (isTranslating)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Leave a field empty to use the default text.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),

        TextFormField(
          initialValue: isTranslating
              ? node.title.overrides[language] ?? ''
              : node.title.base,
          decoration: InputDecoration(
            labelText: isTranslating ? 'Title translation' : 'Title',
            border: const OutlineInputBorder(),
            helperText: isTranslating
                ? 'Default: ${node.title.base}'
                : 'What customers read.',
            counterText: '',
          ),
          maxLength: CatalogValidator.maxTitleLength,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: isTranslating
              ? CatalogValidator.fieldTranslation
              : CatalogValidator.fieldTitle,
          onChanged: (value) => _setTitle(node, value),
        ),
        const SizedBox(height: 16),

        TextFormField(
          initialValue: isTranslating
              ? node.description.overrides[language] ?? ''
              : node.description.base,
          decoration: InputDecoration(
            labelText:
                isTranslating ? 'Description translation' : 'Description',
            border: const OutlineInputBorder(),
            helperText: 'Optional.',
            counterText: '',
          ),
          maxLines: 3,
          maxLength: CatalogValidator.maxDescriptionLength,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: CatalogValidator.fieldDescription,
          onChanged: (value) => _setDescription(node, value),
        ),
        const SizedBox(height: 16),

        if (!isTranslating) ...[
          _IconPicker(
            value: node.iconId,
            onChanged: (value) =>
                _write(_copyScalars(node, iconId: value)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: node.emoji,
            decoration: const InputDecoration(
              labelText: 'Emoji',
              border: OutlineInputBorder(),
              helperText: 'Optional, shown beside the title.',
              counterText: '',
            ),
            maxLength: 4,
            onChanged: (value) =>
                _write(_copyScalars(node, emoji: value.trim())),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: node.media.url,
            decoration: const InputDecoration(
              labelText: 'Image address',
              border: OutlineInputBorder(),
              helperText: 'Optional. Must start with https://. '
                  'Leave empty to use the built-in artwork.',
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: CatalogValidator.fieldMediaUrl,
            onChanged: (value) {
              final trimmed = value.trim();
              _write(_copyScalars(
                node,
                media: trimmed.isEmpty
                    ? CmsMediaRef.none
                    : CmsMediaRef.fromJson(trimmed),
              ));
            },
          ),
          if (node.media.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                node.media.url,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Text('That image could not be loaded.'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            initialValue: node.order.toString(),
            decoration: const InputDecoration(
              labelText: 'Position',
              border: OutlineInputBorder(),
              helperText: 'Lower numbers appear first.',
            ),
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: CatalogValidator.fieldOrder,
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed == null || parsed < 0) return;
              _write(_copyScalars(node, order: parsed));
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible to customers'),
            subtitle: Text(
              node.enabled
                  ? 'Shown in the app once published.'
                  : 'Hidden. Its content is kept and can be switched back on.',
            ),
            value: node.enabled,
            onChanged: (value) =>
                _write(_copyScalars(node, enabled: value)),
          ),
          const SizedBox(height: 16),
          CapabilityEditor(
            capabilities: node.capabilities ?? const FacilityCapabilities(),
            constraints: node.constraints,
            onChanged: (FacilityCapabilities caps) => _write(_copyWithCapabilities(node, caps)),
          ),
          if (node is CatalogSection) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Advanced'),
              children: [
                TextFormField(
                  initialValue: node.searchAliases.join(', '),
                  decoration: const InputDecoration(
                    labelText: 'Linked category slugs',
                    border: OutlineInputBorder(),
                    helperText: 'Comma separated. These connect the section to '
                        'live venue categories. Leave as-is unless you know '
                        'the slug has changed.',
                  ),
                  onChanged: (value) {
                    final slugs = value
                        .split(',')
                        .map((s) => s.trim().toLowerCase())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    _write((node).copyWith(searchAliases: slugs));
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (canDelete)
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('Delete this ${levelLabel.toLowerCase()}'),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'This facility type is built into the app, so it cannot be '
                'deleted - it would come back the next time the catalogue '
                'loads. Switch visibility off to hide it instead.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

/// Picks an icon from the ids compiled into this build.
///
/// A dropdown rather than a free-text field on purpose: an admin can only ever
/// choose a glyph the app already ships, so content can never reference an
/// icon that renders as a blank box.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ids = CmsIcon.knownIds.toList()..sort();
    final selected = CmsIcon.isKnown(value) ? value : CmsIcon.fallbackId;

    return DropdownButtonFormField<String>(
      value: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Icon',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final id in ids)
          DropdownMenuItem<String>(
            value: id,
            child: Row(
              children: [
                Icon(CmsIcon.resolve(id), size: 20),
                const SizedBox(width: 12),
                Text(id),
              ],
            ),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Preview
// ---------------------------------------------------------------------------

/// Shows the catalogue exactly as the draft resolves it: enabled entries only,
/// in admin order, with each string resolved for the chosen language through
/// the same `titleFor` / `descriptionFor` calls the app itself will use.
///
/// This is a **content** preview, not a pixel copy of Home. The customer
/// surface is painted by the 3D Glass Matrix, which is frozen UI this batch
/// must not touch, so reusing it would mean modifying it. What is shared with
/// production is the part that can actually be wrong - which entries appear,
/// in what order, under what wording, with which icon and artwork. Layout
/// fidelity is checked on the real screen once a later batch migrates it.
class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({required this.content, required this.languageCode});

  final CatalogContent content;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = content.visible;

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Preview', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                catalogEditorLanguages[languageCode] ?? languageCode,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What customers would see if you published now. Hidden entries '
            'are left out.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (types.isEmpty)
            Card(
              color: theme.colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nothing is visible. Customers would fall back to the '
                  'catalogue built into the app.',
                ),
              ),
            )
          else
            for (final type in types) _PreviewFacilityType(
              type: type,
              languageCode: languageCode,
            ),
        ],
      ),
    );
  }
}

class _PreviewFacilityType extends StatelessWidget {
  const _PreviewFacilityType({
    required this.type,
    required this.languageCode,
  });

  final CatalogFacilityType type;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = type.visibleSections;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CmsIcon.resolve(type.iconId), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  type.titleFor(languageCode, fallback: type.key),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sections.isEmpty)
            Text(
              'No visible sections.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            for (final section in sections)
              _PreviewSection(section: section, languageCode: languageCode),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.section, required this.languageCode});

  final CatalogSection section;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subs = section.visibleSubsections;
    final description = section.descriptionFor(languageCode);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.media.isNotEmpty)
            Image.network(
              section.media.url,
              height: 96,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => Container(
                height: 96,
                alignment: Alignment.center,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Text('Image unavailable'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (section.emoji.isNotEmpty) ...[
                      Text(section.emoji),
                      const SizedBox(width: 6),
                    ],
                    Icon(CmsIcon.resolve(section.iconId), size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        section.displayTitleFor(
                          languageCode,
                          fallback: section.key,
                        ),
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodySmall),
                ],
                if (subs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final sub in subs)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: sub.emoji.isNotEmpty
                              ? Text(sub.emoji)
                              : Icon(CmsIcon.resolve(sub.iconId), size: 14),
                          label: Text(
                            sub.titleFor(languageCode, fallback: sub.key),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
