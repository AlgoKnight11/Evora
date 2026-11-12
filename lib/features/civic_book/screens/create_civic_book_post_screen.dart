import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../services/ai_gateway_service.dart';
import '../../../services/device_permission_service.dart';
import '../../../services/pii_redaction_service.dart';
import '../../ai_engine/models/civic_ai_models.dart';
import '../../ai_engine/services/duplicate_detector_service.dart';
import '../../ai_engine/widgets/duplicate_alert_sheet.dart';
import '../../auth/services/auth_service.dart';
import '../../civic_flow/models/civic_taxonomy.dart';
import '../../civic_flow/services/civic_flow_service.dart';
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
  Uint8List? _preparedBytes;
  bool _isAnalyzingAi = false;
  bool _isSubmitting = false;
  String? _aiBanner;
  bool _aiBannerWarning = false;
  CivicVisionAnalysis? _analysis;
  PiiRedactionResult? _redactionResult;
  List<double>? _cachedEmbedding;
  bool _titleEdited = false;
  bool _descEdited = false;

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
    final isCamera = source == ImageSource.camera;
    final granted = isCamera
        ? await DevicePermissionService.ensureCameraPermission()
        : await DevicePermissionService.ensureGalleryPermission();

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCamera
                  ? 'Camera permission is required to capture civic photos.'
                  : 'Photo gallery permission is required to choose civic photos.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (!mounted || picked == null) return;
      await _analyzeAndScrubPhoto(File(picked.path));
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

  Future<void> _analyzeAndScrubPhoto(File rawFile) async {
    setState(() {
      _selectedImage = rawFile;
      _isAnalyzingAi = true;
      _aiBanner = null;
      _aiBannerWarning = false;
      _cachedEmbedding = null;
    });

    try {
      final gateway = ref.read(aiGatewayProvider);
      final rawBytes = await rawFile.readAsBytes();
      final compressed = await PiiRedactionService.compressAndStripExif(rawBytes);

      if (!mounted) return;

      if (!gateway.isConfigured) {
        final scrubbed = await PiiRedactionService.redactFileToTemp(
          sourceFile: rawFile,
          regions: const [],
          precompressedBytes: compressed,
        );
        if (!mounted) return;
        setState(() {
          _selectedImage = scrubbed.file ?? rawFile;
          _preparedBytes = Uint8List.fromList(scrubbed.bytes);
          _redactionResult = scrubbed;
          _isAnalyzingAi = false;
          _aiBanner =
              'EXIF stripped locally. Save GEMINI_API_KEY in .env to enable AI photo auto-fill & PII blurring.';
          _aiBannerWarning = true;
        });
        return;
      }

      final analysis = await gateway.analyzeCivicIssueImage(
        imageBytes: compressed,
        userDescriptionHint: '${_titleController.text} ${_descController.text}',
        localityHint: ref.read(civicBookProvider).userLocation.localityName,
        compressImage: false,
      );

      final redaction = await PiiRedactionService.redactFileToTemp(
        sourceFile: rawFile,
        regions: analysis.piiRegions,
        precompressedBytes: compressed,
      );

      if (!mounted) return;

      setState(() {
        _analysis = analysis;
        _redactionResult = redaction;
        _selectedImage = redaction.file ?? rawFile;
        _preparedBytes = Uint8List.fromList(redaction.bytes);
        _isAnalyzingAi = false;

        if (!analysis.isValidCivicIssue) {
          _aiBanner = analysis.rejectionReason ??
              'Photo may not depict a clear outdoor civic observation.';
          _aiBannerWarning = true;
        } else {
          _selectedCategory = analysis.civicBookCategoryKey;
          if (!_titleEdited || _titleController.text.trim().isEmpty) {
            _titleController.text = analysis.suggestedTitle;
          }
          if (!_descEdited || _descController.text.trim().isEmpty) {
            _descController.text = analysis.suggestedDescription;
          }
          final piiNote = redaction.hasRedactions
              ? ' • Blurred ${redaction.facesBlurred} face(s), ${redaction.platesBlurred} plate(s)'
              : '';
          final deptNote = analysis.isMultiDepartment
              ? ' • ${analysis.requiredDepartments.length} depts relevant'
              : '';
          _aiBanner =
              'AI Suggested: ${analysis.category} (${analysis.confidencePercent}%)$deptNote$piiNote';
          _aiBannerWarning = false;
        }
      });
    } on AiGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _aiBanner = e.message;
        _aiBannerWarning = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _aiBanner = 'AI auto-fill unavailable right now. Please enter details manually.';
        _aiBannerWarning = true;
      });
    }
  }

  Future<void> _submitObservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final gateway = ref.read(aiGatewayProvider);
    final detector = ref.read(duplicateDetectorProvider);
    final location = ref.read(civicBookProvider).userLocation;

    List<double>? embedding = _cachedEmbedding;
    if (embedding == null && gateway.isConfigured) {
      embedding = await gateway.generateEmbedding(
        text: '${_titleController.text} ${_descController.text}',
        imageBytes: _preparedBytes,
      );
      _cachedEmbedding = embedding;
    }

    final flowCategory = CivicTaxonomy.fromCivicBookKey(_selectedCategory);
    final duplicates = await detector.findNearbyDuplicates(
      latitude: location.latitude,
      longitude: location.longitude,
      category: flowCategory,
      subcategory: _analysis?.subcategory ?? CivicTaxonomy.categories[flowCategory]!.first,
      summaryText: '${_titleController.text} ${_descController.text}',
      embeddingVector: embedding,
      inMemoryCases: ref.read(civicFlowProvider).citizenCases,
      inMemoryPosts: ref.read(civicBookProvider).allPosts,
    );

    if (!mounted) return;

    if (duplicates.isNotEmpty) {
      setState(() => _isSubmitting = false);
      final resolution = await DuplicateAlertSheet.show(
        context,
        candidates: duplicates,
        onSupportCandidate: (candidate) async {
          if (candidate.sourceType == 'civic_flow_case') {
            await ref
                .read(civicFlowProvider.notifier)
                .supportExistingCase(candidate.sourceId);
          } else {
            await ref
                .read(civicBookProvider.notifier)
                .toggleVote(candidate.sourceId, 1);
          }
        },
      );

      if (!mounted) return;
      if (resolution.resolution == DuplicateAlertResolution.supportedExisting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upvoted/supported existing nearby observation instead!'),
            backgroundColor: EvoraColors.primary,
          ),
        );
        context.pop();
        return;
      } else if (resolution.resolution == DuplicateAlertResolution.cancelled) {
        return;
      }

      setState(() => _isSubmitting = true);
    }

    final success = await ref.read(civicBookProvider.notifier).createPost(
      title: _titleController.text,
      description: _descController.text,
      category: _selectedCategory,
      imageFile: _selectedImage,
      embeddingVector: embedding,
      piiRedactedCount: _redactionResult?.totalRedacted ?? 0,
      requiredDepartments: _analysis?.requiredDepartments ?? const [],
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
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
    final isAuthenticated = ref.watch(authProvider.select((s) => s.isAuthenticated));
    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Observation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_outlined, size: 56, color: EvoraColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'Sign In Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please sign in or register to post a new neighborhood observation to CivicBook.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: EvoraColors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In / Register'),
                  onPressed: () => context.push<bool>('/login?returnOnSuccess=true'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                              'Coordinates generalized (~100m); faces, plates & EXIF stripped on-device.',
                              style: TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Photo Attachment + AI Auto-Fill Box
                const Text(
                  'Attach Photo Proof (AI Auto-Fill & Privacy Blur)',
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
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (_isAnalyzingAi)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 10),
                                  Text(
                                    'AI Vision & Privacy Scrubbing...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            onPressed: _isAnalyzingAi
                                ? null
                                : () => setState(() {
                                      _selectedImage = null;
                                      _preparedBytes = null;
                                      _analysis = null;
                                      _redactionResult = null;
                                      _cachedEmbedding = null;
                                      _aiBanner = null;
                                    }),
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
                          onPressed: _isAnalyzingAi ? null : () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('From Gallery'),
                          onPressed: _isAnalyzingAi ? null : () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                if (_aiBanner != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _aiBannerWarning
                          ? Colors.orange.withValues(alpha: 0.12)
                          : EvoraColors.secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _aiBannerWarning
                            ? Colors.orange.withValues(alpha: 0.4)
                            : EvoraColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _aiBannerWarning ? Icons.info_outline : Icons.auto_awesome,
                          size: 16,
                          color: _aiBannerWarning ? Colors.orange.shade800 : EvoraColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aiBanner!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _aiBannerWarning ? Colors.orange.shade900 : EvoraColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  onChanged: (_) => _titleEdited = true,
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
                  onChanged: (_) => _descEdited = true,
                  decoration: const InputDecoration(
                    labelText: 'Observation Details',
                    hintText: 'Describe what you noticed, landmark clues, or severity for your neighbors...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 10) ? 'Please provide a brief description (min 10 chars)' : null,
                ),
                const SizedBox(height: 28),

                // Submit Button
                ElevatedButton(
                  onPressed: (_isSubmitting || _isAnalyzingAi) ? null : _submitObservation,
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
