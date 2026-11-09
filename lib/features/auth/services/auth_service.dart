import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  void _init() {
    try {
      _firebaseAuth?.authStateChanges().listen((User? firebaseUser) {
        if (firebaseUser != null) {
          state = state.copyWith(
            user: EvoraUser(
              uid: firebaseUser.uid,
              displayName: firebaseUser.displayName ?? 'Local Resident',
              email: firebaseUser.email,
              phoneNumber: firebaseUser.phoneNumber,
              photoUrl: firebaseUser.photoURL,
              tenantId: AppConstants.defaultTenantId,
              selectedLocality: 'Dehradun Central',
              createdAt: DateTime.now(),
            ),
            isLoading: false,
            clearError: true,
          );
        } else {
          state = state.copyWith(user: null, isLoading: false);
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
    LoggingService.logBreadcrumb('Initiating Email Sign-In', correlationId: cid);

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final u = credential.user!;
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: u.uid,
            displayName: u.displayName ?? 'Local Resident',
            email: u.email,
            phoneNumber: u.phoneNumber,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        return true;
      } else {
        // Mock fallback for immediate local testing before google-services.json
        await Future.delayed(const Duration(milliseconds: 600));
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: 'mock_uid_${email.hashCode}',
            displayName: email.split('@')[0],
            email: email,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        return true;
      }
    } on FirebaseAuthException catch (e) {
      LoggingService.logError('Email sign-in failed: ${e.code}', correlationId: cid);
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

    try {
      final auth = _firebaseAuth;
      if (auth != null) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await credential.user?.updateDisplayName(displayName);
        final u = credential.user!;
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: u.uid,
            displayName: displayName,
            email: u.email,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: locality,
            createdAt: DateTime.now(),
          ),
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 600));
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: 'mock_uid_${email.hashCode}',
            displayName: displayName,
            email: email,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: locality,
            createdAt: DateTime.now(),
          ),
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
            await auth.signInWithCredential(credential);
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
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: 'test_phone_user_9999999999',
            displayName: 'Resident (Dev Test)',
            phoneNumber: '+91 9999999999',
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        LoggingService.logBreadcrumb('Dev test phone user authenticated successfully.', correlationId: cid);
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
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: u.uid,
            displayName: 'Resident',
            phoneNumber: u.phoneNumber,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 500));
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: 'mock_phone_user_123',
            displayName: 'Resident (+91)',
            phoneNumber: '+91 9999999999',
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        return true;
      }
    } catch (e) {
      LoggingService.logError('Invalid OTP code', correlationId: cid);
      state = state.copyWith(isLoading: false, errorMessage: 'Invalid verification code.');
      return false;
    }
  }

  /// Sign In with Google
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

        final userCredential = await auth.signInWithCredential(credential);
        final u = userCredential.user!;

        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: u.uid,
            displayName: u.displayName ?? 'Google User',
            email: u.email,
            photoUrl: u.photoURL,
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        return true;
      } else {
        // Mock fallback
        await Future.delayed(const Duration(milliseconds: 600));
        state = state.copyWith(
          isLoading: false,
          user: EvoraUser(
            uid: 'mock_google_user_001',
            displayName: 'Bhavya (Demo)',
            email: 'user@evora.org',
            tenantId: AppConstants.defaultTenantId,
            selectedLocality: 'Dehradun Central',
            createdAt: DateTime.now(),
          ),
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Google Sign-In was cancelled or failed.');
      return false;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
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
