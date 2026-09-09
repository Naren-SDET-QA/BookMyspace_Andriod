import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../providers/owner_venue_providers.dart';

/// Photo item representation in the gallery.
class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.url,
    this.fileName = 'Space Photo',
    this.fileSizeFormatted = '1.2 MB',
    this.isCover = false,
    this.isUploading = false,
    this.uploadProgress = 1.0,
    this.statusStage = '',
    this.errorMessage,
  });

  final String id;
  final String url;
  final String fileName;
  final String fileSizeFormatted;
  final bool isCover;
  final bool isUploading;
  final double uploadProgress;
  final String statusStage;
  final String? errorMessage;

  GalleryPhoto copyWith({
    String? id,
    String? url,
    String? fileName,
    String? fileSizeFormatted,
    bool? isCover,
    bool? isUploading,
    double? uploadProgress,
    String? statusStage,
    String? errorMessage,
  }) {
    return GalleryPhoto(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      fileSizeFormatted: fileSizeFormatted ?? this.fileSizeFormatted,
      isCover: isCover ?? this.isCover,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      statusStage: statusStage ?? this.statusStage,
      errorMessage: errorMessage,
    );
  }
}

/// Operating slot model.
class OperatingSlot {
  OperatingSlot({
    required this.id,
    required this.title,
    required this.timing,
    required this.price,
    this.isSelected = true,
  });

  final String id;
  final String title;
  final String timing;
  final double price;
  bool isSelected;
}

/// Multi-step owner venue creation and editing screen.
class CreateVenueScreen extends ConsumerStatefulWidget {
  const CreateVenueScreen({super.key, this.existingVenue});

