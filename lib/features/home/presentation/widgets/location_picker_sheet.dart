import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../location/domain/gps_location.dart';
import '../../../location/domain/pin_code_location.dart';
import '../../../location/presentation/gps_session.dart';
import '../../../location/presentation/location_providers.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../discovery_location.dart';

class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  final _scrollController = ScrollController();
  final _pinSectionKey = GlobalKey();
  final _citySectionKey = GlobalKey();
  PinLookupResult _pinResult =
      const PinLookupResult(status: PinLookupStatus.idle);
  PinCodeOffice? _selectedOffice;
  bool _applyingGps = false;
  GpsSessionNotifier? _gpsSession;

  @override
  void initState() {
    super.initState();
    _gpsSession = ref.read(gpsSessionProvider.notifier);
  }

  @override
  void dispose() {
    _gpsSession?.cancelIfBusy();
    _pinController.dispose();
    _pinFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    FocusScope.of(context).unfocus();
    await ref.read(gpsSessionProvider.notifier).requestCurrentLocation();
  }

  Future<void> _lookupPin() async {
    final pin = _pinController.text.trim();
    final invalid = validateIndianPin(pin);
    if (invalid != null) {
      setState(() {
        _selectedOffice = null;
        _pinResult = PinLookupResult(
          status: PinLookupStatus.invalid,
          pincode: pin,
          message: invalid,
        );
      });
      return;
    }
    setState(() {
      _selectedOffice = null;
      _pinResult = PinLookupResult(
        status: PinLookupStatus.loading,
        pincode: pin,
      );
    });
    try {
      final result = await ref
          .read(pinCodeRepositoryProvider)
          .lookup(pin)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _pinResult = result;
        _selectedOffice = result.offices.isEmpty ? null : result.offices.first;
      });
      _pinFocus.unfocus();
      FocusScope.of(context).unfocus();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _pinResult = PinLookupResult(
          status: PinLookupStatus.error,
          pincode: pin,
          message: 'PIN lookup timed out. Try again.',
        );
      });
    }
  }

  void _applyGps(GpsFix fix) {
    if (_applyingGps) return;
    _applyingGps = true;
    ref.read(discoveryLocationProvider.notifier).applyGps(
          latitude: fix.latitude,
          longitude: fix.longitude,
          city: fix.city,
          district: fix.district,
          stateName: fix.state,
          pincode: fix.postalCode,
          label: fix.displayLabel,
        );
    Navigator.pop(context);
  }

  void _applyPin() {
    final office = _selectedOffice;
    if (office == null) return;
    ref.read(discoveryLocationProvider.notifier).applyPin(
          pincode: office.pincode,
          city: office.city,
          district: office.district,
          stateName: office.state,
          mandal: office.mandal,
          label: office.displayLabel,
        );
    Navigator.pop(context);
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    final citiesAsync = ref.watch(listedVenueCitiesProvider);
    final gps = ref.watch(gpsSessionProvider);
    const radii = [5, 10, 25];
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final topInset = MediaQuery.viewPaddingOf(context).top;

    final sheetWidth = MediaQuery.sizeOf(context).width;
    final canApplyGps = gps.isSuccess && gps.fix != null;
    final canApplyPin = _selectedOffice != null && _pinResult.isSuccess;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        topInset > 0 ? topInset : 12,
        20,
        20 + bottomInset,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        width: sheetWidth,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: gps.isBusy ? null : _useGps,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: gps.isBusy
                      ? const _GpsPulseIcon()
                      : const Icon(Icons.my_location_rounded),
                  label: Text(
                    gps.isBusy
                        ? 'Getting your location…'
                        : 'Use my current location',
                  ),
                ),
              ),
              if (gps.isBusy) ...[
                const SizedBox(height: 10),
                const _GpsProgressCard(),
              ],
              if (gps.isFailure) ...[
                const SizedBox(height: 10),
                _GpsFailureCard(
                  phase: gps.phase,
                  message: gps.message,
                  onRetry: _useGps,
                  onOpenSettings: () =>
                      ref.read(gpsSessionProvider.notifier).openSettings(),
                  onChooseCity: () => _scrollTo(_citySectionKey),
                  onEnterPin: () {
                    _scrollTo(_pinSectionKey);
                    _pinFocus.requestFocus();
                  },
                ),
              ],
              if (gps.isSuccess && gps.fix != null) ...[
                const SizedBox(height: 10),
                _GpsSuccessCard(
                  fix: gps.fix!,
                  onApply: () => _applyGps(gps.fix!),
                ),
              ],
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _pinSectionKey,
                child: const Text(
                  'Find by Indian PIN code',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pinController,
                      focusNode: _pinFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '6-digit PIN',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _lookupPin(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _pinResult.status == PinLookupStatus.loading
                        ? null
                        : _lookupPin,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _pinResult.status == PinLookupStatus.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lookup'),
                  ),
                ],
              ),
              if (_pinResult.status != PinLookupStatus.idle) ...[
                const SizedBox(height: 8),
                _PinStatusCard(
                  result: _pinResult,
                  selected: _selectedOffice,
                  onSelect: (office) =>
                      setState(() => _selectedOffice = office),
                  onRetry: _lookupPin,
                  onApply: _selectedOffice != null ? _applyPin : null,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Radius preference (used when GPS is available):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: radii.map((km) {
                  return ChoiceChip(
                    selected: location.radiusKm == km,
                    label: Text('$km km'),
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(discoveryLocationProvider.notifier)
                            .setRadiusKm(km);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _citySectionKey,
                child: const Text(
                  'Cities from listed venues',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              citiesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(listedVenueCitiesProvider),
                ),
                data: (cities) {
                  if (cities.isEmpty) {
                    return const EmptyState(
                      icon: Icons.location_off_outlined,
                      title: 'No listed cities yet',
                      message: 'Cities appear here from real venue listings.',
                    );
                  }
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.clear_all_rounded),
                        title: const Text('All cities'),
                        onTap: () {
                          ref
                              .read(discoveryLocationProvider.notifier)
                              .setCity(null);
                          Navigator.pop(context);
                        },
                      ),
                      ...cities.map((city) {
                        final selected = location.city == city &&
                            location.source == DiscoveryLocationSource.city;
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(city),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.brand)
                              : null,
                          onTap: () {
                            ref
                                .read(discoveryLocationProvider.notifier)
                                .setCity(city);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
                  ],
                ),
              ),
            ),
            if (canApplyGps || canApplyPin) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: Key(
                    canApplyGps ? 'apply_gps_location_footer' : 'apply_pin_location_footer',
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: canApplyGps
                      ? () => _applyGps(gps.fix!)
                      : _applyPin,
                  child: Text(
                    canApplyGps
                        ? 'Apply this location'
                        : 'Apply PIN location',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GpsPulseIcon extends StatefulWidget {
  const _GpsPulseIcon();

  @override
  State<_GpsPulseIcon> createState() => _GpsPulseIconState();
}

class _GpsPulseIconState extends State<_GpsPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: const Icon(Icons.near_me_rounded),
    );
  }
}

class _GpsProgressCard extends StatelessWidget {
  const _GpsProgressCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const _GpsPulseIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Getting your location…',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsSuccessCard extends StatelessWidget {
  const _GpsSuccessCard({required this.fix, required this.onApply});

  final GpsFix fix;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fix.cityLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              fix.geocodeFailed
                  ? '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)} · choose a city or PIN to name this place'
                  : '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('apply_gps_location'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: onApply,
                child: const Text('Apply this location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsFailureCard extends StatelessWidget {
  const _GpsFailureCard({
    required this.phase,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onChooseCity,
    required this.onEnterPin,
    this.message,
  });

  final GpsPhase phase;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onChooseCity;
  final VoidCallback onEnterPin;

  @override
  Widget build(BuildContext context) {
    final title = switch (phase) {
      GpsPhase.permissionDenied => 'Location permission is off',
      GpsPhase.serviceDisabled => 'Location Services are off',
      GpsPhase.timeout => 'Location request timed out',
      _ => "Couldn't get your location",
    };
    final showSettings =
        phase == GpsPhase.permissionDenied || phase == GpsPhase.serviceDisabled;
    final showChooseCity = phase != GpsPhase.timeout;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (message != null && message!.isNotEmpty && message != title) ...[
              const SizedBox(height: 4),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showSettings)
                  FilledButton(
                    onPressed: onOpenSettings,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Open Settings'),
                  ),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Retry'),
                ),
                if (showChooseCity)
                  OutlinedButton(
                    onPressed: onChooseCity,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Choose city'),
                  ),
                if (showChooseCity)
                  OutlinedButton(
                    onPressed: onEnterPin,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Enter PIN'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinStatusCard extends StatelessWidget {
  const _PinStatusCard({
    required this.result,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
    this.onApply,
  });

  final PinLookupResult result;
  final PinCodeOffice? selected;
  final ValueChanged<PinCodeOffice> onSelect;
  final VoidCallback onRetry;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    if (result.status == PinLookupStatus.loading) {
      return const LinearProgressIndicator();
    }
    if (result.status == PinLookupStatus.success) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: RadioGroup<PinCodeOffice>(
            groupValue: selected,
            onChanged: (office) {
              if (office != null) onSelect(office);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...result.offices.map((office) {
                  final isSelected = selected?.name == office.name &&
                      selected?.pincode == office.pincode;
                  return RadioListTile<PinCodeOffice>(
                    value: office,
                    dense: true,
                    title: Text(office.displayLabel),
                    subtitle: office.hierarchy.isEmpty
                        ? null
                        : Text(
                            office.hierarchy
                                .map((item) => '${item.$1}: ${item.$2}')
                                .join(' · '),
                          ),
                    selected: isSelected,
                  );
                }),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: onApply,
                  child: const Text('Apply PIN location'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message ??
                  (result.status == PinLookupStatus.empty
                      ? 'No postal records found for this PIN.'
                      : 'PIN lookup failed.'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
