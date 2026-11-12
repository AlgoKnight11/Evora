import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../services/ai_gateway_service.dart';
import '../../../services/device_permission_service.dart';
import '../../../services/location_service.dart';
import '../../../services/pii_redaction_service.dart';
import '../../ai_engine/models/civic_ai_models.dart';
import '../../ai_engine/services/duplicate_detector_service.dart';
import '../../ai_engine/widgets/duplicate_alert_sheet.dart';
import '../../auth/services/auth_service.dart';
import '../../civic_book/services/civic_book_service.dart';
import '../models/civic_taxonomy.dart';
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
  String _selectedPriority = 'medium';
  String _leadDepartment = CivicTaxonomy.defaultDepartmentByCategory['Solid Waste']!;
  List<String> _requiredDepartments = [
    CivicTaxonomy.defaultDepartmentByCategory['Solid Waste']!,
  ];
  Map<String, String> _departmentReasons = {};

  final _descController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _localityController = TextEditingController();

  File? _imageFile;
  Uint8List? _preparedImageBytes;
  bool _isAnalyzingAi = false;
  bool _isSubmitting = false;
  String? _statusMessage;
  String? _aiNoticeBanner;
  bool _aiNoticeIsWarning = false;
  CivicVisionAnalysis? _visionAnalysis;
  PiiRedactionResult? _redactionResult;
  List<double>? _cachedEmbedding;
  bool _descriptionEditedManually = false;
  bool _localityEditedManually = false;
  bool _isFetchingLocation = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      final matched = CivicTaxonomy.normalizeCategory(widget.initialCategory);
      _selectedCategory = matched;
      _selectedSubcategory = CivicTaxonomy.categories[matched]!.first;
      _leadDepartment = CivicTaxonomy.defaultDepartmentByCategory[matched]!;
      _requiredDepartments = [_leadDepartment];
    }
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      _descController.text = widget.initialTitle!;
      _descriptionEditedManually = true;
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

  void _syncDefaultDepartmentIfUnset(String category) {
    final defaultDept = CivicTaxonomy.defaultDepartmentByCategory[category] ??
        CivicTaxonomy.allDepartments.first;
    _leadDepartment = defaultDept;
    if (_visionAnalysis == null) {
      _requiredDepartments = [defaultDept];
      _departmentReasons = {
        defaultDept: 'Standard municipal routing for $category.',
      };
    } else if (!_requiredDepartments.contains(defaultDept)) {
      _requiredDepartments = [defaultDept, ..._requiredDepartments];
    }
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
                  ? 'Camera permission is required to capture issue photos.'
                  : 'Photo gallery permission is required to select issue photos.',
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

      final rawFile = File(picked.path);
      await _processPhotoWithAiAndPrivacy(rawFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open ${isCamera ? "camera" : "gallery"}: $e')),
        );
      }
    }
  }

  /// Phase 3 Pipeline:
  /// 1. Compress + strip EXIF locally.
  /// 2. Classify via Gemini 3.8 Flash Vision (single category + multi-department routing + PII boxes).
  /// 3. Blur detected human faces & license plates on-device BEFORE preview & upload.
  Future<void> _processPhotoWithAiAndPrivacy(File rawFile) async {
    setState(() {
      _imageFile = rawFile;
      _isAnalyzingAi = true;
      _statusMessage = 'Compressing & running AI Vision + Multi-Dept Triage...';
      _aiNoticeBanner = null;
      _aiNoticeIsWarning = false;
      _cachedEmbedding = null;
    });

    try {
      final gateway = ref.read(aiGatewayProvider);
      final rawBytes = await rawFile.readAsBytes();
      final compressedBytes = await PiiRedactionService.compressAndStripExif(rawBytes);

      if (!mounted) return;

      if (!gateway.isConfigured) {
        // Still strip EXIF via compressed temp file even when API key isn't set
        final stripped = await PiiRedactionService.redactFileToTemp(
          sourceFile: rawFile,
          regions: const [],
          precompressedBytes: compressedBytes,
        );
        if (!mounted) return;
        setState(() {
          _imageFile = stripped.file ?? rawFile;
          _preparedImageBytes = Uint8List.fromList(stripped.bytes);
          _redactionResult = stripped;
          _isAnalyzingAi = false;
          _statusMessage = null;
          _aiNoticeBanner =
              'EXIF stripped locally. Save GEMINI_API_KEY in .env to enable live AI Vision classification & PII face/plate blur.';
          _aiNoticeIsWarning = true;
        });
        return;
      }

      final analysis = await gateway.analyzeCivicIssueImage(
        imageBytes: compressedBytes,
        userDescriptionHint: _descController.text,
        localityHint: _localityController.text,
        compressImage: false,
      );

      // Run on-device PII redaction using returned face/license_plate boxes
      final redaction = await PiiRedactionService.redactFileToTemp(
        sourceFile: rawFile,
        regions: analysis.piiRegions,
        precompressedBytes: compressedBytes,
      );

      if (!mounted) return;

      setState(() {
        _visionAnalysis = analysis;
        _redactionResult = redaction;
        _imageFile = redaction.file ?? rawFile;
        _preparedImageBytes = Uint8List.fromList(redaction.bytes);
        _isAnalyzingAi = false;
        _statusMessage = null;

        if (!analysis.isValidCivicIssue) {
          _aiNoticeBanner = analysis.rejectionReason ??
              'Photo may not show a municipal civic issue. You can still retake or classify manually.';
          _aiNoticeIsWarning = true;
        } else {
          _selectedCategory = analysis.category;
          _selectedSubcategory = analysis.subcategory;
          _selectedPriority = analysis.severity;
          _leadDepartment = analysis.leadDepartment;
          _requiredDepartments = List<String>.from(analysis.requiredDepartments);
          _departmentReasons = Map<String, String>.from(analysis.departmentReasonsMap);

          if (!_descriptionEditedManually || _descController.text.trim().isEmpty) {
            _descController.text = analysis.suggestedDescription;
          }

          final piiMsg = redaction.hasRedactions
              ? ' • Blurred ${redaction.facesBlurred} face(s), ${redaction.platesBlurred} plate(s)'
              : '';
          final cacheMsg = analysis.fromCache ? ' (cached)' : '';
          _aiNoticeBanner =
              'Detected: ${analysis.category} / ${analysis.subcategory} (${analysis.confidencePercent}% confidence)$cacheMsg$piiMsg';
          _aiNoticeIsWarning = false;
        }
      });
    } on AiGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _statusMessage = null;
        _aiNoticeBanner = e.message;
        _aiNoticeIsWarning = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _statusMessage = null;
        _aiNoticeBanner = 'AI triage unavailable right now ($e). You can proceed manually.';
        _aiNoticeIsWarning = true;
      });
    }
  }

  void _clearSelectedPhoto() {
    setState(() {
      _imageFile = null;
      _preparedImageBytes = null;
      _visionAnalysis = null;
      _redactionResult = null;
      _cachedEmbedding = null;
      _aiNoticeBanner = null;
      _aiNoticeIsWarning = false;
    });
  }

  Future<void> _refreshLocationOnDemand() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    final loc = await LocationService.acquireLocation();
    if (!mounted) return;
    setState(() {
      _isFetchingLocation = false;
      if (loc.isLiveGps &&
          !_localityEditedManually &&
          (widget.initialLocality == null || widget.initialLocality!.isEmpty)) {
        _localityController.text = loc.localityName;
      }
    });
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    final civicFlowNotifier = ref.read(civicFlowProvider.notifier);
    if (ref.read(civicFlowProvider).isRateLimited) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rate limit active. Please wait ${ref.read(civicFlowProvider).rateLimitCooldownSeconds}s.',
          ),
          backgroundColor: EvoraColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Checking for similar reports within 500m...';
    });

    final gateway = ref.read(aiGatewayProvider);
    final detector = ref.read(duplicateDetectorProvider);
    final loc = LocationService.currentLocation.isLiveGps
        ? LocationService.currentLocation
        : await LocationService.acquireLocation();
    if (!mounted) return;

    final summaryForMatch =
        _visionAnalysis?.issueFingerprintText ?? '$_selectedCategory $_selectedSubcategory ${_descController.text}';

    // Generate multimodal embedding vector (image + summary) for duplicate similarity
    List<double>? embedding = _cachedEmbedding;
    if (embedding == null && gateway.isConfigured) {
      embedding = await gateway.generateEmbedding(
        text: summaryForMatch,
        imageBytes: _preparedImageBytes,
      );
      _cachedEmbedding = embedding;
    }

    final duplicates = await detector.findNearbyDuplicates(
      latitude: loc.latitude,
      longitude: loc.longitude,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      summaryText: '${_descController.text} ${_landmarkController.text}',
      embeddingVector: embedding,
      inMemoryCases: ref.read(civicFlowProvider).citizenCases,
      inMemoryPosts: ref.read(civicBookProvider).allPosts,
      excludePostId: widget.sourcePostId,
    );

    if (!mounted) return;

    if (duplicates.isNotEmpty) {
      setState(() {
        _isSubmitting = false;
        _statusMessage = null;
      });

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
          SnackBar(
            content: Text(
              'Added your support to ${resolution.selectedCandidate?.referenceLabel ?? "existing report"}!',
            ),
            backgroundColor: EvoraColors.primary,
          ),
        );
        context.go('/civic-flow');
        return;
      } else if (resolution.resolution == DuplicateAlertResolution.cancelled) {
        return;
      }

      setState(() {
        _isSubmitting = true;
        _statusMessage = 'Uploading evidence & routing departments...';
      });
    } else {
      setState(() {
        _statusMessage = 'Uploading evidence & submitting grievance...';
      });
    }

    final caseNumber = await civicFlowNotifier.submitCase(
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      description: _descController.text,
      locality: _localityController.text,
      landmark: _landmarkController.text,
      imageFile: _imageFile,
      sourceCivicBookPostId: widget.sourcePostId,
      priority: _selectedPriority,
      assignedDepartment: _leadDepartment,
      requiredDepartments: _requiredDepartments,
      departmentReasons: _departmentReasons,
      aiConfidence: _visionAnalysis?.confidence,
      piiRedactedCount: _redactionResult?.totalRedacted ?? 0,
      embeddingVector: embedding,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _statusMessage = null;
    });

    if (caseNumber != null) {
      _showSuccessDialog(caseNumber);
    }
  }

  void _showSuccessDialog(String caseNumber) {
    final isMulti = _requiredDepartments.length > 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final bottomNavInset =
            media.padding.bottom > media.viewPadding.bottom
                ? media.padding.bottom
                : media.viewPadding.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomNavInset),
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
              Text(
                isMulti
                    ? 'Routed across ${_requiredDepartments.length} municipal departments (Lead: $_leadDepartment) for coordinated resolution.'
                    : 'Your case has been routed to $_leadDepartment and queued for municipal dispatch.',
                style: const TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
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

  Widget _buildPhotoAndAiCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EvoraColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: EvoraColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Vision Triage & Privacy Shield',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              if (_redactionResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: EvoraColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 12, color: EvoraColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'EXIF Stripped',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: EvoraColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a photo first — EVORA AI auto-detects Category, Severity, Multi-Department Routing, and blurs faces/plates on-device.',
            style: TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant, height: 1.3),
          ),
          const SizedBox(height: 12),
          if (_imageFile != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    _imageFile!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_isAnalyzingAi)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _statusMessage ?? 'Analyzing with Gemini Vision...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
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
                      onPressed: _isAnalyzingAi ? null : _clearSelectedPhoto,
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
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Take Photo'),
                    onPressed: _isAnalyzingAi ? null : () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    onPressed: _isAnalyzingAi ? null : () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          if (_aiNoticeBanner != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _aiNoticeIsWarning
                    ? Colors.orange.withValues(alpha: 0.12)
                    : EvoraColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _aiNoticeIsWarning
                      ? Colors.orange.withValues(alpha: 0.4)
                      : EvoraColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _aiNoticeIsWarning
                        ? Icons.warning_amber_rounded
                        : Icons.auto_fix_high,
                    size: 16,
                    color: _aiNoticeIsWarning
                        ? Colors.orange.shade800
                        : EvoraColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_aiNoticeBanner${_aiNoticeIsWarning ? "" : " — Tap below to edit"}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _aiNoticeIsWarning
                            ? Colors.orange.shade900
                            : EvoraColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiDepartmentSelector() {
    final isMulti = _requiredDepartments.length > 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 18, color: EvoraColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMulti
                      ? 'Multi-Department Routing (${_requiredDepartments.length} Depts)'
                      : 'Department Routing (Single Dept)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('lead_$_leadDepartment'),
            initialValue: _leadDepartment,
            decoration: const InputDecoration(
              labelText: 'Lead Nodal Department',
              prefixIcon: Icon(Icons.account_balance_outlined),
              isDense: true,
            ),
            items: CivicTaxonomy.allDepartments.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(d, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _leadDepartment = val;
                  if (!_requiredDepartments.contains(val)) {
                    _requiredDepartments = [val, ..._requiredDepartments];
                  }
                });
              }
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Co-Assigned / Supporting Departments (Tap to toggle):',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: EvoraColors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CivicTaxonomy.allDepartments
                .where((d) => d != _leadDepartment)
                .map((dept) {
              final selected = _requiredDepartments.contains(dept);
              return FilterChip(
                selected: selected,
                selectedColor: EvoraColors.primary.withValues(alpha: 0.16),
                checkmarkColor: EvoraColors.primary,
                label: Text(
                  dept,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? EvoraColors.primary : EvoraColors.onSurface,
                  ),
                ),
                onSelected: (isSelected) {
                  setState(() {
                    if (isSelected) {
                      _requiredDepartments = [..._requiredDepartments, dept];
                    } else {
                      _requiredDepartments =
                          _requiredDepartments.where((d) => d != dept).toList();
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (_departmentReasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._requiredDepartments.where((d) => _departmentReasons[d]?.isNotEmpty == true).map((d) {
              final isLead = d == _leadDepartment;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${isLead ? "[Lead]" : "[Support]"} $d: ${_departmentReasons[d]}',
                  style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authProvider.select((s) => s.isAuthenticated));
    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('File Formal Grievance')),
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
                  'Please sign in or register to submit a formal municipal grievance in CivicFlow.',
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
            onStepTapped: (step) {
              setState(() => _currentStep = step);
              if (step == 1 && !LocationService.currentLocation.isLiveGps) {
                _refreshLocationOnDemand();
              }
            },
            onStepContinue: () {
              if (_currentStep < 2) {
                final nextStep = _currentStep + 1;
                setState(() => _currentStep = nextStep);
                if (nextStep == 1 && !LocationService.currentLocation.isLiveGps) {
                  _refreshLocationOnDemand();
                }
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
              final disabled = _isSubmitting || _isAnalyzingAi || civicFlowState.isRateLimited;
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_statusMessage != null && _isSubmitting) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: EvoraColors.primary,
                          ),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: disabled ? null : details.onStepContinue,
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
                            onPressed: _isSubmitting ? null : details.onStepCancel,
                            child: const Text('Back'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
            steps: [
              // Step 1: Evidence + AI Vision + Category + Multi-Department Routing
              Step(
                title: const Text('AI Triage'),
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
                    _buildPhotoAndAiCard(),
                    const SizedBox(height: 18),
                    const Text('Grievance Category', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('cat_$_selectedCategory'),
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                      items: CivicTaxonomy.categories.keys.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                            _selectedSubcategory = CivicTaxonomy.categories[val]!.first;
                            _syncDefaultDepartmentIfUnset(val);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Specific Issue Type', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sub_${_selectedCategory}_$_selectedSubcategory'),
                      initialValue: _selectedSubcategory,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.subdirectory_arrow_right)),
                      items: CivicTaxonomy.categories[_selectedCategory]!.map((sub) {
                        return DropdownMenuItem(value: sub, child: Text(sub, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubcategory = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Severity / Priority', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: const ['low', 'medium', 'high', 'urgent'].map((level) {
                        final selected = _selectedPriority == level;
                        return ChoiceChip(
                          label: Text(level.toUpperCase()),
                          selected: selected,
                          selectedColor: level == 'urgent' || level == 'high'
                              ? Colors.orange.shade700
                              : EvoraColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : EvoraColors.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          onSelected: (_) => setState(() => _selectedPriority = level),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _buildMultiDepartmentSelector(),
                  ],
                ),
              ),

              // Step 2: Location & Place
              Step(
                title: const Text('Place'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Locality / Ward', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _localityController,
                      onChanged: (_) => _localityEditedManually = true,
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
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EvoraColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location, size: 18, color: EvoraColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Geofence Ready: Coordinates (${LocationService.currentLocation.latitude.toStringAsFixed(4)}, ${LocationService.currentLocation.longitude.toStringAsFixed(4)}) will be checked for duplicates within 500 m.',
                              style: const TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
                            ),
                          ),
                        ],
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
                      onChanged: (_) => _descriptionEditedManually = true,
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
                          Text('• Priority: ${_selectedPriority.toUpperCase()}', style: const TextStyle(fontSize: 12)),
                          Text('• Lead Dept: $_leadDepartment', style: const TextStyle(fontSize: 12)),
                          if (_requiredDepartments.length > 1)
                            Text(
                              '• Co-Assigned: ${_requiredDepartments.where((d) => d != _leadDepartment).join(", ")}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          Text('• Locality: ${_localityController.text}', style: const TextStyle(fontSize: 12)),
                          Text(
                            '• Photo Evidence: ${_imageFile != null ? "Attached (EXIF stripped${(_redactionResult?.hasRedactions ?? false) ? ', ${_redactionResult!.totalRedacted} PII blurred' : ''})" : "None"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• 500m AI Duplicate Shield & 10-stage timeline active',
                            style: TextStyle(fontSize: 12, color: EvoraColors.primary, fontWeight: FontWeight.w600),
                          ),
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
