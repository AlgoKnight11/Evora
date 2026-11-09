import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/civic_book/screens/civic_book_feed_screen.dart';
import '../features/civic_book/screens/create_civic_book_post_screen.dart';
import '../features/civic_book/screens/post_detail_screen.dart';
import '../features/civic_flow/screens/case_detail_screen.dart';
import '../features/civic_flow/screens/civic_flow_cases_screen.dart';
import '../features/civic_flow/screens/civic_flow_wizard_screen.dart';
import '../features/legal/screens/privacy_policy_screen.dart';
import '../features/legal/screens/terms_and_conditions_screen.dart';
import '../features/neighbourhood/screens/home_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/splash/screens/splash_screen.dart';

/// Helper for smooth cross-fade route transitions
CustomTransitionPage<void> _buildFadePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Builds the app router, starting with the animated SplashScreen
GoRouter createAppRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => _buildFadePage(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildFadePage(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => _buildFadePage(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsAndConditionsScreen(),
      ),

      // CivicBook Routes
      GoRoute(
        path: '/civic-book',
        name: 'civic-book',
        pageBuilder: (context, state) => _buildFadePage(
          context: context,
          state: state,
          child: const CivicBookFeedScreen(),
        ),
      ),
      GoRoute(
        path: '/civic-book/create',
        name: 'civic-book-create',
        builder: (context, state) => const CreateCivicBookPostScreen(),
      ),
      GoRoute(
        path: '/civic-book/:id',
        name: 'civic-book-detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PostDetailScreen(postId: id);
        },
      ),

      // CivicFlow Routes
      GoRoute(
        path: '/civic-flow',
        name: 'civic-flow',
        pageBuilder: (context, state) => _buildFadePage(
          context: context,
          state: state,
          child: const CivicFlowCasesScreen(),
        ),
      ),
      GoRoute(
        path: '/civic-flow/wizard',
        name: 'civic-flow-wizard',
        builder: (context, state) {
          final sourcePostId = state.uri.queryParameters['sourcePostId'];
          final category = state.uri.queryParameters['category'];
          final title = state.uri.queryParameters['title'];
          final locality = state.uri.queryParameters['locality'];

          return CivicFlowWizardScreen(
            sourcePostId: sourcePostId,
            initialCategory: category,
            initialTitle: title,
            initialLocality: locality,
          );
        },
      ),
      GoRoute(
        path: '/civic-flow/:id',
        name: 'civic-flow-detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CaseDetailScreen(caseId: id);
        },
      ),
    ],
  );
}

/// Static fallback router instance
final appRouter = createAppRouter();
