import 'package:flutter/material.dart';
import '../../domain/venue_discovery.dart';
import '../../infrastructure/overpass_discovery_service.dart';
import '../../infrastructure/supabase_discovery_repository.dart';

class VenueDiscoveryScreen extends StatefulWidget {
  const VenueDiscoveryScreen({
    super.key,
    this.service,
    this.repository,
    this.allowClaims = false,
  });
  final OverpassDiscoveryService? service;
  final SupabaseDiscoveryRepository? repository;
  final bool allowClaims;
  @override
  State<VenueDiscoveryScreen> createState() => _VenueDiscoveryScreenState();
}

class _VenueDiscoveryScreenState extends State<VenueDiscoveryScreen> {
  final _city = TextEditingController();
  final _store = InMemoryVenueStagingStore();
  String _state = 'Andhra Pradesh';
  String _category = 'Function Hall';
  List<DiscoveredVenue> _results = const [];
  bool _loading = false;
  String? _message;
  int? _stagedCount;
  int? _duplicateCount;

  Future<void> _search() async {
    if (_city.text.trim().isEmpty) {
      setState(() => _message = 'Enter a town or city.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
      _stagedCount = null;
      _duplicateCount = null;
    });
    try {
      List<DiscoveredVenue> found;
      if (widget.repository == null) {
        found = await (widget.service ?? OverpassDiscoveryService()).discover(
          state: _state,
          city: _city.text.trim(),
          category: _category,
        );
      } else {
        // The import-venues edge function stages every result it finds into
        // venue_discovery_staging (via stage_discovered_venue) as part of
        // this call — search and staging are the same server-side action
        // on this path, not two separate steps.
        final response = await widget.repository!.discover(
          state: _state,
          city: _city.text.trim(),
          category: _category,
        );
        _stagedCount = response['staged_count'] as int?;
        _duplicateCount = response['duplicate_count'] as int?;
        found = (response['venues'] as List)
            .map(
              (v) => DiscoveredVenue(
                source: v['source'] as String,
                sourcePlaceId: v['sourcePlaceId'] as String,
                name: v['name'] as String,
                latitude: (v['latitude'] as num).toDouble(),
                longitude: (v['longitude'] as num).toDouble(),
                address: v['address'] as String?,
                city: v['city'] as String?,
                state: v['state'] as String?,
                phone: v['phone'] as String?,
                website: v['website'] as String?,
                openingHours: v['openingHours'] as String?,
                category: v['category'] as String?,
                sourceUrl: v['sourceUrl'] as String?,
                stagingId: v['stagingId'] as String?,
                rawMetadata: Map<String, dynamic>.from(
                  v['rawMetadata'] as Map? ?? const {},
                ),
              ),
            )
            .toList();
      }
      final unique = <String, DiscoveredVenue>{
        for (final venue in found)
          '${venue.source}:${venue.sourcePlaceId}': venue,
      };
      setState(() {
        _results = unique.values.toList();
        _loading = false;
        _message = _results.isEmpty ? 'No venues found.' : null;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _message = 'Could not reach venue discovery. Try again.';
      });
    }
  }

  void _showDetails(DiscoveredVenue venue) {
    final alreadyStaged = widget.repository != null;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(venue.name, style: Theme.of(context).textTheme.titleLarge),
            if (venue.address != null) Text(venue.address!),
            if (venue.phone != null) Text(venue.phone!),
            if (venue.website != null) Text(venue.website!),
            Text('${venue.latitude}, ${venue.longitude}'),
            Text('${venue.source} • ${venue.sourcePlaceId}'),
            const SizedBox(height: 12),
            if (widget.allowClaims && venue.stagingId != null)
              FilledButton.icon(
                onPressed: () => _submitClaim(venue),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Claim this venue'),
              )
            else if (alreadyStaged)
              const Text(
                'Already added to the admin review queue from this search.',
              )
            else
              FilledButton(
                onPressed: () {
                  _store.stage(venue);
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Stage locally (preview only)'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitClaim(DiscoveredVenue venue) async {
    final proof = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim this venue'),
        content: TextField(
          controller: proof,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Proof or contact note (optional)',
            hintText: 'Tell the admin why you represent this place.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, proof.text.trim()),
            child: const Text('Submit claim'),
          ),
        ],
      ),
    );
    proof.dispose();
    if (!mounted || note == null || venue.stagingId == null) return;
    try {
      await widget.repository!.submitClaim(venue.stagingId!, proofNote: note);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim submitted for admin approval.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit claim: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Venue Discovery')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _state,
          decoration: const InputDecoration(labelText: 'State'),
          items: [
            'Andhra Pradesh',
            'Karnataka',
            'Telangana',
            'Maharashtra',
            'Delhi NCR',
            'Tamil Nadu',
            'Goa',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _state = v!),
        ),
        TextField(
          controller: _city,
          decoration: const InputDecoration(labelText: 'Town / City'),
        ),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Venue Category'),
          items: [
            'Function Hall',
            'Hotel',
            'Temple',
            'Sports Court',
            'Olympic Turf Complex',
            'Rooftop Event Arena',
            'Coworking Space',
            'Badminton Academy',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _search,
          child: const Text('Search venues'),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_message != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        if (_stagedCount != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Staged $_stagedCount new for admin review'
              '${(_duplicateCount ?? 0) > 0 ? ' ($_duplicateCount already in the queue)' : ''}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ..._results.map(
          (v) => Card(
            child: ListTile(
              title: Text(v.name),
              subtitle: Text(
                [
                  if (v.address != null) v.address!,
                  if (v.category != null) v.category!,
                  '${v.source} • ${v.sourcePlaceId}',
                ].join('\n'),
              ),
              onTap: () => _showDetails(v),
            ),
          ),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }
}
