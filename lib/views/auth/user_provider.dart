import 'dart:io';
import '/utils/app_logger.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:xpay/controller/settings_controller.dart';
import 'package:xpay/data/user_model.dart';
import 'package:xpay/utils/threading_utils.dart';
import 'package:xpay/services/firebase_batch_service.dart';
import 'package:xpay/services/firebase_query_optimizer.dart';
import 'package:xpay/services/firebase_cache_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  final FirebaseBatchService _batchService = FirebaseBatchService();
  final FirebaseQueryOptimizer _queryOptimizer = FirebaseQueryOptimizer();
  final FirebaseCacheService _cacheService = FirebaseCacheService();

  UserModel? get user => _user;

  Future<void> fetchUserDetails() async {
    try {
      // Use background thread for Firebase operations
      final result = await ThreadingUtils.runFirebaseOperation(() async {
        User? user = FirebaseAuth.instance.currentUser;
        if (user?.uid == null) return null;
        
        // Try to get from optimized query service with caching
        final userData = await _queryOptimizer.getUserData(user!.uid);
        if (userData != null) {
          return UserModel.fromMap(userData);
        }
        return null;
      }, operationName: 'Fetch user details');

      if (result != null) {
        _user = result;
        // Use UI operation for notifying listeners
        await ThreadingUtils.runUIOperation(() async {
          notifyListeners();
        });
      }
    } catch (e) {
      AppLogger.log('Error fetching user details: $e');
    }
  }

  Future<void> updateUserDetails(Map<String, dynamic> updatedFields) async {
    try {
      if (_user != null) {
        await ThreadingUtils.runFirebaseOperation(() async {
          // Use batch service for optimized writes
          await _batchService.addUpdate(
            collection: 'users',
            documentId: _user!.userId,
            data: updatedFields,
          );
          await _batchService.flushBatch();
        }, operationName: 'Update user details');

        // Invalidate cache and refresh
        await _cacheService.invalidateUserCaches(_user!.userId);
        await fetchUserDetails();
      }
    } catch (e) {
      AppLogger.log('Error updating user details: $e');
    }
  }

  Future<String?> uploadProfilePhoto(File photoFile) async {
    try {
      // Use background thread for Firebase Storage operations
      return await ThreadingUtils.runFirebaseOperation(() async {
        // Assuming you're using Firebase Storage for the upload
        final storageRef = FirebaseStorage.instance.ref().child(
          'profile_photos/${photoFile.path.split('/').last}',
        );
        final uploadTask = storageRef.putFile(photoFile);

        // Wait for the upload to complete
        final snapshot = await uploadTask;

        // Get the download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      }, operationName: 'Upload profile photo');
    } catch (e) {
      // Handle any errors
      AppLogger.log('Failed to upload profile photo: $e');
      return null;
    }
  }

  // Method to update user directly without isolates with null safety
  void updateUserDirectly(UserModel? userModel) {
    if (userModel != null) {
      _user = userModel;
      notifyListeners();
    }
  }

  Future<void> changePassword(SettingsController controller) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // Re-authenticate the user
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: controller.oldPasswordController.text.trim(),
      );

      try {
        // Re-authenticate user
        await user.reauthenticateWithCredential(credential);

        // Update password
        await user.updatePassword(controller.newPasswordController.text.trim());

        // Update password in Firestore
        await updateUserDetails({
          'password': controller.newPasswordController.text.trim(),
        });

        // Fetch updated user details
        await fetchUserDetails();
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message);
      }
    } else {
      throw Exception('User not found or email not available.');
    }
  }

  Future<void> deleteAccount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in.');
      }

      String userId = user.uid;

      // Use background thread for Firebase operations
      await ThreadingUtils.runFirebaseOperation(() async {
        // Delete user data from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        // Delete user profile photo from Firebase Storage if exists
        if (_user?.profilePhoto != null && _user!.profilePhoto!.isNotEmpty) {
          try {
            await FirebaseStorage.instance
                .refFromURL(_user!.profilePhoto!)
                .delete();
          } catch (e) {
            AppLogger.log('Error deleting profile photo: $e');
            // Continue with account deletion even if photo deletion fails
          }
        }

        // Delete the Firebase Authentication account
        await user.delete();
      }, operationName: 'Delete user account');

      // Clear local user data
      _user = null;
      
      // Use UI operation for notifying listeners
      await ThreadingUtils.runUIOperation(() async {
        notifyListeners();
      });

      AppLogger.log('User account deleted successfully');
    } on FirebaseAuthException catch (e) {
      AppLogger.log('Firebase Auth error during account deletion: ${e.message}');
      if (e.code == 'requires-recent-login') {
        throw Exception('Please log in again before deleting your account for security reasons.');
      }
      throw Exception(e.message ?? 'Failed to delete account');
    } catch (e) {
      AppLogger.log('Error deleting user account: $e');
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }
}
