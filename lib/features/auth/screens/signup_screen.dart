import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/evora_colors.dart';
import '../services/auth_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localityController = TextEditingController(text: 'Dehradun Central');
  bool _consentAgreed = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 28 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join EVORA',
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: EvoraColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Help build a cleaner, greener neighbourhood.',
                style: textTheme.bodyMedium?.copyWith(
                  color: EvoraColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              if (authState.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EvoraColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(
                      color: EvoraColors.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'e.g. Rahul Sharma',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _localityController,
                decoration: const InputDecoration(
                  labelText: 'Neighbourhood / Locality',
                  hintText: 'e.g. Rajpur Road, Ward 4',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 6 characters',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 18),

              // Consent Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentAgreed,
                    activeColor: EvoraColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() => _consentAgreed = val ?? false);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        children: [
                          const Text('I agree to the ',
                              style: TextStyle(fontSize: 12)),
                          GestureDetector(
                            onTap: () => context.push('/terms'),
                            child: const Text(
                              'Terms & Conditions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: EvoraColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(' and acknowledge the ',
                              style: TextStyle(fontSize: 12)),
                          GestureDetector(
                            onTap: () => context.push('/privacy-policy'),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: EvoraColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                              ', including non-continuous location and EXIF data scrubbing.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: (!_consentAgreed || authState.isLoading)
                    ? null
                    : () async {
                        final success = await ref
                            .read(authProvider.notifier)
                            .signUpWithEmail(
                              email: _emailController.text,
                              password: _passwordController.text,
                              displayName: _nameController.text.trim(),
                              locality: _localityController.text.trim(),
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
                    : const Text('Create My Account'),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account?', style: textTheme.bodySmall),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
