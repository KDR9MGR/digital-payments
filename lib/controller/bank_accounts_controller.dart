import 'dart:convert';
import '/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bank_account_model.dart';

class BankAccountsController extends GetxController {
  static const String _bankAccountsKey = 'saved_bank_accounts';

  final RxList<BankAccountModel> _bankAccounts = <BankAccountModel>[].obs;
  final RxBool _isLoading = false.obs;
  final Rx<BankAccountModel?> _selectedBankAccount = Rx<BankAccountModel?>(null);

  List<BankAccountModel> get bankAccounts => _bankAccounts;
  bool get isLoading => _isLoading.value;
  BankAccountModel? get selectedBankAccount => _selectedBankAccount.value;

  // Set selected bank account
  void setSelectedAccount(BankAccountModel account) {
    _selectedBankAccount.value = account;
  }

  @override
  void onInit() {
    super.onInit();
    loadBankAccounts();
  }

  // Add sample bank data for testing QR generation
  Future<void> addSampleBankData() async {
    try {
      // Only add sample data if no accounts exist
      if (_bankAccounts.isEmpty) {
        final sampleAccounts = [
          BankAccountModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            bankName: 'Chase Bank',
            accountHolderName: 'John Doe',
            accountNumber: '1234567890123456',
            routingNumber: '021000021',
            accountType: 'Checking',
            isDefault: true,
            createdAt: DateTime.now(),
          ),
          BankAccountModel(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            bankName: 'Bank of America',
            accountHolderName: 'Jane Smith',
            accountNumber: '9876543210987654',
            routingNumber: '026009593',
            accountType: 'Savings',
            isDefault: false,
            createdAt: DateTime.now(),
          ),
        ];
        
        _bankAccounts.addAll(sampleAccounts);
        await _saveBankAccounts();
        Get.snackbar('Success', 'Sample bank accounts added for testing');
      } else {
        Get.snackbar('Info', 'Bank accounts already exist');
      }
    } catch (e) {
      AppLogger.log('Error adding sample bank data: $e');
      Get.snackbar('Error', 'Failed to add sample bank data');
    }
  }

  // Load bank accounts from local storage
  Future<void> loadBankAccounts() async {
    try {
      _isLoading.value = true;
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_bankAccountsKey);

      if (accountsJson != null) {
        final List<dynamic> accountsList = json.decode(accountsJson);
        _bankAccounts.value =
            accountsList
                .map((accountJson) => BankAccountModel.fromJson(accountJson))
                .toList();
      }
    } catch (e) {
      AppLogger.log('Error loading bank accounts: $e');
      Get.snackbar('Error', 'Failed to load saved bank accounts');
    } finally {
      _isLoading.value = false;
    }
  }

  // Save bank accounts to local storage
  Future<void> _saveBankAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = json.encode(
        _bankAccounts.map((account) => account.toJson()).toList(),
      );
      await prefs.setString(_bankAccountsKey, accountsJson);
    } catch (e) {
      AppLogger.log('Error saving bank accounts: $e');
      throw Exception('Failed to save bank accounts');
    }
  }

  // Add a new bank account
  Future<bool> addBankAccount({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    required String routingNumber,
    required String accountType,
    bool setAsDefault = false,
  }) async {
    try {
      _isLoading.value = true;

      // Validate input data
      if (!_validateBankAccountData(bankName, accountHolderName, accountNumber, routingNumber, accountType)) {
        return false;
      }

      // Check if account already exists
      final existingAccount = _bankAccounts.firstWhereOrNull(
        (account) => account.accountNumber == accountNumber && account.routingNumber == routingNumber,
      );

      if (existingAccount != null) {
        Get.snackbar('Error', 'This bank account is already saved');
        return false;
      }

      // If this is the first account or setAsDefault is true, make it default
      final isDefault = _bankAccounts.isEmpty || setAsDefault;

      // If setting as default, update existing accounts
      if (isDefault) {
        for (int i = 0; i < _bankAccounts.length; i++) {
          _bankAccounts[i] = BankAccountModel(
            id: _bankAccounts[i].id,
            bankName: _bankAccounts[i].bankName,
            accountHolderName: _bankAccounts[i].accountHolderName,
            accountNumber: _bankAccounts[i].accountNumber,
            routingNumber: _bankAccounts[i].routingNumber,
            accountType: _bankAccounts[i].accountType,
            isDefault: false,
            createdAt: _bankAccounts[i].createdAt,
          );
        }
      }

      // Create new bank account
      final newAccount = BankAccountModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bankName: bankName.trim(),
        accountHolderName: accountHolderName.trim(),
        accountNumber: accountNumber.trim(),
        routingNumber: routingNumber.trim(),
        accountType: accountType.trim(),
        isDefault: isDefault,
        createdAt: DateTime.now(),
      );

      _bankAccounts.add(newAccount);
      await _saveBankAccounts();
      
      // Navigate to dashboard with success message
      Get.offAllNamed('/navigationScreen');
      Get.snackbar(
        'Success', 
        'Bank account added successfully! You can now use it for payments.',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      AppLogger.log('Error adding bank account: $e');
      Get.snackbar('Error', 'Failed to add bank account');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Remove a bank account
  Future<bool> removeBankAccount(String accountId) async {
    try {
      _isLoading.value = true;
      final accountIndex = _bankAccounts.indexWhere((account) => account.id == accountId);

      if (accountIndex == -1) {
        Get.snackbar('Error', 'Bank account not found');
        return false;
      }

      final wasDefault = _bankAccounts[accountIndex].isDefault;
      _bankAccounts.removeAt(accountIndex);

      // If removed account was default and there are other accounts, make the first one default
      if (wasDefault && _bankAccounts.isNotEmpty) {
        _bankAccounts[0] = BankAccountModel(
          id: _bankAccounts[0].id,
          bankName: _bankAccounts[0].bankName,
          accountHolderName: _bankAccounts[0].accountHolderName,
          accountNumber: _bankAccounts[0].accountNumber,
          routingNumber: _bankAccounts[0].routingNumber,
          accountType: _bankAccounts[0].accountType,
          isDefault: true,
          createdAt: _bankAccounts[0].createdAt,
        );
      }

      await _saveBankAccounts();
      Get.snackbar('Success', 'Bank account removed successfully');
      return true;
    } catch (e) {
      AppLogger.log('Error removing bank account: $e');
      Get.snackbar('Error', 'Failed to remove bank account');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Set default bank account
  Future<bool> setDefaultBankAccount(String accountId) async {
    try {
      _isLoading.value = true;
      final accountIndex = _bankAccounts.indexWhere((account) => account.id == accountId);

      if (accountIndex == -1) {
        Get.snackbar('Error', 'Bank account not found');
        return false;
      }

      // Update all accounts to not be default
      for (int i = 0; i < _bankAccounts.length; i++) {
        _bankAccounts[i] = BankAccountModel(
          id: _bankAccounts[i].id,
          bankName: _bankAccounts[i].bankName,
          accountHolderName: _bankAccounts[i].accountHolderName,
          accountNumber: _bankAccounts[i].accountNumber,
          routingNumber: _bankAccounts[i].routingNumber,
          accountType: _bankAccounts[i].accountType,
          isDefault: i == accountIndex,
          createdAt: _bankAccounts[i].createdAt,
        );
      }

      await _saveBankAccounts();
      Get.snackbar('Success', 'Default bank account updated');
      return true;
    } catch (e) {
      AppLogger.log('Error setting default bank account: $e');
      Get.snackbar('Error', 'Failed to update default bank account');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Get default bank account
  BankAccountModel? get defaultBankAccount {
    try {
      return _bankAccounts.firstWhere((account) => account.isDefault);
    } catch (e) {
      return _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
    }
  }

  // Validate bank account data
  bool _validateBankAccountData(
    String bankName,
    String accountHolderName,
    String accountNumber,
    String routingNumber,
    String accountType,
  ) {
    // Validate bank name
    if (bankName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter bank name');
      return false;
    }

    if (bankName.trim().length < 2 || bankName.trim().length > 50) {
      Get.snackbar('Error', 'Bank name must be between 2 and 50 characters');
      return false;
    }

    final bankNamePattern = RegExp(r'^[a-zA-Z\s.\-&]+$');
    if (!bankNamePattern.hasMatch(bankName.trim())) {
      Get.snackbar('Error', 'Bank name contains invalid characters');
      return false;
    }

    // Validate account holder name
    if (accountHolderName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter account holder name');
      return false;
    }

    if (accountHolderName.trim().length < 2 || accountHolderName.trim().length > 50) {
      Get.snackbar('Error', 'Account holder name must be between 2 and 50 characters');
      return false;
    }

    final namePattern = RegExp(r"^[a-zA-Z\s.\-']+$");
    if (!namePattern.hasMatch(accountHolderName.trim())) {
      Get.snackbar('Error', 'Account holder name contains invalid characters');
      return false;
    }

    // Validate account number
    if (accountNumber.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter account number');
      return false;
    }

    final digitPattern = RegExp(r'^\d+$');
    if (!digitPattern.hasMatch(accountNumber.trim())) {
      Get.snackbar('Error', 'Account number should contain only digits');
      return false;
    }

    if (accountNumber.trim().length < 8 || accountNumber.trim().length > 17) {
      Get.snackbar('Error', 'Account number should be 8-17 digits long');
      return false;
    }

    if (_hasSuspiciousPattern(accountNumber.trim())) {
      Get.snackbar('Error', 'Account number appears to have suspicious pattern');
      return false;
    }

    // Validate routing number
    if (routingNumber.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter routing number');
      return false;
    }

    final routingPattern = RegExp(r'^\d{9}$');
    if (!routingPattern.hasMatch(routingNumber.trim())) {
      Get.snackbar('Error', 'Routing number must be exactly 9 digits');
      return false;
    }

    if (!_validateRoutingNumber(routingNumber.trim())) {
      Get.snackbar('Error', 'Invalid routing number');
      return false;
    }

    // Validate account type
    if (accountType.trim().isEmpty) {
      Get.snackbar('Error', 'Please select account type');
      return false;
    }

    final allowedTypes = ['checking', 'savings', 'business_checking', 'business_savings'];
    if (!allowedTypes.contains(accountType.trim().toLowerCase())) {
      Get.snackbar('Error', 'Invalid account type. Must be checking, savings, business_checking, or business_savings');
      return false;
    }

    return true;
  }

  // Helper method to check for suspicious patterns in account numbers
  bool _hasSuspiciousPattern(String accountNumber) {
    // Check for all same digits
    final sameDigitPattern = RegExp(r'^(.)\1+$');
    if (sameDigitPattern.hasMatch(accountNumber)) {
      return true;
    }

    // Check for sequential digits (ascending)
    bool isSequential = true;
    for (int i = 1; i < accountNumber.length; i++) {
      int current = int.parse(accountNumber[i]);
      int previous = int.parse(accountNumber[i - 1]);
      if (current != previous + 1) {
        isSequential = false;
        break;
      }
    }
    if (isSequential) return true;

    // Check for descending sequential digits
    isSequential = true;
    for (int i = 1; i < accountNumber.length; i++) {
      int current = int.parse(accountNumber[i]);
      int previous = int.parse(accountNumber[i - 1]);
      if (current != previous - 1) {
        isSequential = false;
        break;
      }
    }
    if (isSequential) return true;

    return false;
  }

  // Helper method to validate routing number using ABA checksum algorithm
  bool _validateRoutingNumber(String routingNumber) {
    if (routingNumber.length != 9) return false;

    final digits = routingNumber.split('').map(int.parse).toList();
    final checksum = (3 * (digits[0] + digits[3] + digits[6]) +
                     7 * (digits[1] + digits[4] + digits[7]) +
                     (digits[2] + digits[5] + digits[8])) % 10;
    
    return checksum == 0;
  }

  // Clear all bank accounts (for testing or reset)
  Future<void> clearAllBankAccounts() async {
    try {
      _bankAccounts.clear();
      await _saveBankAccounts();
      Get.snackbar('Success', 'All bank accounts cleared');
    } catch (e) {
      AppLogger.log('Error clearing bank accounts: $e');
      Get.snackbar('Error', 'Failed to clear bank accounts');
    }
  }
}
