import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bank_account_model.dart';

class BankAccountsController extends GetxController {
  static const String _bankAccountsKey = 'saved_bank_accounts';
  
  final RxList<BankAccountModel> _bankAccounts = <BankAccountModel>[].obs;
  final RxBool _isLoading = false.obs;

  List<BankAccountModel> get bankAccounts => _bankAccounts;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    loadBankAccounts();
  }

  // Load bank accounts from local storage
  Future<void> loadBankAccounts() async {
    try {
      _isLoading.value = true;
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_bankAccountsKey);
      
      if (accountsJson != null) {
        final List<dynamic> accountsList = json.decode(accountsJson);
        _bankAccounts.value = accountsList.map((accountJson) => BankAccountModel.fromJson(accountJson)).toList();
      }
    } catch (e) {
      print('Error loading bank accounts: $e');
      Get.snackbar('Error', 'Failed to load saved bank accounts');
    } finally {
      _isLoading.value = false;
    }
  }

  // Save bank accounts to local storage
  Future<void> _saveBankAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = json.encode(_bankAccounts.map((account) => account.toJson()).toList());
      await prefs.setString(_bankAccountsKey, accountsJson);
    } catch (e) {
      print('Error saving bank accounts: $e');
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
  }) async {
    try {
      _isLoading.value = true;

      // Validate bank account data
      if (!_validateBankAccountData(bankName, accountHolderName, accountNumber, routingNumber, accountType)) {
        return false;
      }

      // Check if account already exists
      if (_bankAccounts.any((account) => account.accountNumber == accountNumber.trim())) {
        Get.snackbar('Error', 'This bank account is already saved');
        return false;
      }

      // Create new bank account
      final newAccount = BankAccountModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bankName: bankName.trim(),
        accountHolderName: accountHolderName.trim(),
        accountNumber: accountNumber.trim(),
        routingNumber: routingNumber.trim(),
        accountType: accountType.trim(),
        isDefault: _bankAccounts.isEmpty, // First account becomes default
        createdAt: DateTime.now(),
      );

      _bankAccounts.add(newAccount);
      await _saveBankAccounts();
      
      Get.snackbar('Success', 'Bank account added successfully');
      return true;
    } catch (e) {
      print('Error adding bank account: $e');
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

      final removedAccount = _bankAccounts[accountIndex];
      _bankAccounts.removeAt(accountIndex);

      // If removed account was default, make first remaining account default
      if (removedAccount.isDefault && _bankAccounts.isNotEmpty) {
        _bankAccounts[0] = _bankAccounts[0].copyWith(isDefault: true);
      }

      await _saveBankAccounts();
      Get.snackbar('Success', 'Bank account removed successfully');
      return true;
    } catch (e) {
      print('Error removing bank account: $e');
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
      
      // Remove default from all accounts
      for (int i = 0; i < _bankAccounts.length; i++) {
        _bankAccounts[i] = _bankAccounts[i].copyWith(isDefault: false);
      }

      // Set new default
      final accountIndex = _bankAccounts.indexWhere((account) => account.id == accountId);
      if (accountIndex == -1) {
        Get.snackbar('Error', 'Bank account not found');
        return false;
      }

      _bankAccounts[accountIndex] = _bankAccounts[accountIndex].copyWith(isDefault: true);
      await _saveBankAccounts();
      
      Get.snackbar('Success', 'Default bank account updated');
      return true;
    } catch (e) {
      print('Error setting default bank account: $e');
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
  bool _validateBankAccountData(String bankName, String accountHolderName, String accountNumber, String routingNumber, String accountType) {
    // Validate bank name
    if (bankName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter bank name');
      return false;
    }

    // Validate account holder name
    if (accountHolderName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter account holder name');
      return false;
    }

    // Validate account number
    if (accountNumber.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter account number');
      return false;
    }

    if (!RegExp(r'^\d+$').hasMatch(accountNumber.trim())) {
      Get.snackbar('Error', 'Account number should contain only digits');
      return false;
    }

    if (accountNumber.trim().length < 8 || accountNumber.trim().length > 17) {
      Get.snackbar('Error', 'Account number should be 8-17 digits long');
      return false;
    }

    // Validate routing number
    if (routingNumber.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter routing number');
      return false;
    }

    if (!RegExp(r'^\d{9}$').hasMatch(routingNumber.trim())) {
      Get.snackbar('Error', 'Routing number should be exactly 9 digits');
      return false;
    }

    // Validate account type
    if (accountType.trim().isEmpty) {
      Get.snackbar('Error', 'Please select account type');
      return false;
    }

    return true;
  }

  // Clear all bank accounts (for testing or reset)
  Future<void> clearAllBankAccounts() async {
    try {
      _bankAccounts.clear();
      await _saveBankAccounts();
      Get.snackbar('Success', 'All bank accounts cleared');
    } catch (e) {
      print('Error clearing bank accounts: $e');
      Get.snackbar('Error', 'Failed to clear bank accounts');
    }
  }
} 