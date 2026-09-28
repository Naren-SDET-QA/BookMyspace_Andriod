import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../owner_venues/presentation/widgets/media_preview.dart';
import '../../domain/media_item.dart';
import '../../domain/venue.dart';

/// "Video tour" and "3D / 360° tour" actions on the venue page. Hidden when
/// the owner has added neither.
class VenueMediaTours extends StatelessWidget {
  const VenueMediaTours({super.key, required this.venue});

  final Venue venue;

  MediaItem _item(String url, MediaKind kind) => MediaItem(
        id: '${venue.id}-${kind.name}',
        venueId: venue.id,
        url: url,
        kind: kind,
        isActive: true,
        isCover: false,
        sortOrder: 0,
        processingStatus: MediaProcessingStatus.ready,
      );

  Future<void> _openTour(BuildContext context) async {
    if (venue.tourIsModel) {
      await showMediaPreview(context, _item(venue.tourUrl, MediaKind.model3d));
      return;
    }
    final uri = Uri.tryParse(venue.tourUrl);
    final messenger = ScaffoldMessenger.of(context);
    final ok = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the virtual tour.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = venue.videoUrl.isNotEmpty;
    final hasTour = venue.tourUrl.isNotEmpty;
    if (!hasVideo && !hasTour) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (hasVideo)
            OutlinedButton.icon(
              key: const Key('venue-video-tour'),
              onPressed: () => showMediaPreview(
                context,
                _item(venue.videoUrl, MediaKind.video),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch video tour'),
            ),
          if (hasTour)
            OutlinedButton.icon(
              key: const Key('venue-3d-tour'),
              onPressed: () => _openTour(context),
              icon: const Icon(Icons.threed_rotation_rounded),
              label: const Text('3D / 360° tour'),
            ),
        ],
      ),
    );
  }
}