  final Venue? existingVenue;

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen> {
  int _currentStep = 0;
  bool _isSaving = false;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _capacityController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  // Media & 3D Walkthrough Controllers
  late final TextEditingController _videoTitleController;
  late final TextEditingController _videoUrlController;
  late final TextEditingController _tour3dUrlController;
  late final TextEditingController _tour3dHotspotsController;

  // URL dialog controller
  final _urlInputController = TextEditingController();
  String? _urlInputError;

  // Selected Category
  String _selectedCategoryId = 'banquet';

  // Gallery Photos
  List<GalleryPhoto> _photos = [];

  // Batch Upload Simulation State
  bool _isBatchUploading = false;
  double _batchProgress = 0.0;
  String _batchStatus = '';

  // Facilities & Amenities
  final Map<String, bool> _facilities = {
    'High-Speed WiFi': true,
    'Valet Parking': true,
    'Central Air Conditioning': true,
    'Power Backup': true,
    'Sound & DJ System': true,
    'Catering Kitchen': true,
    'Elevator Access': false,
    'Wheelchair Accessible': true,
    'Security & CCTV': true,
    'Bridal / Green Room': true,
  };

  // Time Slots
  late List<OperatingSlot> _slots;

  // Fullscreen Photo Viewer URL
  String? _fullscreenPhotoUrl;

  // Camera preview URL
  String? _pendingCameraUrl;

  final List<(String, String)> _presetImages = const [
    (
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1200&q=80',
      'Grand Ballroom',
    ),
    (
      'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80',
      'Floral Stage',
    ),
    (
      'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80',
      'Open Lawn',
    ),
    (
      'https://images.unsplash.com/photo-1533105079780-92b9be482077?auto=format&fit=crop&w=1200&q=80',
      'Skyline Rooftop',
    ),
    (
      'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1200&q=80',
      'Co-Working Space',
    ),
    (
      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=1200&q=80',
      'Sports Turf',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final ev = widget.existingVenue;

    _nameController = TextEditingController(text: ev?.name ?? '');
    _descriptionController = TextEditingController(text: ev?.description ?? '');
    _priceController = TextEditingController(
      text: ev != null ? ev.pricingBaseAmount.toInt().toString() : '35000',
    );
    _capacityController = TextEditingController(
      text: ev != null && ev.capacity > 0 ? ev.capacity.toString() : '500',
    );
    _addressController = TextEditingController(text: ev?.address ?? '');
    _cityController = TextEditingController(text: ev?.city ?? 'Hyderabad');
    _stateController = TextEditingController(text: ev?.state ?? 'Telangana');
    _pincodeController = TextEditingController(text: ev?.pincode ?? '500081');
    _latController = TextEditingController(
      text: ev != null ? ev.latitude.toString() : '17.4435',
    );
    _lngController = TextEditingController(
      text: ev != null ? ev.longitude.toString() : '78.3772',
    );

    _videoTitleController = TextEditingController(text: 'Virtual Walkthrough Tour');
    _videoUrlController = TextEditingController();
    _tour3dUrlController = TextEditingController();
    _tour3dHotspotsController = TextEditingController(text: 'Grand Entrance, Main Ballroom, Dining Area');

    if (ev?.category != null && ev!.category!.id.isNotEmpty) {
      _selectedCategoryId = ev.category!.id;
    }

    if (ev != null && ev.images.isNotEmpty) {
      _photos = ev.images.asMap().entries.map((entry) {
        return GalleryPhoto(
          id: 'img_${entry.key}',
          url: entry.value.url,
          fileName: 'Venue Photo ${entry.key + 1}',
          isCover: entry.key == 0 || entry.value.isCover,
        );
      }).toList();
    } else {
      _photos = [
        const GalleryPhoto(
          id: 'preset_1',
          url: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1200&q=80',
          fileName: 'Grand Ballroom & Stage',
          isCover: true,
        ),
        const GalleryPhoto(
          id: 'preset_2',
          url: 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80',
          fileName: 'Floral Arch & Setup',
          isCover: false,
        ),
      ];
    }

    if (ev != null && ev.facilities.isNotEmpty) {
      for (final f in ev.facilities) {
        _facilities[f.facility] = f.isAvailable;
      }
    }

    final baseAmount = double.tryParse(_priceController.text) ?? 35000.0;
    _slots = [
      OperatingSlot(
        id: 'slot_morning',
        title: 'Morning Session',
        timing: '08:00 AM - 02:00 PM',
        price: (baseAmount * 0.6).roundToDouble(),
      ),
      OperatingSlot(
        id: 'slot_evening',
        title: 'Evening Gala / Reception',
        timing: '04:00 PM - 11:30 PM',
        price: baseAmount,
      ),
      OperatingSlot(
        id: 'slot_fullday',
        title: 'Full Day Exclusive Access',
        timing: '24 Hours (Full Access)',
        price: (baseAmount * 1.5).roundToDouble(),
      ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _videoTitleController.dispose();
    _videoUrlController.dispose();
    _tour3dUrlController.dispose();
    _tour3dHotspotsController.dispose();
    _urlInputController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.existingVenue != null;

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitVenue() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a space/venue name.')),
      );
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final address = _addressController.text.trim();
    final pincode = _pincodeController.text.trim();
    final pricing = double.tryParse(_priceController.text.trim()) ?? 15000.0;
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 100;
    final lat = double.tryParse(_latController.text.trim()) ?? 17.4435;
    final lng = double.tryParse(_lngController.text.trim()) ?? 78.3772;

    final venueImages = _photos.asMap().entries.map((entry) {
      return VenueImage(
        id: 'img_${entry.key}',
        url: entry.value.url,
        altText: entry.value.fileName,
        isCover: entry.key == 0,
        sortOrder: entry.key,
      );
    }).toList();

    final selectedFacilities = _facilities.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    try {
      if (_isEditMode) {
        await ref.read(
          updateVenueProvider((
            venueId: widget.existingVenue!.id,
            name: name,
            categoryId: _selectedCategoryId,
            description: description,
            city: city,
            state: state,
            latitude: lat,
            longitude: lng,
            capacity: capacity,
            pricingBaseAmount: pricing,
            address: address,
            pincode: pincode,
            images: venueImages,
            facilities: selectedFacilities,
            videoUrl: _videoUrlController.text.trim(),
            tour3dUrl: _tour3dUrlController.text.trim(),
            isActive: true,
          )).future,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Updated "$name" successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
          context.pop();
        }
      } else {
        await ref.read(
          createVenueProvider((
            name: name,
            categoryId: _selectedCategoryId,
            description: description,
            city: city,
            state: state,
            latitude: lat,
            longitude: lng,
            capacity: capacity,
            pricingBaseAmount: pricing,
            address: address,
            pincode: pincode,
            images: venueImages,
            facilities: selectedFacilities,
            videoUrl: _videoUrlController.text.trim(),
            tour3dUrl: _tour3dUrlController.text.trim(),
          )).future,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.celebration, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Space "$name" published successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving space: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _movePhotoLeft(int index) {
    if (index > 0) {
      setState(() {
        final item = _photos.removeAt(index);
        _photos.insert(index - 1, item);
      });
    }
  }

  void _movePhotoRight(int index) {
    if (index < _photos.length - 1) {
      setState(() {
        final item = _photos.removeAt(index);
        _photos.insert(index + 1, item);
      });
    }
  }

  void _makeCover(int index) {
    if (index > 0 && index < _photos.length) {
      setState(() {
        final item = _photos.removeAt(index);
        _photos.insert(0, item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set as Cover Photo ⭐')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _showAddPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Space Photos',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload high-resolution images of your space',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Camera Capture
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                    child: Icon(Icons.camera_alt, color: Theme.of(ctx).colorScheme.primary),
                  ),
                  title: const Text('Take Live Photo 📷', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Capture space highlights using camera'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _simulateCameraCapture();
                  },
                ),
                const SizedBox(height: 8),
                // Device Gallery / Presets
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.secondaryContainer,
                    child: Icon(Icons.photo_library, color: Theme.of(ctx).colorScheme.secondary),
                  ),
                  title: const Text('Choose from Gallery 🖼️', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select photos with instant WebP batch upload'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startBatchUploadSimulation();
                  },
                ),
                const SizedBox(height: 8),
                // URL input
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.tertiaryContainer,
                    child: Icon(Icons.link, color: Theme.of(ctx).colorScheme.tertiary),
                  ),
                  title: const Text('Add by Web URL 🔗', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Paste direct high-res image link'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUrlInputDialog();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _simulateCameraCapture() {
    setState(() {
      _pendingCameraUrl = 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1200&q=80';
    });
    _showCameraPreviewDialog();
  }

  void _showCameraPreviewDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Photo Preview 📸',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      _pendingCameraUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.Center,
                        child: const Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Review your venue photo before adding it to the listing gallery.',
                  textAlign: TextAlign.Center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retake'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _simulateCameraCapture();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirm & Add'),
                        onPressed: () {
                          if (_pendingCameraUrl != null) {
                            setState(() {
                              _photos.add(GalleryPhoto(
                                id: 'cam_${DateTime.now().millisecondsSinceEpoch}',
                                url: _pendingCameraUrl!,
                                fileName: 'Captured Photo ${_photos.length + 1}',
                              ));
                              _pendingCameraUrl = null;
                            });
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Photo added to gallery! 📸')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startBatchUploadSimulation() async {
    setState(() {
      _isBatchUploading = true;
      _batchProgress = 0.2;
      _batchStatus = 'Compressing & WebP encoding images...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _batchProgress = 0.6;
      _batchStatus = 'Uploading batch to Supabase Storage...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _batchProgress = 1.0;
      _batchStatus = 'Upload complete (2 images added)';
      _photos.addAll([
        const GalleryPhoto(
          id: 'gallery_add_1',
          url: 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80',
          fileName: 'Outdoor Lawn Setup',
          fileSizeFormatted: '1.4 MB',
        ),
        const GalleryPhoto(
          id: 'gallery_add_2',
          url: 'https://images.unsplash.com/photo-1533105079780-92b9be482077?auto=format&fit=crop&w=1200&q=80',
          fileName: 'Rooftop Ambient Lounge',
          fileSizeFormatted: '980 KB',
        ),
      ]);
      _isBatchUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploaded 2 high-resolution photos! 🖼️')),
    );
  }

  void _showUrlInputDialog() {
    _urlInputController.clear();
    _urlInputError = null;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final urlText = _urlInputController.text.trim();
            final isValid = urlText.startsWith('http://') || urlText.startsWith('https://');

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.link, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Add Image by URL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter or paste direct link to a high-resolution space photo (JPG, PNG, WEBP):',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlInputController,
                    decoration: InputDecoration(
                      labelText: 'Image URL',
                      hintText: 'https://images.unsplash.com/...',
                      border: const OutlineInputBorder(),
                      errorText: _urlInputError,
                      suffixIcon: urlText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setDialogState(() => _urlInputController.clear()),
                            )
                          : null,
                    ),
                    onChanged: (v) => setDialogState(() => _urlInputError = null),
                  ),
                  if (isValid) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          urlText,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.Center,
                            child: const Text('Unable to preview link', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: urlText.isEmpty
                      ? null
                      : () {
                          if (!isValid) {
                            setDialogState(() {
                              _urlInputError = 'Please enter a valid HTTP/HTTPS URL';
                            });
                            return;
                          }
                          setState(() {
                            _photos.add(GalleryPhoto(
                              id: 'url_${DateTime.now().millisecondsSinceEpoch}',
                              url: urlText,
                              fileName: 'Web Image ${_photos.length + 1}',
                            ));
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image added from URL! 🔗')),
                          );
                        },
                  child: const Text('Add Image'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFullscreenLightbox(String url) {
    setState(() => _fullscreenPhotoUrl = url);

    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (ctx) {
        final currentIndex = _photos.indexWhere((p) => p.url == url);

        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.95),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              currentIndex >= 0 ? 'Photo ${currentIndex + 1} of ${_photos.length}' : 'Space Photo',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (currentIndex > 0)
                TextButton.icon(
                  icon: const Icon(Icons.star, color: Colors.amber, size: 18),
                  label: const Text('Make Cover', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    _makeCover(currentIndex);
                    Navigator.pop(ctx);
                  },
                ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white70, size: 60),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _fullscreenPhotoUrl = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(venueCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Space Listing 🏛️' : 'List Space & Media 🏛️',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submitVenue,
              child: Text(
                _isEditMode ? 'Save' : 'Publish',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    child: const Text('Back'),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _currentStep == 3 ? _submitVenue : _nextStep,
                  child: Text(
                    _currentStep == 3
                        ? (_isSaving
                            ? 'Publishing Space...'
                            : (_isEditMode
                                ? 'Update Space Listing 🚀'
                                : 'Publish Space Listing 🚀'))
                        : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Step Progress Bar Indicator
          _buildStepHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(theme, categoriesAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(ThemeData theme) {
    final steps = [
      ('1. Details', Icons.edit_note),
      ('2. Photos', Icons.photo_library),
      ('3. Media & Slots', Icons.videocam),
      ('4. Preview', Icons.preview),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.asMap().entries.map((entry) {
              final idx = entry.key;
              final (title, icon) = entry.value;
              final isCurrent = _currentStep == idx;
              final isDone = _currentStep > idx;

              return InkWell(
                onTap: () => setState(() => _currentStep = idx),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isDone
                            ? const Color(0xFF2E7D32)
                            : (isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant),
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Icon(icon, size: 13, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 4.0,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(
    ThemeData theme,
    AsyncValue<List<VenueCategory>> categoriesAsync,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Details(theme, categoriesAsync);
      case 1:
        return _buildStep2Photos(theme);
      case 2:
        return _buildStep3MediaAndSlots(theme);
      case 3:
      default:
        return _buildStep4Preview(theme);
    }
  }

  // ==========================================
  // STEP 1: BASIC DETAILS & LOCATION
  // ==========================================
  Widget _buildStep1Details(
    ThemeData theme,
    AsyncValue<List<VenueCategory>> categoriesAsync,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Space Basic Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Venue Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Venue / Property Name *',
                      hintText: 'e.g. Imperial Crystal Banquet & Lawns',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter a venue name' : null,
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description & Highlights',
                      hintText: 'Describe amenities, capacity, accessibility, and unique ambiance...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Selector
                  Text(
                    'Category (Data-Driven)',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) {
                      final validCats = categories.where((c) => c.slug != 'all' && c.isActive).toList();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: validCats.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id ||
                              _selectedCategoryId == cat.slug;
                          return FilterChip(
                            label: Text('${cat.icon?.isNotEmpty == true ? cat.icon! : "🏷️"} ${cat.name}'),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedCategoryId = cat.id);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Banquet Hall'),
                          selected: _selectedCategoryId == 'banquet',
                          onSelected: (_) => setState(() => _selectedCategoryId = 'banquet'),
                        ),
                        FilterChip(
                          label: const Text('Party Lawn'),
                          selected: _selectedCategoryId == 'lawn',
                          onSelected: (_) => setState(() => _selectedCategoryId = 'lawn'),
                        ),
                        FilterChip(
                          label: const Text('Conference Room'),
                          selected: _selectedCategoryId == 'conference',
                          onSelected: (_) => setState(() => _selectedCategoryId = 'conference'),
                        ),
                        FilterChip(
                          label: const Text('Co-Working Space'),
                          selected: _selectedCategoryId == 'coworking',
                          onSelected: (_) => setState(() => _selectedCategoryId = 'coworking'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Base Price & Capacity
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹) *',
                            hintText: 'e.g. 35000',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter price';
                            if (double.tryParse(v) == null) return 'Valid number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Guests / Capacity *',
                            hintText: 'e.g. 500',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter capacity';
                            if (int.tryParse(v) == null) return 'Valid integer';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Location Information Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location & Landmark Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address / Landmark',
                      hintText: 'Plot 42, Hitech City Main Road, Madhapur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Pincode',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: HIGH-QUALITY PHOTO GALLERY
  // ==========================================
  Widget _buildStep2Photos(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '2. High-Quality Photo Gallery',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_photos.length} Photos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Add high-resolution photos. The first image is the main Cover Photo. Tap to view fullscreen or use arrows to reorder.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),

                // Multi-image Concurrent Batch Upload Progress Bar Card
                if (_isBatchUploading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _batchStatus,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(_batchProgress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _batchProgress,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),

                // Empty State or Gallery List
                if (_photos.isEmpty)
                  InkWell(
                    onTap: _showAddPhotoSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 36, color: theme.colorScheme.primary),
                          const SizedBox(height: 4),
                          const Text('No photos added yet', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'Tap to take photo, choose from gallery, or add URL',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, idx) {
                        final photo = _photos[idx];
                        final isCover = idx == 0;

                        return Container(
                          width: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCover
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: isCover ? 2 : 1,
                            ),
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image Thumbnail
                              Expanded(
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showFullscreenLightbox(photo.url),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: Image.network(
                                            photo.url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Colors.grey.shade300,
                                              alignment: Alignment.Center,
                                              child: const Icon(Icons.broken_image),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Cover Badge
                                    if (isCover)
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star, size: 10, color: Colors.white),
                                              SizedBox(width: 2),
                                              Text(
                                                'COVER',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Delete Button
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () => _removePhoto(idx),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Controls Row: Left, #Index, Right
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.keyboard_arrow_left, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: idx > 0 ? () => _movePhotoLeft(idx) : null,
                                    ),
                                    Text(
                                      '#${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.keyboard_arrow_right, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: idx < _photos.length - 1
                                          ? () => _movePhotoRight(idx)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),
                // Primary Add Photos Button
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('+ Add Photos (Camera, Gallery, URL)'),
                  onPressed: _showAddPhotoSheet,
                ),
                const SizedBox(height: 12),
                // Presets
                Text(
                  'Or tap to add preset HD venue shots:',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _presetImages.map((preset) {
                    final (presetUrl, title) = preset;
                    return ActionChip(
                      label: Text('+ $title', style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        if (_photos.none((p) => p.url == presetUrl)) {
                          setState(() {
                            _photos.add(GalleryPhoto(
                              id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
                              url: presetUrl,
                              fileName: title,
                            ));
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added $title shot!')),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: MEDIA (VIDEO & 3D TOUR) & SLOTS
  // ==========================================
  Widget _buildStep3MediaAndSlots(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video & 3D Walkthrough
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3. Video Walkthrough & 3D / 360° Virtual Tour',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Allow clients to take interactive virtual tours and short video walkthroughs before booking.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _videoTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Video Walkthrough Title',
                    hintText: 'e.g. 4K Cinematic Grand Ballroom Tour',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _videoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Video File URL (MP4 / Web Video)',
                    hintText: 'https://storage.googleapis.com/venues/tour.mp4',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tour3dUrlController,
                  decoration: const InputDecoration(
                    labelText: '3D / 360° Virtual Tour URL',
                    hintText: 'https://matterport.com/discover/space/...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tour3dHotspotsController,
                  decoration: const InputDecoration(
                    labelText: '3D Tour Hotspots (Comma-separated)',
                    hintText: 'Grand Entrance, Main Lawn, Ballroom, Dining Area',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Time Slots & Session Pricing
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operating Time Slots & Pricing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select available slots and verify base session pricing:',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                ..._slots.map((slot) {
                  return CheckboxListTile(
                    value: slot.isSelected,
                    contentPadding: EdgeInsets.zero,
                    title: Text(slot.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text('${slot.timing} • ₹${slot.price.toInt()} / session'),
                    onChanged: (val) {
                      setState(() => slot.isSelected = val ?? false);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Facilities & Amenities
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Facilities & Space Amenities',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _facilities.keys.map((fName) {
                    final isChecked = _facilities[fName] ?? false;
                    return FilterChip(
                      label: Text(fName, style: const TextStyle(fontSize: 12)),
                      selected: isChecked,
                      onSelected: (val) {
                        setState(() => _facilities[fName] = val);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4: REVIEW & LIVE PREVIEW
  // ==========================================
  Widget _buildStep4Preview(ThemeData theme) {
    final name = _nameController.text.trim().isEmpty ? 'Space Title' : _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 35000.0;
    final capacity = int.tryParse(_capacityController.text) ?? 500;
    final city = _cityController.text.trim().isEmpty ? 'Hyderabad' : _cityController.text.trim();
    final address = _addressController.text.trim();
    final coverUrl = _photos.isNotEmpty
        ? _photos.first.url
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1200&q=80';

    final activeFacilities = _facilities.entries.where((e) => e.value).map((e) => e.key).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Space Customer Preview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '● Live Preview Mode',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mock Venue Card matching customer app
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image with Badges
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.Center,
                        child: const Icon(Icons.stadium, size: 50),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedCategoryId.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Verified Partner',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? '$address, $city' : city,
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pricing per slot', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '₹${price.toInt()}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people, size: 16),
                              const SizedBox(width: 6),
                              Text('Max $capacity Guests', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_descriptionController.text.trim().isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        _descriptionController.text.trim(),
                        style: const TextStyle(fontSize: 12.5),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (activeFacilities.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: activeFacilities.take(5).map((f) {
                          return Chip(
                            label: Text(f, style: const TextStyle(fontSize: 10.5)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
