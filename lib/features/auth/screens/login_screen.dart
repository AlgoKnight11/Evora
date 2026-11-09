import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/evora_colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController(text: '+91 ');
  final _otpController = TextEditingController();

  // OTP Cooldown Timer state
  Timer? _countdownTimer;
  int _cooldownSeconds = 0;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startOtpTimer() {
    setState(() {
      _cooldownSeconds = 60;
      _otpSent = true;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: EvoraColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: EvoraColors.primary),
              SizedBox(width: 8),
              Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your registered email address. We will send you a secure link to reset or create your password.',
                style: TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(dialogCtx);
                final sent = await ref.read(authProvider.notifier).sendPasswordResetEmail(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sent
                            ? 'Password reset email sent to $email. Follow the link to set your password.'
                            : 'Could not send reset email. Please verify your address.',
                      ),
                      backgroundColor: sent ? EvoraColors.primary : EvoraColors.error,
                    ),
                  );
                }
              },
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 28 + bottomInset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: EvoraColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: EvoraColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'CIVIC INTELLIGENCE • UTTARAKHAND',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: EvoraColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome to EVORA',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: EvoraColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Greener Choices. Healthier Cities.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: EvoraColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Error Banner
                if (authState.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EvoraColors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: EvoraColors.onErrorContainer, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: const TextStyle(
                              color: EvoraColors.onErrorContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Method Selector Tabs
                Container(
                  decoration: BoxDecoration(
                    color: EvoraColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: EvoraColors.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: EvoraColors.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Email Sign In'),
                      Tab(text: 'Phone Number OTP'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tab Content
                SizedBox(
                  height: 240,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Email View
                      Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: EvoraColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: authState.isLoading
                                ? null
                                : () async {
                                    final success = await ref
                                        .read(authProvider.notifier)
                                        .signInWithEmail(
                                          _emailController.text,
                                          _passwordController.text,
                                        );
                                    if (success && context.mounted) {
                                      context.go('/home');
                                    }
                                  },
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Sign In with Email'),
                          ),
                        ],
                      ),

                      // Phone OTP View
                      Column(
                        children: [
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '+91 9999999999',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              suffixIcon: TextButton(
                                onPressed: (_cooldownSeconds > 0 ||
                                        authState.isLoading)
                                    ? null
                                    : () async {
                                        final phone = _phoneController.text.trim();
                                        if (phone.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter a phone number.'),
                                            ),
                                          );
                                          return;
                                        }
                                        final sent = await ref
                                            .read(authProvider.notifier)
                                            .sendPhoneOtp(phone);
                                        if (sent) {
                                          _startOtpTimer();
                                          if (context.mounted) {
                                            final isTest = phone.replaceAll(RegExp(r'\D'), '').endsWith('9999999999');
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(isTest
                                                    ? 'Test Mode Activated: Use code 123456'
                                                    : 'OTP requested for $phone'),
                                                backgroundColor: EvoraColors.primary,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: Text(_cooldownSeconds > 0
                                    ? '${_cooldownSeconds}s'
                                    : 'Send OTP'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_otpSent || authState.phoneVerificationId != null) ...[
                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                hintText: 'Enter 6-digit OTP (e.g. 123456)',
                                prefixIcon: Icon(Icons.security_outlined),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: authState.isLoading
                                  ? null
                                  : () async {
                                      final verified = await ref
                                          .read(authProvider.notifier)
                                          .verifyOtp(_otpController.text.trim());
                                      if (verified && context.mounted) {
                                        context.go('/home');
                                      }
                                    },
                              child: const Text('Verify & Enter'),
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                'Tap "Send OTP" to receive a verification SMS.\nTip: For instant testing, use +91 9999999999 with OTP 123456.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: EvoraColors.outline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR',
                          style: textTheme.labelSmall
                              ?.copyWith(color: EvoraColors.outline)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Sign In Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          final success = await ref
                              .read(authProvider.notifier)
                              .signInWithGoogle();
                          if (success && context.mounted) {
                            context.go('/home');
                          }
                        },
                ),

                const SizedBox(height: 24),

                // Sign Up Navigation Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: textTheme.bodySmall),
                    TextButton(
                      onPressed: () => context.push('/signup'),
                      child: const Text('Register here'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Legal Footer Links
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('By continuing, you accept our ',
                        style: TextStyle(fontSize: 11, color: EvoraColors.outline)),
                    GestureDetector(
                      onTap: () => context.push('/terms'),
                      child: const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: EvoraColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(' and ',
                        style: TextStyle(fontSize: 11, color: EvoraColors.outline)),
                    GestureDetector(
                      onTap: () => context.push('/privacy-policy'),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: EvoraColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
