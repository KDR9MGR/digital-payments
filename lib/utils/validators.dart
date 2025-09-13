import 'package:flutter/material.dart';

/// Utility class for form validation functions
class Validators {
  /// Validates if the input is a valid email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email address';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates if the input is a valid phone number
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    // Fix the boolean negation expression error
    if (!(value.length >= 10)) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
  }

  /// Validates if the input is not empty
  static String? validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  /// Validates if the input is a valid amount (positive number)
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }
    try {
      final amount = double.parse(value);
      if (amount <= 0) {
        return 'Amount must be greater than zero';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }
    return null;
  }

  /// Validates if the password meets minimum requirements
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }
}