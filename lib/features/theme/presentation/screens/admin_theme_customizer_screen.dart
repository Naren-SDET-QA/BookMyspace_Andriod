import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_config.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/app_theme_config_snapshot.dart';
import '../app_theme_providers.dart';

class AdminThemeCustomizerScreen extends ConsumerStatefulWidget {
  const AdminThemeCustomizerScreen({super.key});

  @override
  ConsumerState<AdminThemeCustomizerScreen> createState() =>
      _AdminThemeCustomizerScreenState();
}

class _AdminThemeCustomizerScreenState
    extends ConsumerState<AdminThemeCustomizerScreen> {
  AppThemeConfig? _draft;
  Brightness _previewBrightness = Brightness.light;
  bool _saving = false;
  bool _publishing = false;

  void _update(AppThemeConfig next) => setState(() => _draft = next);

  Future<void> _saveDraft() async {
    final draft = _draft;
    if (draft == null || _saving || _publishing) return;
    setState(() => _saving = true);
    try {
      await ref.read(appThemeConfigControllerProvider).saveDraft(draft);
      if (!mounted) return;
      setState(() => _draft = null);
      _showMessage(AppLocalizations.of(context).adminThemeDraftSaved);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${AppLocalizations.of(context).adminThemeSaveError}: $error',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    if (_saving || _publishing) return;
    setState(() => _publishing = true);
    try {
      final draft = _draft;
      if (draft != null) {
        await ref.read(appThemeConfigControllerProvider).saveDraft(draft);
      }
      await ref.read(appThemeConfigControllerProvider).publish();
      if (!mounted) return;
      setState(() => _draft = null);
      _showMessage(AppLocalizations.of(context).adminThemePublished);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        '${AppLocalizations.of(context).adminThemePublishError}: $error',
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _resetToDefault() {
    setState(() => _draft = AppThemeConfig.defaults);
    _showMessage(AppLocalizations.of(context).adminThemeDefaultRestored);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(adminAppThemeConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminThemeTitle)),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '${l10n.adminThemeLoadError}: $error',
          onRetry: () => ref.invalidate(adminAppThemeConfigProvider),
        ),
        data: (value) => value.isEmpty && _draft == null
            ? _emptyState(context)
            : _workspace(context, value),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.palette_outlined,
      title: l10n.adminThemeEmpty,
      message: l10n.adminThemeStartWithDefaults,
      action: FilledButton.icon(
        onPressed: _resetToDefault,
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text(l10n.adminThemeResetDefault),
      ),
    );
  }

  Widget _workspace(BuildContext context, AppThemeConfigSnapshot snapshot) {
    final l10n = AppLocalizations.of(context);
    final config = _draft ?? snapshot.draft;
    return ResponsiveLayoutBuilder(
      builder: (context, responsive) {
        final editor = _editor(context, config, responsive);
        final preview = _preview(context, config);
        final actions = _actions(context, snapshot);
        final content = <Widget>[
          _intro(context, snapshot),
          const SizedBox(height: 16),
          actions,
          const SizedBox(height: 16),
          if (_draft != null)
            _StatusBanner(
              icon: Icons.edit_note_rounded,
              text: l10n.adminThemeUnsaved,
            ),
          if (_draft != null) const SizedBox(height: 12),
          if (responsive.isCompact || responsive.isMedium) ...[
            editor,
            const SizedBox(height: 16),
            preview,
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: editor),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: preview),
              ],
            ),
          ],
        ];
        return ListView(
          padding: EdgeInsets.fromLTRB(
            responsive.horizontalPadding,
            20,
            responsive.horizontalPadding,
            36,
          ),
          children: content,
        );
      },
    );
  }

  Widget _intro(BuildContext context, AppThemeConfigSnapshot snapshot) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminThemeTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(l10n.adminThemeSubtitle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.verified_outlined, size: 16),
              label: Text(
                '${l10n.adminThemePublishedVersion}: ${snapshot.publishedVersion}',
              ),
            ),
            if (snapshot.publishedAt != null)
              Chip(
                avatar: const Icon(Icons.schedule_outlined, size: 16),
                label: Text(_dateLabel(snapshot.publishedAt!)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, AppThemeConfigSnapshot snapshot) {
    final l10n = AppLocalizations.of(context);
    final busy = _saving || _publishing;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : _resetToDefault,
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text(l10n.adminThemeResetDefault),
        ),
        OutlinedButton.icon(
          onPressed: busy || _draft == null ? null : _saveDraft,
          icon:
              _saving ? const _ProgressIcon() : const Icon(Icons.save_outlined),
          label: Text(l10n.adminThemeSaveDraft),
        ),
        FilledButton.icon(
          onPressed: busy ? null : _publish,
          icon: _publishing
              ? const _ProgressIcon()
              : const Icon(Icons.publish_outlined),
          label: Text(l10n.adminThemePublish),
        ),
        if (snapshot.draftVersion != snapshot.publishedVersion)
          Chip(
            avatar: const Icon(Icons.pending_actions_rounded, size: 16),
            label: Text(l10n.adminThemeDraft),
          ),
      ],
    );
  }

  Widget _editor(
    BuildContext context,
    AppThemeConfig config,
    ResponsiveInfo responsive,
  ) {
    final l10n = AppLocalizations.of(context);
    final mode = _previewBrightness;
    final variant = config.variantFor(mode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminThemeColors,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<Brightness>(
                  segments: [
                    ButtonSegment(
                      value: Brightness.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(l10n.adminThemeLight),
                    ),
                    ButtonSegment(
                      value: Brightness.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(l10n.adminThemeDark),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) =>
                      setState(() => _previewBrightness = value.first),
                ),
                const SizedBox(height: 16),
                _colorFields(context, config, variant, responsive),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _shapeCard(context, config),
      ],
    );
  }

  Widget _colorFields(
    BuildContext context,
    AppThemeConfig config,
    AppThemeVariant variant,
    ResponsiveInfo responsive,
  ) {
    final l10n = AppLocalizations.of(context);
    final maxWidth =
        responsive.isCompact || responsive.isMedium ? double.infinity : 320.0;
    Widget field(String label, Color color, ValueChanged<Color> onChanged) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _ColorField(label: label, color: color, onChanged: onChanged),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        field(
          l10n.adminThemePrimary,
          variant.primary,
          (value) => _update(_replaceVariant(config, variant, primary: value)),
        ),
        field(
          l10n.adminThemeSecondary,
          variant.secondary,
          (value) =>
              _update(_replaceVariant(config, variant, secondary: value)),
        ),
        field(
          l10n.adminThemeBackground,
          variant.background,
          (value) =>
              _update(_replaceVariant(config, variant, background: value)),
        ),
        field(
          l10n.adminThemeSurface,
          variant.surface,
          (value) => _update(_replaceVariant(config, variant, surface: value)),
        ),
        field(
          l10n.adminThemeText,
          variant.text,
          (value) => _update(_replaceVariant(config, variant, text: value)),
        ),
        field(
          l10n.adminThemeCard,
          variant.card,
          (value) => _update(_replaceVariant(config, variant, card: value)),
        ),
      ],
    );
  }

  AppThemeConfig _replaceVariant(
    AppThemeConfig config,
    AppThemeVariant current, {
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? text,
    Color? card,
  }) {
    final next = current.copyWith(
      primary: primary,
      secondary: secondary,
      background: background,
      surface: surface,
      text: text,
      card: card,
    );
    return _previewBrightness == Brightness.dark
        ? config.copyWith(dark: next)
        : config.copyWith(light: next);
  }

  Widget _shapeCard(BuildContext context, AppThemeConfig config) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminThemeShape,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _SliderField(
              label: l10n.adminThemeCardRadius,
              value: config.cardRadius,
              max: 32,
              suffix: 'dp',
              onChanged: (value) => _update(config.copyWith(cardRadius: value)),
            ),
            _SliderField(
              label: l10n.adminThemeButtonRadius,
              value: config.buttonRadius,
              max: 32,
              suffix: 'dp',
              onChanged: (value) =>
                  _update(config.copyWith(buttonRadius: value)),
            ),
            _SliderField(
              label: l10n.adminThemeInputRadius,
              value: config.inputRadius,
              max: 32,
              suffix: 'dp',
              onChanged: (value) =>
                  _update(config.copyWith(inputRadius: value)),
            ),
            _SliderField(
              label: l10n.adminThemeElevation,
              value: config.cardElevation,
              max: 12,
              suffix: 'dp',
              onChanged: (value) =>
                  _update(config.copyWith(cardElevation: value)),
            ),
            _SliderField(
              label: l10n.adminThemeGlassOpacity,
              value: config.glassOpacity,
              max: 1,
              divisions: 20,
              suffix: '%',
              displayValue: '${(config.glassOpacity * 100).round()}%',
              onChanged: (value) =>
                  _update(config.copyWith(glassOpacity: value)),
            ),
            _SliderField(
              label: l10n.adminThemeGlassBorderOpacity,
              value: config.glassBorderOpacity,
              max: 1,
              divisions: 20,
              suffix: '%',
              displayValue: '${(config.glassBorderOpacity * 100).round()}%',
              onChanged: (value) =>
                  _update(config.copyWith(glassBorderOpacity: value)),
            ),
            const SizedBox(height: 8),
            _DropdownField(
              label: l10n.adminThemeBannerStyle,
              value: config.bannerStyle,
              options: {
                'gradient': l10n.adminThemeStyleGradient,
                'solid': l10n.adminThemeStyleSolid,
                'minimal': l10n.adminThemeStyleMinimal,
              },
              onChanged: (value) =>
                  _update(config.copyWith(bannerStyle: value)),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: l10n.adminThemeButtonStyle,
              value: config.buttonStyle,
              options: {
                'filled': l10n.adminThemeStyleFilled,
                'soft': l10n.adminThemeStyleSoft,
                'outline': l10n.adminThemeStyleOutline,
              },
              onChanged: (value) =>
                  _update(config.copyWith(buttonStyle: value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, AppThemeConfig config) {
    final l10n = AppLocalizations.of(context);
    final brightness = _previewBrightness;
    final previewTheme = AppTheme.fromConfig(config, brightness);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminThemeLivePreview,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Icon(
                  Icons.visibility_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Theme(
              data: previewTheme,
              child: _CustomerPreview(
                title: l10n.adminThemePreviewTitle,
                subtitle: l10n.adminThemePreviewSubtitle,
                buttonLabel: l10n.adminThemePreviewAction,
                lightLabel: l10n.adminThemeLight,
                darkLabel: l10n.adminThemeDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      date.toLocal().toIso8601String().split('T').first;
}

class _CustomerPreview extends StatelessWidget {
  const _CustomerPreview({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.lightLabel,
    required this.darkLabel,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final String lightLabel;
  final String darkLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BookMySpace',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(label: Text(isDark ? darkLabel : lightLabel)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(extension?.cardRadius ?? 16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(subtitle),
                const SizedBox(height: 14),
                FilledButton(onPressed: () {}, child: Text(buttonLabel)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: subtitle,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(title),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorField extends StatefulWidget {
  const _ColorField({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: AppThemeVariant.hexOf(widget.color),
    );
  }

  @override
  void didUpdateWidget(covariant _ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = AppThemeVariant.hexOf(widget.color);
    if (oldWidget.color != widget.color && _controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = AppThemeVariant.colorFromHex(_controller.text);
    final color = parsed ?? widget.color;
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
        helperText: '#RRGGBB',
      ),
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        final next = AppThemeVariant.colorFromHex(value);
        if (next != null) widget.onChanged(next);
        setState(() {});
      },
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.suffix = '',
    this.displayValue,
  });

  final String label;
  final double value;
  final double max;
  final int? divisions;
  final String suffix;
  final String? displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final valueText = displayValue ?? '${value.round()}$suffix';
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueText, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          max: max,
          divisions: divisions,
          label: valueText,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options.entries)
          DropdownMenuItem(value: option.key, child: Text(option.value)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ProgressIcon extends StatelessWidget {
  const _ProgressIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
