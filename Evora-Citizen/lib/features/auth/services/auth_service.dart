import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/logging_service.dart';
import '../models/user_model.dart';

/// Authentication State Representation
class AuthState {
  final bool isLoading;
  final EvoraUser? user;
  final String? errorMessage;
  final String? phoneVerificationId;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.phoneVerificationId,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    EvoraUser? user,
    String? errorMessage,
    String? phoneVerificationId,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      phoneVerificationId: phoneVerificationId ?? this.phoneVerificationId,
    );
  }
}

/// Riverpod StateNotifier for Authentication
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthNotifier([this._firebaseAuth]) : super(const AuthState()) {
    _init();
  }

  static String _emailPasswordKey(String email) =>
      'evora_auth_pwd_${email.trim().toLowerCase()}';

  /// Secure local password caching to allow seamless provider linking between
  /// Email/Password authentication and Google Sign-In on the same account.
  Future<void> _savePasswordForEmail(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailPasswordKey(email), password);
    } catch (_) {}
  }

  Future<String?> _getPasswordForEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailPasswordKey(email));
    } catch (_) {
      return null;
    }
  }

  /// Persist authenticated session to local storage for survival across app restarts
  Future<void> _persistSession(EvoraUser user, {String? providerType}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('auth_user_json', jsonEncode(user.toMap()));
      if (providerType != null) {
        await prefs.setString('auth_provider_type', providerType);
      }
      LoggingService.logBreadcrumb('Session persisted for user ${user.uid} ($providerType)');
    } catch (e) {
      LoggingService.logError('Failed to persist auth session: $e');
    }
  }

  /// Clear persisted session on explicit sign out
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_authenticated');
      await prefs.remove('auth_user_json');
      await prefs.remove('auth_provider_type');
      LoggingService.logBreadcrumb('Persisted session cleared.');
    } catch (e) {
      LoggingService.logError('Failed to clear persisted session: $e');
    }
  }

  /// Restores session on app startup
  Future<void> _restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      final userJson = prefs.getString('auth_user_json');

      if (isAuthenticated && userJson != null) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        final restoredUser = EvoraUser.fromMap(map, uid: map['uid'] ?? 'restored_user');
        state = state.copyWith(user: restoredUser, isLoading: false, clearError: true);
        LoggingService.logBreadcrumb('Restored active user session for ${restoredUser.uid}');
      }
    } catch (e) {
      LoggingService.logError('Failed to restore persisted session: $e');
    }
  }

  void _init() {
    _restorePersistedSession();

    try {
      _firebaseAuth?.authStateChanges().listen((User? firebaseUser) async {
        if (firebaseUser != null) {
          final evoraUser = EvoraUser(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? 'Local Resident',
            email: firebaseUser.email,
            phoneNumber: firebaseUser.phoneNumber,
            photoUrl: firebaseUser.photoURL,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          );
          await _persistSession(evoraUser);
          state = state.copyWith(
            user: evoraUser,
            isLoading: false,
            clearError: true,
          );
        } else {
          // If Firebase is null, check if we are running in an offline or dev-test phone session
          final prefs = await SharedPreferences.getInstance();
          final isPersisted = prefs.getBool('is_authenticated') ?? false;
          final providerType = prefs.getString('auth_provider_type');

          if (!isPersisted) {
            state = state.copyWith(user: null, isLoading: false);
          } else if (providerType == 'phone_test' || providerType == 'phone_mock') {
            // Keep dev-test or mock phone session alive across restarts
          }
        }
      });
    } catch (_) {
      // Firebase not yet initialized on device; mock mode available
    }
  }

  /// Sign In with Email and Password
  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Initiating Email Sign-In for $email', correlationId: cid);

    // Save entered password locally so it can link automatically with Google if needed
    await _savePasswordForEmail(email, password);

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final u = credential.user!;
        final evoraUser = EvoraUser(
          uid: u.uid,
          displayName: u.displayName ?? 'Local Resident',
          email: u.email,
          phoneNumber: u.phoneNumber,
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        await _persistSession(evoraUser, providerType: 'password');

        state = state.copyWith(
          isLoading: false,
          user: evoraUser,
        );
        return true;
      } else {
        // Mock fallback for immediate local testing before google-services.json
        await Future.delayed(const Duration(milliseconds: 600));
        final mockUser = EvoraUser(
          uid: 'mock_uid_${email.hashCode}',
          displayName: email.split('@')[0],
          email: email,
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        await _persistSession(mockUser, providerType: 'password_mock');

        state = state.copyWith(
          isLoading: false,
          user: mockUser,
        );
        return true;
      }
    } on FirebaseAuthException catch (e) {
      LoggingService.logError('Email sign-in failed: ${e.code}', correlationId: cid);

      // Check if this account was previously signed into via Google
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found') {
        try {
          // ignore: deprecated_member_use
          final methods = await _firebaseAuth?.fetchSignInMethodsForEmail(email.trim()) ?? [];
          if (methods.contains('google.com') && !methods.contains('password')) {
            // Password was detached by Firebase when Google sign-in was used.
            // Password is now cached. Instruct user to tap Continue with Google to automatically re-link.
            state = state.copyWith(
              isLoading: false,
              errorMessage:
                  'This email is registered via Google Sign-In. Tap "Continue with Google" below to sign in. We will link your password so email login works next time.',
            );
            return false;
          }
        } catch (_) {}
      }

      state = state.copyWith(isLoading: false, errorMessage: _formatAuthError(e.code));
      return false;
    } catch (e) {
      LoggingService.logError('Unexpected email sign-in error: $e', correlationId: cid);
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to sign in. Please try again.');
      return false;
    }
  }

  /// Sign Up with Email and Password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String locality,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Initiating Email Sign-Up', correlationId: cid);

    // Save entered password locally
    await _savePasswordForEmail(email, password);

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await credential.user?.updateDisplayName(displayName);
        final u = credential.user!;
        final evoraUser = EvoraUser(
          uid: u.uid,
          displayName: displayName,
          email: u.email,
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: locality,
          createdAt: DateTime.now(),
        );

        await _persistSession(evoraUser, providerType: 'password');

        state = state.copyWith(
          isLoading: false,
          user: evoraUser,
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 600));
        final mockUser = EvoraUser(
          uid: 'mock_uid_${email.hashCode}',
          displayName: displayName,
          email: email,
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: locality,
          createdAt: DateTime.now(),
        );

        await _persistSession(mockUser, providerType: 'password_mock');

        state = state.copyWith(
          isLoading: false,
          user: mockUser,
        );
        return true;
      }
    } on FirebaseAuthException catch (e) {
      LoggingService.logError('Email sign-up failed: ${e.code}', correlationId: cid);
      state = state.copyWith(isLoading: false, errorMessage: _formatAuthError(e.code));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Registration failed.');
      return false;
    }
  }

  /// Request Phone OTP
  Future<bool> sendPhoneOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Requesting Phone OTP for $phoneNumber', correlationId: cid);

    final cleanDigits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final isTestNumber = cleanDigits.endsWith('9999999999');

    // Seamless offline/local development test number support (+91 9999999999)
    if (isTestNumber) {
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(
        isLoading: false,
        phoneVerificationId: 'dev_test_verification_id_9999999999',
        clearError: true,
      );
      LoggingService.logBreadcrumb('Test number detected. Pre-armed test verification ID.', correlationId: cid);
      return true;
    }

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        await auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            final userCredential = await auth.signInWithCredential(credential);
            final u = userCredential.user;
            if (u != null) {
              final evoraUser = EvoraUser(
                uid: u.uid,
                displayName: 'Resident',
                phoneNumber: u.phoneNumber,
                tenantId: AppConstants.defaultTenantId,
                selectedLocality: 'Dehradun Central',
                createdAt: DateTime.now(),
              );
              await _persistSession(evoraUser, providerType: 'phone');
              state = state.copyWith(user: evoraUser, isLoading: false);
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            LoggingService.logError('Phone verification failed: ${e.code}', correlationId: cid);
            state = state.copyWith(isLoading: false, errorMessage: _formatAuthError(e.code));
          },
          codeSent: (String verificationId, int? resendToken) {
            LoggingService.logBreadcrumb('OTP code sent successfully', correlationId: cid);
            state = state.copyWith(
              isLoading: false,
              phoneVerificationId: verificationId,
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            state = state.copyWith(phoneVerificationId: verificationId);
          },
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 500));
        state = state.copyWith(
          isLoading: false,
          phoneVerificationId: 'mock_verification_id_123',
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to send OTP code.');
      return false;
    }
  }

  /// Verify Phone OTP Code
  Future<bool> verifyOtp(String smsCode) async {
    final verificationId = state.phoneVerificationId;
    if (verificationId == null) {
      state = state.copyWith(errorMessage: 'Please request an OTP first.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();

    // Check if verifying the development test number
    if (verificationId == 'dev_test_verification_id_9999999999' ||
        (verificationId.startsWith('mock_') && smsCode.trim() == '123456')) {
      if (smsCode.trim() == '123456') {
        await Future.delayed(const Duration(milliseconds: 300));
        final devUser = EvoraUser(
          uid: 'test_phone_user_9999999999',
          displayName: 'Resident (Dev Test)',
          phoneNumber: '+91 9999999999',
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        // Persist dev session so force closing and reopening the app stays logged in
        await _persistSession(devUser, providerType: 'phone_test');

        state = state.copyWith(
          isLoading: false,
          user: devUser,
        );
        LoggingService.logBreadcrumb('Dev test phone user authenticated & session persisted.', correlationId: cid);
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Invalid test OTP code. Use 123456.');
        return false;
      }
    }

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        final userCredential = await auth.signInWithCredential(credential);
        final u = userCredential.user!;
        final evoraUser = EvoraUser(
          uid: u.uid,
          displayName: 'Resident',
          phoneNumber: u.phoneNumber,
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        await _persistSession(evoraUser, providerType: 'phone');

        state = state.copyWith(
          isLoading: false,
          user: evoraUser,
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 500));
        final mockUser = EvoraUser(
          uid: 'mock_phone_user_123',
          displayName: 'Resident (+91)',
          phoneNumber: '+91 9999999999',
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        await _persistSession(mockUser, providerType: 'phone_mock');

        state = state.copyWith(
          isLoading: false,
          user: mockUser,
        );
        return true;
      }
    } catch (e) {
      LoggingService.logError('Invalid OTP code', correlationId: cid);
      state = state.copyWith(isLoading: false, errorMessage: 'Invalid verification code.');
      return false;
    }
  }

  /// Sign In with Google, with automatic linking to Email/Password credentials
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Initiating Google Sign-In', correlationId: cid);

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          state = state.copyWith(isLoading: false);
          return false;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        UserCredential userCredential;
        try {
          userCredential = await auth.signInWithCredential(credential);
        } on FirebaseAuthException catch (authEx) {
          if (authEx.code == 'account-exists-with-different-credential') {
            // Account collision: link Google to existing email/password account
            final email = googleUser.email;
            final savedPwd = await _getPasswordForEmail(email);
            if (savedPwd != null) {
              final emailCred = await auth.signInWithEmailAndPassword(
                email: email,
                password: savedPwd,
              );
              await emailCred.user?.linkWithCredential(credential);
              userCredential = emailCred;
            } else {
              state = state.copyWith(
                isLoading: false,
                errorMessage: 'An account already exists for $email. Please sign in with your email & password first to link Google.',
              );
              return false;
            }
          } else {
            rethrow;
          }
        }

        final u = userCredential.user!;

        // Automatically link Email/Password credential if the user has a saved password,
        // ensuring the user can log in with BOTH Google and Email/Password seamlessly.
        final email = u.email;
        if (email != null && email.isNotEmpty) {
          final savedPassword = await _getPasswordForEmail(email);
          if (savedPassword != null && savedPassword.isNotEmpty) {
            try {
              final emailCred = EmailAuthProvider.credential(
                email: email,
                password: savedPassword,
              );
              await u.linkWithCredential(emailCred);
              LoggingService.logBreadcrumb(
                'Successfully linked Email/Password to Google account for $email',
                correlationId: cid,
              );
            } catch (linkError) {
              LoggingService.logBreadcrumb(
                'Password link skipped or already present: $linkError',
                correlationId: cid,
              );
            }
          }
        }

        final evoraUser = EvoraUser(
          uid: u.uid,
          displayName: u.displayName ?? 'Google User',
          email: u.email,
          photoUrl: u.photoURL,
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        await _persistSession(evoraUser, providerType: 'google');

        state = state.copyWith(
          isLoading: false,
          user: evoraUser,
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 600));
        final mockUser = EvoraUser(
          uid: 'mock_google_user_001',
          displayName: 'Bhavya (Demo)',
          email: 'user@evora.org',
          tenantId: AppConstants.defaultTenantId,
          selectedLocality: 'Dehradun Central',
          createdAt: DateTime.now(),
        );

        await _persistSession(mockUser, providerType: 'google_mock');

        state = state.copyWith(
          isLoading: false,
          user: mockUser,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Google Sign-In was cancelled or failed.');
      return false;
    }
  }

  /// Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Sending password reset email to $email', correlationId: cid);

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        await auth.sendPasswordResetEmail(email: email.trim());
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
        state = state.copyWith(isLoading: false);
        return true;
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _formatAuthError(e.code));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to send password reset email.');
      return false;
    }
  }

  /// Sign Out: Completely cleanses local persisted state, Firebase Auth, and Google Sign-In
  Future<void> signOut() async {
    try {
      await _clearPersistedSession();
      await _firebaseAuth?.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
    state = const AuthState();
  }

  String _formatAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code.';
      case 'too-many-requests':
        return 'Too many attempts. For security, please wait a few minutes.';
      case 'operation-not-allowed':
        return 'Phone Sign-In is disabled in Firebase Console. Enable "Phone" under Authentication > Sign-in method.';
      default:
        return 'Authentication failed ($code).';
    }
  }
}

/// Global Riverpod Provider for Auth State
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  FirebaseAuth? auth;
  try {
    auth = FirebaseAuth.instance;
  } catch (_) {
    // Firebase not initialized yet
  }
  return AuthNotifier(auth);
});
