import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../data/user_model.dart';
import '../utils/app_logger.dart';
import '../services/firebase_batch_service.dart';
import '../controller/subscription_controller.dart';
import '../services/subscription_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseBatchService _batchService = FirebaseBatchService();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      AppLogger.log('Attempting email/password sign in for: $email');
      
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      if (result.user != null) {
        AppLogger.log('Email/password sign in successful');
        await _initializeUserSession(result.user!);
        return AuthResult.success();
      } else {
        return AuthResult.error('Authentication failed');
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.log('Firebase auth error: ${e.code} - ${e.message}');
      return AuthResult.error(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      AppLogger.log('Sign in error: $e');
      return AuthResult.error('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String country,
    required String mobile,
    String accountType = 'personal',
    String? companyName,
    String? representativeFirstName,
    String? representativeLastName,
  }) async {
    try {
      AppLogger.log('Attempting email/password sign up for: $email');
      
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      if (result.user != null) {
        // Create user model
        final userModel = UserModel(
          userId: result.user!.uid,
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          country: country,
          emailAddress: email.trim().toLowerCase(),
          mobile: mobile.trim(),
          password: '', // Don't store password in Firestore
          accountType: accountType,
          companyName: companyName?.trim(),
          representativeFirstName: representativeFirstName?.trim(),
          representativeLastName: representativeLastName?.trim(),
          walletBalances: {},
          address: null,
          state: null,
          city: null,
          zipCode: null,
          profilePhoto: null,
          isSubscribed: false,
          subscriptionStatus: 'none',
        );

        // Save user details to Firestore
        await _saveUserToFirestore(userModel);
        
        AppLogger.log('Email/password sign up successful');
        await _initializeUserSession(result.user!);
        return AuthResult.success();
      } else {
        return AuthResult.error('Account creation failed');
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.log('Firebase auth error: ${e.code} - ${e.message}');
      return AuthResult.error(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      AppLogger.log('Sign up error: $e');
      return AuthResult.error('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      AppLogger.log('Attempting Google sign in');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return AuthResult.error('Sign in cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential result = await _auth.signInWithCredential(credential);
      
      if (result.user != null) {
        AppLogger.log('Google sign in successful');
        
        // Check if this is a new user
        if (result.additionalUserInfo?.isNewUser == true) {
          // Create user profile for new Google users
          await _createGoogleUserProfile(result.user!, googleUser);
        }
        
        await _initializeUserSession(result.user!);
        return AuthResult.success();
      } else {
        return AuthResult.error('Google authentication failed');
      }
    } catch (e) {
      AppLogger.log('Google sign in error: $e');
      return AuthResult.error('Google sign in failed. Please try again.');
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      AppLogger.log('Sending password reset email to: $email');
      
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      
      AppLogger.log('Password reset email sent successfully');
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      AppLogger.log('Password reset error: ${e.code} - ${e.message}');
      return AuthResult.error(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      AppLogger.log('Password reset error: $e');
      return AuthResult.error('Failed to send password reset email. Please try again.');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      AppLogger.log('Signing out user');
      
      // Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      
      // Sign out from Firebase
      await _auth.signOut();
      
      AppLogger.log('User signed out successfully');
    } catch (e) {
      AppLogger.log('Sign out error: $e');
    }
  }

  /// Check if user has active subscription and restrict access if needed
  Future<bool> checkSubscriptionAccess() async {
    try {
      if (!isSignedIn) {
        return false;
      }

      final subscriptionService = Get.find<SubscriptionService>();
      final hasActiveSubscription = await subscriptionService.isUserSubscribed(forceRefresh: true);
      
      AppLogger.log('Subscription access check: $hasActiveSubscription');
      return hasActiveSubscription;
    } catch (e) {
      AppLogger.log('Error checking subscription access: $e');
      return false;
    }
  }

  /// Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      if (!isSignedIn) return null;
      
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      
      return null;
    } catch (e) {
      AppLogger.log('Error getting user data: $e');
      return null;
    }
  }

  /// Initialize user session after successful authentication
  Future<void> _initializeUserSession(User user) async {
    try {
      AppLogger.log('Initializing user session for: ${user.uid}');
      
      // Initialize subscription controller
      final subscriptionController = Get.find<SubscriptionController>();
      await subscriptionController.refreshData();
      
      AppLogger.log('User session initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing user session: $e');
    }
  }

  /// Create user profile for new Google users
  Future<void> _createGoogleUserProfile(User user, GoogleSignInAccount googleUser) async {
    try {
      AppLogger.log('Creating Google user profile for: ${user.uid}');
      
      final names = (user.displayName ?? '').split(' ');
      final firstName = names.isNotEmpty ? names.first : '';
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
      
      final userModel = UserModel(
        userId: user.uid,
        firstName: firstName,
        lastName: lastName,
        country: '', // Will be updated by user later
        emailAddress: user.email ?? '',
        mobile: '', // Will be updated by user later
        password: '', // Google users don't have password
        accountType: 'personal',
        walletBalances: {},
        address: null,
        state: null,
        city: null,
        zipCode: null,
        profilePhoto: user.photoURL,
        isSubscribed: false,
        subscriptionStatus: 'none',
      );

      await _saveUserToFirestore(userModel);
      AppLogger.log('Google user profile created successfully');
    } catch (e) {
      AppLogger.log('Error creating Google user profile: $e');
    }
  }

  /// Save user to Firestore
  Future<void> _saveUserToFirestore(UserModel user) async {
    try {
      await _batchService.addWrite(
        collection: 'users',
        documentId: user.userId,
        data: user.toMap(),
      );
      await _batchService.flushBatch();
      AppLogger.log('User saved to Firestore: ${user.userId}');
    } catch (e) {
      AppLogger.log('Error saving user to Firestore: $e');
      throw e;
    }
  }

  /// Get user-friendly error message from FirebaseAuthException
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again to perform this action.';
      default:
        return e.message ?? 'An authentication error occurred. Please try again.';
    }
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  AuthResult._({required this.isSuccess, this.errorMessage, this.user});

  factory AuthResult.success({User? user}) {
    return AuthResult._(isSuccess: true, user: user);
  }

  factory AuthResult.error(String message) {
    return AuthResult._(isSuccess: false, errorMessage: message);
  }
}