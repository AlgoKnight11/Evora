import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/evora_colors.dart';

/// Animated Splash Screen with Glowing EVORA Logo & Cinematic Transition
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  late final AnimationController _exitController;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitScale;

  Timer? _navigationTimer;
  String _destinationRoute = '/login';

  @override
  void initState() {
    super.initState();

    // Set immersive light icons for dark splash theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    // 1. Logo Intro Animation (0 - 1000ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // 2. Continuous Subtle Ambient Glow Pulse (1600ms loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 3. Exit Transition (3000ms - 3500ms)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );

    _exitScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    // Start Intro Animation
    _logoController.forward();

    // Determine target route in background while splash is entertaining the user
    _determineDestination();

    // Ensure the animated splash screen stays visible for ~3.8 seconds (3 to 5 seconds range)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationTimer = Timer(const Duration(milliseconds: 3200), () {
        if (mounted) {
          _exitController.forward().then((_) {
            if (mounted) {
              // Restore light theme system bar styling
              SystemChrome.setSystemUIOverlayStyle(
                const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
              );
              context.go(_destinationRoute);
            }
          });
        }
      });
    });
  }

  Future<void> _determineDestination() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('has_completed_onboarding') ?? false;
      debugPrint('[Splash] has_completed_onboarding: $hasCompletedOnboarding');

      if (!hasCompletedOnboarding) {
        _destinationRoute = '/onboarding';
      } else {
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _destinationRoute = '/home';
          } else {
            _destinationRoute = '/login';
          }
        } catch (_) {
          _destinationRoute = '/login';
        }
      }
      debugPrint('[Splash] Resolved destination route: $_destinationRoute');
    } catch (e, stack) {
      debugPrint('[Splash] Error resolving destination: $e\n$stack');
      _destinationRoute = '/login';
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _logoController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF02130C), // Deep Mountain Emerald Base
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoController, _pulseController, _exitController]),
        builder: (context, child) {
          return Opacity(
            opacity: _exitOpacity.value,
            child: Transform.scale(
              scale: _exitScale.value,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF02130C), // Ultra-deep evergreen
                      Color(0xFF072A1D), // Mountain Emerald
                      Color(0xFF020D08), // Forest slate floor
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: true,
                  maintainBottomViewPadding: true,
                  child: Column(
                    children: [
                      const Spacer(),

                      // Glowing Ambient Aura + Logo Stack
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Radial Glow Pulse
                            Transform.scale(
                              scale: _pulseScale.value,
                              child: Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      EvoraColors.secondary.withValues(alpha: 0.22),
                                      const Color(0xFF006948).withValues(alpha: 0.10),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Official EVORA Glowing Logo (Scale & Fade In)
                            Transform.scale(
                              scale: _logoScale.value,
                              child: Opacity(
                                opacity: _logoOpacity.value,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Image.asset(
                                    'assets/images/evora_logo_transparent_clean.png',
                                    width: 300,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Animated Tagline Badge
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: EvoraColors.secondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: EvoraColors.secondary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco,
                                size: 14,
                                color: EvoraColors.secondary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'CIVIC INTELLIGENCE • UTTARAKHAND',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: EvoraColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Mission Subtitle
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Text(
                          'Greener Choices. Healthier Cities.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.4,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Minimalist Glowing Loading Progress Indicator
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 120,
                              height: 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    EvoraColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Empowering Municipal & Community Action',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dynamic Inset Padding above OS Navigation Controls
                      SizedBox(height: 16 + bottomInset),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
