import 'package:flutter/material.dart';
import '../../../core/theme/evora_colors.dart';

/// Privacy Policy Screen — Fully compliant with the Indian DPDP Act
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: EvoraColors.surfaceContainerLowest,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: EvoraColors.outlineVariant, height: 1),
        ),
      ),
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 28 + MediaQuery.paddingOf(context).bottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: EvoraColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Effective Date: November 2026 • Version 1.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: EvoraColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Privacy & Data Protection',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'EVORA is built on the principle of "Privacy by Design." We collect only the minimum data necessary to resolve civic issues and measure environmental progress.',
              style: textTheme.bodyLarge?.copyWith(
                color: EvoraColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              title: '1. No Continuous Location Tracking',
              content:
                  'EVORA does NOT track your real-time or background location. Location permissions are requested only when you choose to find nearby services or tag a civic report. You can always opt to pick a locality or map pin manually without granting GPS permissions.',
            ),
            _buildSection(
              context,
              title: '2. Automated Photo EXIF & Privacy Scrubbing',
              content:
                  'Photos taken on mobile devices contain sensitive embedded metadata (including exact camera coordinates and timestamps). When you upload civic photos or mission evidence to EVORA, all EXIF metadata is automatically stripped before storage to prevent exposing your home location.',
            ),
            _buildSection(
              context,
              title: '3. Coordinate Generalization on Public Feeds',
              content:
                  'On public community feeds like CivicBook, issue locations are generalized to the neighbourhood or ward level. Your exact coordinates, phone number, and private account email are never displayed publicly.',
            ),
            _buildSection(
              context,
              title: '4. Eco Buddy AI Conversations',
              content:
                  'Queries sent to the Eco Buddy assistant are grounded in verified municipal and sustainability data. We do not use your private personal chat content to train public models. You may review or clear your assistant chat history at any time from your Profile settings.',
            ),
            _buildSection(
              context,
              title: '5. Your Rights Under the DPDP Act',
              content:
                  'Under the Digital Personal Data Protection Act, you have the right to access your personal data, request correction of inaccurate records, withdraw consent, and request deletion of your account (subject to statutory municipal record-keeping requirements).',
            ),
            _buildSection(
              context,
              title: '6. Grievance Officer & Contact',
              content:
                  'For questions, data requests, or privacy concerns, contact our designated Data Protection Officer at privacy@evora.org or via the in-app support center.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EvoraColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: EvoraColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: textTheme.bodyMedium?.copyWith(
                color: EvoraColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
