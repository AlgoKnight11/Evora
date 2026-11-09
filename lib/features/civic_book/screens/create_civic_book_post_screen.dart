import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/evora_colors.dart';
import '../services/civic_book_service.dart';

class CreateCivicBookPostScreen extends ConsumerStatefulWidget {
  const CreateCivicBookPostScreen({super.key});

  @override
  ConsumerState<CreateCivicBookPostScreen> createState() =>
      _CreateCivicBookPostScreenState();
}

class _CreateCivicBookPostScreenState
    extends ConsumerState<CreateCivicBookPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'waste';
  File? _selectedImage;
  bool _isSubmitting = false;

  final List<({String key, String label, IconData icon})> _categories = const [
    (key: 'waste', label: 'Solid Waste', icon: Icons.delete_outline),
    (key: 'roads', label: 'Roads & Potholes', icon: Icons.add_road_outlined),
    (key: 'water', label: 'Water Leakage', icon: Icons.water_drop_outlined),
    (key: 'lights', label: 'Street Lighting', icon: Icons.lightbulb_outline),
    (key: 'greenery', label: 'Greenery / Trees', icon: Icons.park_outlined),
    (key: 'general', label: 'General Civic', icon: Icons.campaign_outlined),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    // Permission disclosure dialog before accessing Camera / Gallery
    final isCamera = source == ImageSource.camera;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EvoraColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCamera ? Icons.camera_alt_outlined : Icons.photo_library_outlined,
              color: EvoraColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              isCamera ? 'Camera Access' : 'Photo Gallery Access',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          isCamera
              ? 'EVORA requests camera access to photograph local civic and environmental issues on the ground for community verification.'
              : 'EVORA requests gallery access so you can select and upload existing photos of civic issues.',
          style: const TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow & Open'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${isCamera ? "camera" : "gallery"}: $e'),
            backgroundColor: EvoraColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitObservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final success = await ref.read(civicBookProvider.notifier).createPost(
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory,
      imageFile: _selectedImage,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observation posted successfully to CivicBook!'),
          backgroundColor: EvoraColors.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(civicBookProvider).userLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Observation'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Locality Banner with Privacy Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EvoraColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, color: EvoraColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location: ${location.localityName}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const Text(
                              'Coordinates are generalized (~100m) to preserve your privacy.',
                              style: TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Headline / Summary',
                    hintText: 'e.g., Blocked stormwater drain near Rajpur Road',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? 'Please enter a clear title (min 5 chars)' : null,
                ),
                const SizedBox(height: 16),

                // Category Selector
                const Text(
                  'Select Issue Category',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final isSelected = _selectedCategory == c.key;
                    return ChoiceChip(
                      avatar: Icon(c.icon, size: 16, color: isSelected ? Colors.white : EvoraColors.primary),
                      label: Text(c.label),
                      selected: isSelected,
                      selectedColor: EvoraColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : EvoraColors.onSurface,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = c.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Description Input
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observation Details',
                    hintText: 'Describe what you noticed, landmark clues, or severity for your neighbors...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 10) ? 'Please provide a brief description (min 10 chars)' : null,
                ),
                const SizedBox(height: 20),

                // Photo Attachment Box
                const Text(
                  'Attach Photo Proof (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take Photo'),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('From Gallery'),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitObservation,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Post to CivicBook Feed'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
