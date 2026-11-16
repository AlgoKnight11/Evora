import 'package:flutter/material.dart';
import '../../../core/theme/evora_colors.dart';

/// Terms and Conditions Screen for EVORA
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
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
                color: EvoraColors.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Effective Date: November 2026 • Version 1.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: EvoraColors.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Terms of Service & Citizen Agreement',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'By registering or accessing EVORA, you agree to these Terms. Please read them carefully before submitting formal civic grievances or participating in environmental missions.',
              style: textTheme.bodyLarge?.copyWith(
                color: EvoraColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              title: '1. CivicFlow Grievance Accuracy',
              content:
                  'CivicFlow is a formal municipal grievance channel. You agree to submit truthful, accurate, and observable information. Intentionally submitting fraudulent, defamatory, or abusive reports is prohibited and may result in immediate account restriction and referral to municipal authorities.',
            ),
            _buildSection(
              context,
              title: '2. CivicBook Community Rules',
              content:
                  'CivicBook is an open neighbourhood observation feed. You agree to maintain civil discourse. Upvotes, downvotes, and comments represent community awareness; they do not constitute legal proof or guarantee official case priority.',
            ),
            _buildSection(
              context,
              title: '3. Eco Coins Are In-App Reward Points Only',
              content:
                  'Eco Coins are internal recognition and gamification points awarded for verified environmental activities. They are NOT cryptocurrency, securities, money, legal tender, or tradable carbon offsets. They have no guaranteed cash value and cannot be exchanged for cash.',
            ),
            _buildSection(
              context,
              title: '4. AI Guidance & Emergency Disclaimer',
              content:
                  'Eco Buddy and EVORA AI features provide automated, informational suggestions. EVORA is NOT an emergency response or police dispatch platform. In life-threatening emergencies, immediate safety hazards, or major utility failures, you must contact official emergency numbers (e.g. 112) directly.',
            ),
            _buildSection(
              context,
              title: '5. Account Suspension & Abuse Controls',
              content:
                  'EVORA reserves the right to suspend or restrict accounts engaged in vote brigading, spam, hate speech, or multiple automated submissions. Restricted users may request review through our dispute and appeals process.',
            ),
            _buildSection(
              context,
              title: '6. Jurisdiction & Applicable Law',
              content:
                  'These Terms are governed by the laws of India, with jurisdiction vested in the competent courts of Uttarakhand.',
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
                color: EvoraColors.tertiary,
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
