import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../domain/owner_venue_repository.dart';
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
    this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.price,
    this.isSelected = true,
  });

  final String? id;
  final String title;
  final String startTime;
  final String endTime;
  final double price;
  bool isSelected;

  String get timing {
    final start = startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
    final end = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
    return '$start - $end';
  }
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
  List<VenueBlockedDate> _blockedDates = [];
  final _picker = ImagePicker();
  bool _uploadingImage = false;

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
    _cityController = TextEditingController(text: ev?.city ?? '');
    _stateController = TextEditingController(text: ev?.state ?? '');
    _pincodeController = TextEditingController(text: ev?.pincode ?? '');
    _latController = TextEditingController(
      text: ev != null && ev.latitude != 0 ? ev.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: ev != null && ev.longitude != 0 ? ev.longitude.toString() : '',
    );

    _videoTitleController =
        TextEditingController(text: 'Virtual Walkthrough Tour');
    _videoUrlController = TextEditingController();
    _tour3dUrlController = TextEditingController();
    _tour3dHotspotsController = TextEditingController(
        text: 'Grand Entrance, Main Ballroom, Dining Area');

    if (ev?.category != null && ev!.category!.id.isNotEmpty) {
      _selectedCategoryId = ev.category!.id;
    }

    if (ev != null && ev.images.isNotEmpty) {
      _photos = ev.images.asMap().entries.map((entry) {
        return GalleryPhoto(
          id: entry.value.id.isNotEmpty ? entry.value.id : 'img_${entry.key}',
          url: entry.value.url,
          fileName: 'Venue Photo ${entry.key + 1}',
          isCover: entry.key == 0 || entry.value.isCover,
        );
      }).toList();
    } else {
      _photos = [];
    }

    if (ev != null && ev.facilities.isNotEmpty) {
      for (final f in ev.facilities) {
        _facilities[f.facility] = f.isAvailable;
      }
    }

    final baseAmount = double.tryParse(_priceController.text) ?? 35000.0;
    _slots = [
      OperatingSlot(
        title: 'Morning Session',
        startTime: '08:00:00',
        endTime: '14:00:00',
        price: (baseAmount * 0.6).roundToDouble(),
      ),
      OperatingSlot(
        title: 'Evening Gala / Reception',
        startTime: '16:00:00',
        endTime: '23:30:00',
        price: baseAmount,
      ),
      OperatingSlot(
        title: 'Full Day Exclusive Access',
        startTime: '00:00:00',
        endTime: '23:59:00',
        price: (baseAmount * 1.5).roundToDouble(),
        isSelected: false,
      ),
    ];

    if (ev != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAvailability(ev.id);
      });
    }
  }

  Future<void> _loadAvailability(String venueId) async {
    try {
      final repo = ref.read(ownerVenueRepositoryProvider);
      final slots = await repo.listTimeSlots(venueId);
      final blocked = await repo.listBlockedDates(venueId);
      if (!mounted) return;
      setState(() {
        if (slots.isNotEmpty) {
          _slots = slots
              .map(
                (slot) => OperatingSlot(
                  id: slot.id,
                  title: slot.label,
                  startTime: slot.startTime,
                  endTime: slot.endTime,
                  price: slot.priceAmount,
                  isSelected: slot.isActive,
                ),
              )
              .toList();
        }
        _blockedDates = blocked;
      });
    } catch (_) {
      // Availability editors remain usable with local defaults.
    }
  }

  Future<void> _addBlockedDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (range == null || !mounted) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reason (optional)'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Maintenance, private event, ...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (!mounted || reason == null) return;
    final dates = <VenueBlockedDate>[];
    for (var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))) {
      final exists = _blockedDates.any((item) =>
          item.date.year == day.year &&
          item.date.month == day.month &&
          item.date.day == day.day);
      if (!exists) {
        dates.add(VenueBlockedDate(
          date: DateTime(day.year, day.month, day.day),
          reason: reason.isEmpty ? null : reason,
        ));
      }
    }
    setState(() => _blockedDates = [..._blockedDates, ...dates]);
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
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (city.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('City, latitude, and longitude are required.'),
        ),
      );
      setState(() {
        _isSaving = false;
        _currentStep = 0;
      });
      return;
    }

    final venueImages = _photos.asMap().entries.map((entry) {
      return VenueImage(
        id: 'img_${entry.key}',
        url: entry.value.url,
        altText: entry.value.fileName,
        isCover: entry.key == 0,
        sortOrder: entry.key,
      );
    }).toList();

    final selectedFacilities =
        _facilities.entries.where((e) => e.value).map((e) => e.key).toList();

    try {
      late final Venue saved;
      if (_isEditMode) {
        saved = await ref.read(
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
      } else {
        saved = await ref.read(
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
      }
      final repo = ref.read(ownerVenueRepositoryProvider);
      await repo.replaceTimeSlots(
        saved.id,
        _slots
            .map(
              (slot) => TimeSlotDraft(
                id: slot.id,
                label: slot.title,
                startTime: slot.startTime,
                endTime: slot.endTime,
                priceAmount: slot.price,
                isActive: slot.isSelected,
              ),
            )
            .toList(),
      );
      await repo.replaceBlockedDates(saved.id, _blockedDates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isEditMode ? Icons.check_circle : Icons.celebration,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditMode
                      ? 'Updated "$name" successfully!'
                      : 'Space "$name" published successfully!',
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        context.pop();
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

  Future<void> _removePhoto(int index) async {
    final photo = _photos[index];
    setState(() {
      _photos.removeAt(index);
    });
    try {
      await ref.read(ownerVenueRepositoryProvider).deleteStoredImage(photo.url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete stored image: $error')),
      );
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The selected image is invalid.')),
          );
        }
        return;
      }
      setState(() {
        _uploadingImage = true;
        _isBatchUploading = true;
        _batchProgress = 0.35;
        _batchStatus = 'Uploading to Supabase Storage...';
      });
      final url = await ref.read(
        uploadOwnerVenueImageProvider((
          bytes: bytes,
          fileName: picked.name,
          contentType: picked.mimeType,
        )).future,
      );
      if (!mounted) return;
      setState(() {
        _photos.add(
          GalleryPhoto(
            id: 'img_${DateTime.now().microsecondsSinceEpoch}',
            url: url,
            fileName: picked.name,
            fileSizeFormatted: '${(bytes.length / 1024).round()} KB',
          ),
        );
        _uploadingImage = false;
        _isBatchUploading = false;
        _batchProgress = 1;
        _batchStatus = 'Upload complete';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _isBatchUploading = false;
      });
      final denied = error.code.toLowerCase().contains('denied') ||
          error.code.toLowerCase().contains('permission');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? 'Permission denied. Enable camera or photos in Settings.'
                : 'Could not pick image: ${error.message ?? error.code}',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _pickAndUpload(source),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _isBatchUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _pickAndUpload(source),
          ),
        ),
      );
    }
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
                                color:
                                    Theme.of(ctx).colorScheme.onSurfaceVariant,
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
                    child: Icon(Icons.camera_alt,
                        color: Theme.of(ctx).colorScheme.primary),
                  ),
                  title: const Text('Take Live Photo 📷',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Capture space highlights using camera'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                // Device Gallery / Presets
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.secondaryContainer,
                    child: Icon(Icons.photo_library,
                        color: Theme.of(ctx).colorScheme.secondary),
                  ),
                  title: const Text('Choose from Gallery 🖼️',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'Select photos and upload to Supabase Storage'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                // URL input
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.tertiaryContainer,
                    child: Icon(Icons.link,
                        color: Theme.of(ctx).colorScheme.tertiary),
                  ),
                  title: const Text('Add by Web URL 🔗',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showUrlInputDialog() {
    _urlInputController.clear();
    _urlInputError = null;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final urlText = _urlInputController.text.trim();
            final isValid =
                urlText.startsWith('http://') || urlText.startsWith('https://');

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.link, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Add Image by URL',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                      hintText: 'https://cdn.example.com/venue.jpg',
                      border: const OutlineInputBorder(),
                      errorText: _urlInputError,
                      suffixIcon: urlText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setDialogState(
                                  () => _urlInputController.clear()),
                            )
                          : null,
                    ),
                    onChanged: (v) =>
                        setDialogState(() => _urlInputError = null),
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
                            alignment: Alignment.center,
                            child: const Text('Unable to preview link',
                                style: TextStyle(fontSize: 11)),
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
                              _urlInputError =
                                  'Please enter a valid HTTP/HTTPS URL';
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
                            const SnackBar(
                                content: Text('Image added from URL! 🔗')),
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
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (ctx) {
        final currentIndex = _photos.indexWhere((p) => p.url == url);

        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              currentIndex >= 0
                  ? 'Photo ${currentIndex + 1} of ${_photos.length}'
                  : 'Space Photo',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            actions: [
              if (currentIndex > 0)
                TextButton.icon(
                  icon: const Icon(Icons.star, color: Colors.amber, size: 18),
                  label: const Text('Make Cover',
                      style: TextStyle(color: Colors.white)),
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
                  child:
                      Icon(Icons.broken_image, color: Colors.white70, size: 60),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {});
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
                color: Colors.black.withValues(alpha: 0.05),
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Icon(icon, size: 13, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
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
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a venue name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description & Highlights',
                      hintText:
                          'Describe amenities, capacity, accessibility, and unique ambiance...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Selector
                  Text(
                    'Category (Data-Driven)',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) {
                      final validCats = categories
                          .where((c) => c.slug != 'all' && c.isActive)
                          .toList();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: validCats.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id ||
                              _selectedCategoryId == cat.slug;
                          return FilterChip(
                            label: Text(
                                '${cat.icon?.isNotEmpty == true ? cat.icon! : "🏷️"} ${cat.name}'),
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
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = 'banquet'),
                        ),
                        FilterChip(
                          label: const Text('Party Lawn'),
                          selected: _selectedCategoryId == 'lawn',
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = 'lawn'),
                        ),
                        FilterChip(
                          label: const Text('Conference Room'),
                          selected: _selectedCategoryId == 'conference',
                          onSelected: (_) => setState(
                              () => _selectedCategoryId = 'conference'),
                        ),
                        FilterChip(
                          label: const Text('Co-Working Space'),
                          selected: _selectedCategoryId == 'coworking',
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = 'coworking'),
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
                            if (v == null || v.trim().isEmpty)
                              return 'Enter price';
                            if (double.tryParse(v) == null)
                              return 'Valid number';
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
                            if (v == null || v.trim().isEmpty)
                              return 'Enter capacity';
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter city'
                              : null,
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _batchStatus,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(_batchProgress * 100).toInt()}%',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
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
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 36, color: theme.colorScheme.primary),
                          const SizedBox(height: 4),
                          const Text('No photos added yet',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'Tap to take photo, choose from gallery, or add URL',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant),
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
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image Thumbnail
                              Expanded(
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _showFullscreenLightbox(photo.url),
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: Image.network(
                                            photo.url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey.shade300,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                  Icons.broken_image),
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star,
                                                  size: 10,
                                                  color: Colors.white),
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
                                          child: const Icon(Icons.close,
                                              size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Controls Row: Left, #Index, Right
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.keyboard_arrow_left,
                                          size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: idx > 0
                                          ? () => _movePhotoLeft(idx)
                                          : null,
                                    ),
                                    Text(
                                      '#${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.keyboard_arrow_right,
                                          size: 18),
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
                  onPressed: _uploadingImage ? null : _showAddPhotoSheet,
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
                    hintText:
                        'Grand Entrance, Main Lawn, Ballroom, Dining Area',
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                ..._slots.map((slot) {
                  return CheckboxListTile(
                    value: slot.isSelected,
                    contentPadding: EdgeInsets.zero,
                    title: Text(slot.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(
                        '${slot.timing} • ₹${slot.price.toInt()} / session'),
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
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocked dates',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Blocked dates cannot be held or booked by customers.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (_blockedDates.isEmpty)
                  const Text('No blocked dates yet.')
                else
                  ..._blockedDates.map((item) {
                    final label =
                        '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(label),
                      subtitle: item.reason == null || item.reason!.isEmpty
                          ? null
                          : Text(item.reason!),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() => _blockedDates.remove(item));
                        },
                      ),
                    );
                  }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addBlockedDateRange,
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Block dates'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Facilities & Amenities
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final name = _nameController.text.trim().isEmpty
        ? 'Space Title'
        : _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 35000.0;
    final capacity = int.tryParse(_capacityController.text) ?? 500;
    final city =
        _cityController.text.trim().isEmpty ? 'City' : _cityController.text.trim();
    final address = _addressController.text.trim();
    final coverUrl = _photos.isNotEmpty ? _photos.first.url : '';

    final activeFacilities =
        _facilities.entries.where((e) => e.value).map((e) => e.key).toList();

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
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mock Venue Card matching customer app
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                        alignment: Alignment.center,
                        child: const Icon(Icons.stadium, size: 50),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedCategoryId.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
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
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? '$address, $city' : city,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant),
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
                            const Text('Pricing per slot',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people, size: 16),
                              const SizedBox(width: 6),
                              Text('Max $capacity Guests',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
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
                            label:
                                Text(f, style: const TextStyle(fontSize: 10.5)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
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
