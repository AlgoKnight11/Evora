import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../services/location_service.dart';
import '../../auth/services/auth_service.dart';
import '../services/civic_flow_service.dart';

class CivicFlowWizardScreen extends ConsumerStatefulWidget {
  final String? sourcePostId;
  final String? initialCategory;
  final String? initialTitle;
  final String? initialLocality;

  const CivicFlowWizardScreen({
    super.key,
    this.sourcePostId,
    this.initialCategory,
    this.initialTitle,
    this.initialLocality,
  });

  @override
  ConsumerState<CivicFlowWizardScreen> createState() =>
      _CivicFlowWizardScreenState();
}

class _CivicFlowWizardScreenState extends ConsumerState<CivicFlowWizardScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  String _selectedCategory = 'Solid Waste';
  String _selectedSubcategory = 'Garbage Dump Overflow';
  final _descController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _localityController = TextEditingController();
  File? _imageFile;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  final Map<String, List<String>> _taxonomy = {
    'Solid Waste': [
      'Garbage Dump Overflow',
      'Uncollected Door-to-Door Waste',
      'Hazardous / Medical Waste Dumping',
      'Dead Animal Removal',
      'Plastic Waste in Stream/Canal',
    ],
    'Roads & Footpaths': [
      'Dangerous Pothole',
      'Damaged Pedestrian Footpath',
      'Missing Manhole Cover',
      'Road Cave-in / Landslide Debris',
      'Illegal Road Encroachment',
    ],
    'Drainage & Waterlogging': [
      'Blocked Stormwater Drain',
      'Monsoon Waterlogging',
      'Sewage Overflow on Street',
      'Broken Drain Slab',
    ],
    'Street Lighting': [
      'Streetlight Completely Off',
      'Flickering Light Pole',
      'Exposed Electrical Wiring',
      'Damaged Electric Pole',
    ],
    'Water Supply': [
      'Main Pipeline Leakage / Wastage',
      'Contaminated / Turbid Tap Water',
      'No Municipal Water Supply',
      'Low Pressure Supply',
    ],
    'Public Sanitation': [
      'Unsanitary Public Toilet',
      'Open Urination Hotspot',
      'Stagnant Dirty Water Puddle',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      final matchingKey = _taxonomy.keys.firstWhere(
        (k) => k.toLowerCase().contains(widget.initialCategory!.toLowerCase()),
        orElse: () => 'Solid Waste',
      );
      _selectedCategory = matchingKey;
      _selectedSubcategory = _taxonomy[matchingKey]!.first;
    }
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _descController.text = widget.initialTitle!;
    }
    if (widget.initialLocality != null && widget.initialLocality!.isNotEmpty) {
      _localityController.text = widget.initialLocality!;
    } else {
      final loc = LocationService.currentLocation;
      final userLocality = ref.read(authProvider).user?.selectedLocality;
      _localityController.text = loc.isLiveGps
          ? loc.localityName
          : (userLocality != null && userLocality.isNotEmpty
              ? userLocality
              : loc.localityName);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _landmarkController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final isCamera = source == ImageSource.camera;

    // Explicit Device Access Permission Dialog
    final allowed = await showDialog<bool>(
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
              isCamera ? 'Camera Access Required' : 'Photo Gallery Access',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isCamera
              ? 'EVORA requires camera access to photograph physical proof of this municipal grievance. Photo EXIF metadata will be stripped before submission.'
              : 'EVORA requires gallery access so you can attach existing photographic evidence.',
          style: const TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow & Open')),
        ],
      ),
    );

    if (allowed != true) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open ${isCamera ? "camera" : "gallery"}: $e')),
        );
      }
    }
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final caseNumber = await ref.read(civicFlowProvider.notifier).submitCase(
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      description: _descController.text,
      locality: _localityController.text,
      landmark: _landmarkController.text,
      imageFile: _imageFile,
      sourceCivicBookPostId: widget.sourcePostId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (caseNumber != null) {
      _showSuccessDialog(caseNumber);
    }
  }

  void _showSuccessDialog(String caseNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: EvoraColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: EvoraColors.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EvoraColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: EvoraColors.primary, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Grievance Registered Successfully!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: EvoraColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  caseNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: EvoraColors.primary,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your case has been forwarded to the municipal control desk. You will receive real-time updates as field officers inspect and assign your case.',
                style: TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/civic-flow');
                },
                child: const Text('View All My Cases'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final civicFlowState = ref.watch(civicFlowProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Formal Grievance'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepTapped: (step) => setState(() => _currentStep = step),
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _submitCase();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                context.pop();
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || civicFlowState.isRateLimited) ? null : details.onStepContinue,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_currentStep == 2 ? 'Submit Formal Grievance' : 'Next Step'),
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: [
              // Step 1: Category & Subcategory
              Step(
                title: const Text('Category'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.sourcePostId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EvoraColors.tertiaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EvoraColors.tertiary.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt, color: EvoraColors.tertiary, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Escalating from CivicBook Community Post',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: EvoraColors.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text('Select Grievance Category', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                      items: _taxonomy.keys.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                            _selectedSubcategory = _taxonomy[val]!.first;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Specific Issue Type', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sub_$_selectedCategory'),
                      initialValue: _selectedSubcategory,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.subdirectory_arrow_right)),
                      items: _taxonomy[_selectedCategory]!.map((sub) {
                        return DropdownMenuItem(value: sub, child: Text(sub, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubcategory = val);
                      },
                    ),
                  ],
                ),
              ),

              // Step 2: Visual Proof & Location
              Step(
                title: const Text('Proof & Place'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Photographic Evidence', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_imageFile != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_imageFile!, height: 180, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                onPressed: () => setState(() => _imageFile = null),
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
                              label: const Text('Gallery'),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const Text('Locality / Ward', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _localityController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Dehradun Central, Ward 4',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a locality' : null,
                    ),
                    const SizedBox(height: 14),
                    const Text('Nearby Landmark', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _landmarkController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Opposite BSNL Exchange, near Clock Tower',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                  ],
                ),
              ),

              // Step 3: Description & Final Review
              Step(
                title: const Text('Review'),
                isActive: _currentStep >= 2,
                state: StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (civicFlowState.isRateLimited) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EvoraColors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Anti-Spam Rate Limit Active: Please wait ${civicFlowState.rateLimitCooldownSeconds}s before filing another case.',
                          style: const TextStyle(color: EvoraColors.onErrorContainer, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text('Detailed Description of Grievance', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Provide complete details (duration of problem, safety impact, exact location clues)...',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 15) ? 'Please provide detailed description (min 15 chars)' : null,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: EvoraColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Summary Checklist:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('• Category: $_selectedCategory — $_selectedSubcategory', style: const TextStyle(fontSize: 12)),
                          Text('• Locality: ${_localityController.text}', style: const TextStyle(fontSize: 12)),
                          Text('• Photo Evidence: ${_imageFile != null ? "Attached (EXIF stripped)" : "None"}', style: const TextStyle(fontSize: 12)),
                          const Text('• Tracking: Official 10-stage municipal timeline assigned upon submission', style: TextStyle(fontSize: 12, color: EvoraColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
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
