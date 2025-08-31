import '/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:digital_payments_fixed/data/user_model.dart';
import '../../services/firebase_batch_service.dart';

import '../../base_vm.dart';

class LoginViewModel extends BaseViewModel {
  FirebaseAuth? _auth;
  User? _user;
  final FirebaseBatchService _batchService = FirebaseBatchService();

  LoginViewModel() {
    try {
      _auth = FirebaseAuth.instance;
    } catch (e) {
      AppLogger.log('Firebase Auth initialization error: $e');
      _auth = null;
    }
  }

  User? get user => _user;

  Future<String> signUp(UserModel user) async {
    if (_auth == null) {
      return 'Firebase Auth is not initialized. Please restart the app.';
    }
    try {
      final UserCredential result = await _auth!.createUserWithEmailAndPassword(
        email: user.emailAddress,
        password: user.password,
      );
      _user = result.user;
      user.userId = _user!.uid;

      if (_user != null) {
        await saveUserDetails(user);
        return '';
      } else {
        debugPrint('User is null');
        return 'User is null';
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('signInError: $e');
      if (e.code == 'email-already-in-use') {
        return 'The email address is already in use.';
      } else if (e.code == 'user-disabled') {
        return 'The user account has been disabled.';
      } else if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is not formatted correctly.';
      } else if (e.code == 'invalid-credential') {
        return 'The supplied auth credential is malformed or has expired. Please check your email and password.';
      } else if (e.code == 'weak-password') {
        return 'The password provided is not strong enough.';
      } else if (e.code == 'operation-not-allowed') {
        return 'This sign-in method is not enabled.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many requests. Please try again later.';
      } else {
        return 'Error signing in: ${e.message}';
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
      return 'Error signing in: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_auth == null) {
      AppLogger.log('Firebase Auth is not initialized');
      return;
    }
    try {
      await _auth!.signOut();

      _user = null;
    } catch (error) {
      debugPrint('Sign out error: $error');
    } finally {
      notifyListeners();
    }
  }

  Future<String> signIn(String email, String password) async {
    if (_auth == null) {
      return 'Firebase Auth is not initialized. Please restart the app.';
    }
    try {
      final UserCredential result = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;

      if (_user != null) {
        return '';
      } else {
        debugPrint('User is null');
        return 'User is null';
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('signInError: $e');
      if (e.code == 'email-already-in-use') {
        return 'The email address is already in use.';
      } else if (e.code == 'user-disabled') {
        return 'The user account has been disabled.';
      } else if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is not formatted correctly.';
      } else if (e.code == 'invalid-credential') {
        return 'The supplied auth credential is malformed or has expired. Please check your email and password.';
      } else if (e.code == 'weak-password') {
        return 'The password provided is not strong enough.';
      } else if (e.code == 'operation-not-allowed') {
        return 'This sign-in method is not enabled.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many requests. Please try again later.';
      } else {
        return 'Error signing in: ${e.message}';
      }
    } catch (e) {
      debugPrint('Error signing in: $e');
      return 'Error signing in: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<String> resetPassword(String email) async {
    if (_auth == null) {
      debugPrint('Firebase Auth is not initialized');
      return 'Firebase Auth is not initialized. Please restart the app.';
    }
    
    debugPrint('Attempting to send password reset email to: $email');
    
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent successfully to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during password reset: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        return 'No user found for that email address.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is not formatted correctly.';
      } else if (e.code == 'user-disabled') {
        return 'The user account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many requests. Please try again later.';
      } else if (e.code == 'operation-not-allowed') {
        return 'Password reset is not enabled. Please contact support.';
      } else if (e.code == 'missing-email') {
        return 'Please enter an email address.';
      } else {
        debugPrint('Unhandled FirebaseAuthException: ${e.code} - ${e.message}');
        return 'Error sending password reset email: ${e.message}';
      }
    } catch (e) {
      debugPrint('General error during password reset: $e');
      return 'Error sending password reset email: $e';
    } finally {
      notifyListeners();
    }
    return '';
  }



  @override
  Future init() async {
    dataloadingState = DataloadingState.dataLoadComplete;
    notifyListeners();
  }

  Future<void> saveUserDetails(UserModel user) async {
    try {
      await _batchService.addWrite(
        collection: 'users',
        documentId: user.userId,
        data: user.toMap(),
      );
      await _batchService.flushBatch();
    } catch (error) {
      debugPrint('Failed to add user: $error');
    }
  }
}
