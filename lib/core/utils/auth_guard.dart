import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/services/auth_service.dart';
import '../theme/evora_colors.dart';

/// Enforces authentication before interactive user actions while allowing
/// unauthenticated users to browse the EVORA home dashboard and public feeds.
class AuthGuard {
  AuthGuard._();

  /// Checks whether the user is currently signed in.
  /// If signed out, prompts the user to sign in or register and navigates to LoginScreen.
  /// Returns `true` if the user is authenticated after the flow completes.
  static Future<bool> requireLogin(
    BuildContext context,
    WidgetRef ref, {
    String? actionDescription,
  }) async {
    if (ref.read(authProvider).isAuthenticated) {
      return true;
    }

    final shouldProceedToLogin = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final media = MediaQuery.of(sheetCtx);
        final rawBottom = [
          media.padding.bottom,
          media.viewPadding.bottom,
          media.viewInsets.bottom,
        ].reduce((a, b) => a > b ? a : b);
        final bottomInset = rawBottom > 0 ? (rawBottom + 16.0) : 56.0;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset),
          decoration: const BoxDecoration(
            color: EvoraColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: EvoraColors.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EvoraColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: EvoraColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign In Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: EvoraColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                actionDescription ??
                    'Sign in or create a free EVORA account to post, vote, comment on CivicBook, or register a formal grievance in CivicFlow.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: EvoraColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In / Register'),
                onPressed: () => Navigator.pop(sheetCtx, true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx, false),
                child: const Text('Continue Browsing as Guest'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldProceedToLogin != true || !context.mounted) {
      return false;
    }

    await context.push<bool>('/login?returnOnSuccess=true');
    return ref.read(authProvider).isAuthenticated;
  }
}
