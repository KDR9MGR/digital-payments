import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:xpay/controller/settings_controller.dart';
import 'package:xpay/data/user_model.dart';
import 'package:xpay/utils/threading_utils.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  Future<void> fetchUserDetails() async {
    try {
      // Use background thread for Firebase operations
      final result = await ThreadingUtils.runFirebaseOperation(() async {
        User? user = FirebaseAuth.instance.currentUser;
        QuerySnapshot querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where('userId', isEqualTo: user?.uid)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          return UserModel.fromMap(
            querySnapshot.docs.first.data() as Map<String, dynamic>,
          );
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
      print('Error fetching user details: $e');
    }
  }

  Future<void> updateUserDetails(Map<String, dynamic> updatedFields) async {
    try {
      if (_user != null) {
        await ThreadingUtils.runFirebaseOperation(() async {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.userId)
              .update(updatedFields);
        }, operationName: 'Update user details');

        await fetchUserDetails();
      }
    } catch (e) {
      print('Error updating user details: $e');
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
      print('Failed to upload profile photo: $e');
      return null;
    }
  }

  // Method to update user directly without isolates
  void updateUserDirectly(UserModel userModel) {
    _user = userModel;
    notifyListeners();
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
      throw Exception("User not found or email not available.");
    }
  }
}
