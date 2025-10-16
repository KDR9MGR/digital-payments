import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bank_account_model.dart';
import '/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_batch_service.dart';
import '../services/plaid_service.dart';


class BankAccountsController extends GetxController {
  static const String _bankAccountsKey = 'saved_bank_accounts';

  final RxList<BankAccountModel> _bankAccounts = <BankAccountModel>[].obs;
  final RxBool _isLoading = false.obs;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseBatchService _batchService = FirebaseBatchService();
  final PlaidService _plaidService = Get.find<PlaidService>();

  final Rx<BankAccountModel?> _selectedBankAccount = Rx<BankAccountModel?>(
    null,
  );

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

  // Load bank accounts from server and local storage
  Future<void> loadBankAccounts() async {
    try {
      _isLoading.value = true;

      // Try to load from server first if user is authenticated
      if (_auth.currentUser != null) {
        await _loadBankAccountsFromServer();
      } else {
        // Fallback to local storage if not authenticated
        await _loadBankAccountsFromLocal();
      }
    } catch (e) {
      AppLogger.log('Error loading bank accounts: $e');
      // Fallback to local storage on server error
      await _loadBankAccountsFromLocal();
    } finally {
      _isLoading.value = false;
    }
  }

  // Load bank accounts from server
  Future<void> _loadBankAccountsFromServer() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        final savedBankAccounts =
            userData['saved_bank_accounts'] as List<dynamic>?;

