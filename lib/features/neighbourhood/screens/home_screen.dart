import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/device_permission_service.dart';
import '../../auth/services/auth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _uploadedImageUrl;
  bool _isUploading = false;
  String? _uploadStatus;

  Future<void> _testCloudinaryUpload() async {
    final authed = await AuthGuard.requireLogin(
      context,
      ref,
      actionDescription: 'Sign in to upload verification photos to EVORA.',
    );
    if (!authed) return;

    final granted = await DevicePermissionService.ensureGalleryPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo gallery permission is required to select a photo.'),
          ),
        );
      }
      return;
    }

    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading photo to Cloudinary...';
    });

    final result = await CloudinaryService.uploadImage(
      File(pickedFile.path),
      folder: 'civic_reports_test',
    );

    setState(() {
      _isUploading = false;
      if (result.isSuccess) {
        _uploadedImageUrl = result.url;
        _uploadStatus = 'Upload Success! EXIF stripped & WebP optimized.';
      } else {
        _uploadStatus = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EvoraColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, color: EvoraColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('EVORA'),
          ],
        ),
        actions: [
          if (authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Sign Out',
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out. You are now browsing in guest mode.'),
                    ),
                  );
                }
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => context.push('/login?returnOnSuccess=true'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting & Locality Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: EvoraColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: EvoraColors.primary,
                    child: Text(
                      (user?.displayName.isNotEmpty == true)
                          ? user!.displayName[0].toUpperCase()
                          : 'R',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Namaste, ${user?.displayName ?? "Resident"}',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: EvoraColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              user?.selectedLocality ?? 'Dehradun Central',
                              style: textTheme.bodySmall?.copyWith(
                                color: EvoraColors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's Eco Action Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [EvoraColors.primary, Color(0xFF004D34)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      "TODAY'S ECO ACTION",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Segregate Dry & Wet Waste',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep biodegradable kitchen scraps separate from plastics to facilitate municipal composting in Ward 4.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EvoraColors.secondary,
                      foregroundColor: EvoraColors.onSecondary,
                    ),
                    onPressed: () async {
                      final authed = await AuthGuard.requireLogin(
                        context,
                        ref,
                        actionDescription:
                            'Sign in to complete daily eco actions and earn Eco Coins.',
                      );
                      if (authed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Daily eco action rewards unlock in Phase 5 Eco Missions!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Mark Completed (+10 Eco Coins)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cloudinary Verification & Upload Test Box
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: EvoraColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          color: EvoraColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Cloudinary Storage Test',
                        style: textTheme.headlineSmall?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connected Bucket: ztamooew (Preset: evora_unsigned)\nTest picking and uploading a photo to verify CDN storage & EXIF stripping:',
                    style: textTheme.bodySmall?.copyWith(
                      color: EvoraColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isUploading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Pick & Upload Test Photo'),
                      onPressed: _testCloudinaryUpload,
                    ),
                  if (_uploadStatus != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _uploadStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _uploadedImageUrl != null
                            ? EvoraColors.primary
                            : EvoraColors.error,
                      ),
                    ),
                  ],
                  if (_uploadedImageUrl != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _uploadedImageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Core Pillars Navigation Grid
            Text(
              'Civic & Sustainability Services',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _buildServiceCard(
                  context,
                  title: 'CivicFlow',
                  subtitle: 'Official grievance wizard',
                  icon: Icons.assignment_outlined,
                  color: EvoraColors.primary,
                  onTap: () => context.push('/civic-flow'),
                ),
                _buildServiceCard(
                  context,
                  title: 'CivicBook',
                  subtitle: '3-5 km community feed',
                  icon: Icons.dynamic_feed_outlined,
                  color: EvoraColors.secondaryContainer,
                  iconColor: EvoraColors.onSecondaryContainer,
                  onTap: () => context.push('/civic-book'),
                ),
                _buildServiceCard(
                  context,
                  title: 'EvoSwitch',
                  subtitle: 'Green alternative engine',
                  icon: Icons.swap_calls_outlined,
                  color: EvoraColors.tertiaryContainer,
                  iconColor: Colors.white,
                  onTap: () async {
                    final authed = await AuthGuard.requireLogin(
                      context,
                      ref,
                      actionDescription: 'Sign in to explore personalized sustainable swaps in EvoSwitch.',
                    );
                    if (authed && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('EvoSwitch engine arrives in Phase 4!')),
                      );
                    }
                  },
                ),
                _buildServiceCard(
                  context,
                  title: 'Waste Directory',
                  subtitle: 'Recycling & e-waste hubs',
                  icon: Icons.delete_outline,
                  color: EvoraColors.surfaceContainerHigh,
                  onTap: () async {
                    final authed = await AuthGuard.requireLogin(
                      context,
                      ref,
                      actionDescription: 'Sign in to interact with verified recycling & e-waste hubs.',
                    );
                    if (authed && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Circular Waste Directory arrives in Phase 4!')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Footer Links
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.push('/privacy-policy'),
                    child: const Text('Privacy Policy'),
                  ),
                  const Text('•', style: TextStyle(color: EvoraColors.outline)),
                  TextButton(
                    onPressed: () => context.push('/terms'),
                    child: const Text('Terms of Service'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EvoraColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: EvoraColors.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
