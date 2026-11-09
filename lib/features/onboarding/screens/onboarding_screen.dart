import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/evora_colors.dart';

/// Onboarding Slide Model
class OnboardingSlideData {
  final String imagePath;
  final String title;
  final String description;
  final String? highlightWord;
  final Color? highlightColor;
  final double imageHeight;

  const OnboardingSlideData({
    required this.imagePath,
    required this.title,
    required this.description,
    this.highlightWord,
    this.highlightColor,
    this.imageHeight = 240,
  });
}

/// Onboarding Screen — Displayed exclusively on first app launch
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingSlideData> _slides = [
    OnboardingSlideData(
      imagePath: 'assets/images/slide1_illustration.png',
      title: 'AI-Powered Civic Intelligence',
      description:
          'Transforming civic grievances and citizen sustainability into real-time municipal action across Uttarakhand.',
      imageHeight: 220,
    ),
    OnboardingSlideData(
      imagePath: 'assets/images/slide2_illustration.png',
      title: 'Our Mission: Preserving the Doon Valley',
      description:
          'We connect citizens, workers, and administrators to protect our local ecosystem, manage waste efficiently, and monitor river health in real-time.',
      imageHeight: 240,
    ),
    OnboardingSlideData(
      imagePath: 'assets/images/slide3_illustration.png',
      title: "Let's Get Started",
      description:
          'Join thousands of citizens making a difference in Uttarakhand. Earn EcoCoins for every civic action you take.',
      highlightWord: 'EcoCoins',
      highlightColor: Color(0xFFD97706),
      imageHeight: 200,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) {
      context.go('/login');
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand Logo / Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: EvoraColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco,
                          color: EvoraColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EVORA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: EvoraColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // Skip Button
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: EvoraColors.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 36, width: 48),
                ],
              ),
            ),

            // Slide PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration Container
                        Container(
                          height: slide.imageHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            slide.imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF064E3B), // Deep Forest Emerald
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description (with highlighted keywords support)
                        _buildDescriptionText(slide, textTheme),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Controls (Cleanly positioned above OS Navigation Bar)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? EvoraColors.primary
                              : EvoraColors.outlineVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  if (_currentPage == 0) ...[
                    // Slide 1: Single Next Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3D2E), // Deep Evergreen
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ] else if (_currentPage == 1) ...[
                    // Slide 2: Back & Next Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _prevPage,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: EvoraColors.onSurface,
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F3D2E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Slide 3: Begin Your Journey Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3D2E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Begin Your Journey',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionText(OnboardingSlideData slide, TextTheme textTheme) {
    if (slide.highlightWord == null) {
      return Text(
        slide.description,
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF4B5563),
          height: 1.55,
          fontSize: 14,
        ),
      );
    }

    final parts = slide.description.split(slide.highlightWord!);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF4B5563),
          height: 1.55,
          fontSize: 14,
        ),
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: slide.highlightWord,
            style: TextStyle(
              color: slide.highlightColor ?? EvoraColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}