        if (savedBankAccounts != null) {
          _bankAccounts.value =
              savedBankAccounts
                  .map(
                    (accountData) => BankAccountModel.fromJson(
                      accountData as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          // Also save to local storage for offline access
          await _saveBankAccountsToLocal();
          AppLogger.log(
            'Loaded ${_bankAccounts.length} bank accounts from server',
          );
        }
      }
    } catch (e) {
      AppLogger.log('Error loading bank accounts from server: $e');
      throw e;
    }
  }

  // Load bank accounts from local storage
  Future<void> _loadBankAccountsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_bankAccountsKey);

      if (accountsJson != null) {
        final List<dynamic> accountsList = json.decode(accountsJson);
        _bankAccounts.value =
            accountsList
                .map((accountJson) => BankAccountModel.fromJson(accountJson))
                .toList();
        AppLogger.log(
          'Loaded ${_bankAccounts.length} bank accounts from local storage',
        );
      }
    } catch (e) {
      AppLogger.log('Error loading bank accounts from local storage: $e');
      Get.snackbar('Error', 'Failed to load saved bank accounts');
    }
  }

  // Save bank accounts to both server and local storage
  Future<void> _saveBankAccounts() async {
    try {
      // Save to server if user is authenticated
      if (_auth.currentUser != null) {
        await _saveBankAccountsToServer();
      }

      // Always save to local storage as backup
      await _saveBankAccountsToLocal();
    } catch (e) {
      AppLogger.log('Error saving bank accounts: $e');
      throw Exception('Failed to save bank accounts');
    }
  }

  // Save bank accounts to server
  Future<void> _saveBankAccountsToServer() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final accountsData =
          _bankAccounts.map((account) => account.toJson()).toList();

      await _batchService.addUpdate(
        collection: 'users',
        documentId: userId,
        data: {'saved_bank_accounts': accountsData},
      );
      await _batchService.flushBatch();

      AppLogger.log('Saved ${_bankAccounts.length} bank accounts to server');
    } catch (e) {
      AppLogger.log('Error saving bank accounts to server: $e');
      throw e;
    }
  }

  // Save bank accounts to local storage
  Future<void> _saveBankAccountsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = json.encode(
        _bankAccounts.map((account) => account.toJson()).toList(),
      );
      await prefs.setString(_bankAccountsKey, accountsJson);
      AppLogger.log(
        'Saved ${_bankAccounts.length} bank accounts to local storage',
      );
    } catch (e) {
      AppLogger.log('Error saving bank accounts to local storage: $e');
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
      if (!_validateBankAccountData(
        bankName,
        accountHolderName,
        accountNumber,
        routingNumber,
        accountType,
      )) {
        return false;
      }

      // Check if account already exists
      final existingAccount = _bankAccounts.firstWhereOrNull(
        (account) =>
            account.accountNumber == accountNumber &&
            account.routingNumber == routingNumber,
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
        verificationStatus: 'pending',
      );

      _bankAccounts.add(newAccount);
      await _saveBankAccounts();
      
      // Bank account verification will be handled by alternative payment processor

      // Navigate to dashboard with success message
      Get.offAllNamed('/navigationScreen');
      Get.snackbar(
        'Success',
        'Bank account added successfully! Verification in progress.',
        backgroundColor: Colors.green.withValues(alpha: 0.8),
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
      final accountIndex = _bankAccounts.indexWhere(
        (account) => account.id == accountId,
      );

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
      final accountIndex = _bankAccounts.indexWhere(
        (account) => account.id == accountId,
      );

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

    if (accountHolderName.trim().length < 2 ||
        accountHolderName.trim().length > 50) {
      Get.snackbar(
        'Error',
        'Account holder name must be between 2 and 50 characters',
      );
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
      Get.snackbar(
        'Error',
        'Account number appears to have suspicious pattern',
      );
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

    final allowedTypes = [
      'checking',
      'savings',
      'business_checking',
      'business_savings',
    ];
    if (!allowedTypes.contains(accountType.trim().toLowerCase())) {
      Get.snackbar(
        'Error',
        'Invalid account type. Must be checking, savings, business_checking, or business_savings',
      );
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
    final checksum =
        (3 * (digits[0] + digits[3] + digits[6]) +
            7 * (digits[1] + digits[4] + digits[7]) +
            (digits[2] + digits[5] + digits[8])) %
        10;

    return checksum == 0;
  }

  // Bank account verification is now handled by alternative payment processor
  // This function has been removed as Moov services are no longer used
  
  // Retry verification for a bank account
  Future<void> retryBankAccountVerification(String accountId) async {
    try {
      _isLoading.value = true;
      
      final accountIndex = _bankAccounts.indexWhere(
        (account) => account.id == accountId,
      );
      
      if (accountIndex == -1) {
        Get.snackbar('Error', 'Bank account not found');
        return;
      }
      
      // Update status to pending
      final account = _bankAccounts[accountIndex];
      _bankAccounts[accountIndex] = BankAccountModel(
        id: account.id,
        bankName: account.bankName,
        accountHolderName: account.accountHolderName,
        accountNumber: account.accountNumber,
        routingNumber: account.routingNumber,
        accountType: account.accountType,
        isDefault: account.isDefault,
        createdAt: account.createdAt,
        verificationStatus: 'pending',
      );
      
      await _saveBankAccounts();
      
      // Bank account verification will be handled by alternative payment processor
      // For now, just mark as pending
      
      Get.snackbar('Success', 'Bank account verification restarted');
    } catch (e) {
      AppLogger.log('Error retrying bank account verification: $e');
      Get.snackbar('Error', 'Failed to retry verification');
    } finally {
      _isLoading.value = false;
    }
  }
  
  // Get verified bank accounts only
  List<BankAccountModel> get verifiedBankAccounts {
    return _bankAccounts.where(
      (account) => account.verificationStatus == 'verified'
    ).toList();
  }
  
  // Check if account can be used for payments
  bool canUseForPayments(String accountId) {
    final account = _bankAccounts.firstWhereOrNull(
      (account) => account.id == accountId,
    );
    
    return account?.verificationStatus == 'verified';
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

  // Create Plaid Link token
  Future<String?> createLinkToken() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        AppLogger.log('User not authenticated for Plaid Link token creation');
        return null;
      }

      final userId = firebaseUser.uid;
      
      // Create link token through PlaidService
      final result = await _plaidService.createLinkToken(userId: userId);

      if (result != null && result['success'] == true) {
        if (result['linkToken'] != null) {
          AppLogger.log('Plaid Link token created successfully');
          return result['linkToken'] as String;
        } else if (result['data'] != null && result['data']['linkToken'] != null) {
          AppLogger.log('Plaid Link token created successfully');
          return result['data']['linkToken'] as String;
        }
      }

      AppLogger.log('Failed to create Plaid Link token');
      return null;
    } catch (e) {
      AppLogger.log('Error creating Plaid Link token: $e');
      return null;
    }
  }

  // Add bank account from Plaid
  Future<bool> addBankAccountFromPlaid({
    required String publicToken,
    required String accountId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      _isLoading.value = true;

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        AppLogger.log('User not authenticated for adding Plaid bank account');
        return false;
      }

      // Exchange public token for access token
      final exchangeResult = await _plaidService.exchangePublicToken(
        publicToken: publicToken,
        userId: firebaseUser.uid,
      );
      if (exchangeResult == null || exchangeResult['access_token'] == null) {
        AppLogger.log('Failed to exchange Plaid public token');
        return false;
      }

      final accessToken = exchangeResult['access_token'] as String;
      final itemId = exchangeResult['item_id'] as String?;

      // Extract account information from metadata
      final institutionName = metadata['institution']?['name'] ?? 'Unknown Bank';
      final accountName = metadata['account']?['name'] ?? 'Account';
      final accountMask = metadata['account']?['mask'] ?? '****';
      final accountSubtype = metadata['account']?['subtype'] ?? 'checking';

      // Check if account already exists
      final existingAccount = _bankAccounts.firstWhereOrNull(
        (account) => account.plaidAccountId == accountId,
      );

      if (existingAccount != null) {
        Get.snackbar('Error', 'This bank account is already connected');
        return false;
      }

      // Determine if this should be the default account
      final isDefault = _bankAccounts.isEmpty;

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
            verificationStatus: _bankAccounts[i].verificationStatus,
            plaidAccessToken: _bankAccounts[i].plaidAccessToken,
            plaidAccountId: _bankAccounts[i].plaidAccountId,
            plaidItemId: _bankAccounts[i].plaidItemId,
          );
        }
      }

      // Create bank account model
      final bankAccount = BankAccountModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bankName: institutionName,
        accountHolderName: accountName,
        accountNumber: accountMask,
        routingNumber: '', // Will be populated when needed
        accountType: accountSubtype,
        isDefault: isDefault,
        createdAt: DateTime.now(),
        verificationStatus: 'pending',
        plaidAccessToken: accessToken,
        plaidAccountId: accountId,
        plaidItemId: itemId,
      );

      // Add to local list
      _bankAccounts.add(bankAccount);
      await _saveBankAccounts();

      // Note: Bank account verification will be handled separately
      // The account is added with pending status and can be verified later

      AppLogger.log('Bank account added successfully from Plaid');
      return true;
    } catch (e) {
      AppLogger.log('Error adding bank account from Plaid: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }
}
