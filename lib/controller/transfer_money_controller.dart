import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';
import '../services/moov_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import '../data/user_model.dart';
import '../config/moov_config.dart';

class TransferMoneyController extends GetxController {
  final dropdownWalletController = TextEditingController();
  final receiverUsernameOrEmailController = TextEditingController();
  final amountController = TextEditingController();

  List<String> walletList = ['USD', 'GBP', 'BDT'];
  RxString walletName = ''.obs;
  RxDouble charge = 0.00.obs;
  RxDouble chargeCalculated = 0.00.obs;
  RxDouble fixedCharge = 0.00.obs;
  
  // Payment method properties
  List<String> paymentMethods = ['Bank Account', 'Debit Card', 'Credit Card', 'Wallet Balance'];
  RxString selectedPaymentMethod = ''.obs;
  RxBool isProcessingTransfer = false.obs;
  
  final MoovService _moovService = MoovService();

  double calculateCharge(double value) {
    fixedCharge.value = 2.00;
    charge.value = 0.00;
    chargeCalculated.value = 0.00;
    double extraCharge = value * .01;
    chargeCalculated.value = extraCharge;
    charge.value = chargeCalculated.value + fixedCharge.value;
    if (value == 0) {
      chargeCalculated.value = 0.00;
      charge.value = 0.00;
      return 0.00;
    }
    return chargeCalculated.value + fixedCharge.value;
  }

  @override
  void onInit() {
    walletName.value = walletList[0];
    amountController.text = '0';
    _initializePaymentMethod();

    super.onInit();
  }

  // Initialize payment method with proper error handling
  void _initializePaymentMethod() {
    if (paymentMethods.isNotEmpty) {
      selectedPaymentMethod.value = paymentMethods[0];
    } else {
      // Fallback payment methods if list is empty
      paymentMethods = ['Bank Account', 'Debit Card', 'Credit Card', 'Wallet Balance'];
      selectedPaymentMethod.value = paymentMethods[0];
      AppLogger.log('Payment methods list was empty, initialized with default methods');
    }
  }

  // Validate payment method selection
  bool validatePaymentMethod() {
    if (selectedPaymentMethod.value.isEmpty) {
      _initializePaymentMethod();
      return false;
    }
    
    if (!paymentMethods.contains(selectedPaymentMethod.value)) {
      AppLogger.log('Selected payment method not in available methods, resetting to first available');
      selectedPaymentMethod.value = paymentMethods.isNotEmpty ? paymentMethods[0] : '';
      return false;
    }
    
    return true;
  }

  // Refresh payment methods if needed
  void refreshPaymentMethods() {
    if (paymentMethods.isEmpty) {
      _initializePaymentMethod();
      AppLogger.log('Payment methods refreshed due to empty list');
    }
  }

  // Get current payment method with fallback
  String getCurrentPaymentMethod() {
    if (selectedPaymentMethod.value.isEmpty || !paymentMethods.contains(selectedPaymentMethod.value)) {
      validatePaymentMethod();
    }
    return selectedPaymentMethod.value;
  }

  @override
  void dispose() {
    dropdownWalletController.dispose();
    receiverUsernameOrEmailController.dispose();
    amountController.dispose();

    super.dispose();
  }

  void navigateToDashboardScreen() {
    Get.toNamed(Routes.navigationScreen);
  }

  void navigateToConfirmTransferMoneyScreen() {
    Get.toNamed(Routes.confirmTransferMoneyScreen);
  }

  // Process actual money transfer
  Future<void> processTransfer() async {
    // Validate and ensure payment method is properly selected
    if (!validatePaymentMethod()) {
      Get.snackbar(
        'Error',
        'Please select a valid payment method',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    
    // Double-check payment method is still valid after validation
    if (selectedPaymentMethod.value.isEmpty) {
      Get.snackbar(
        'Error',
        'Payment method selection failed. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (receiverUsernameOrEmailController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter recipient email or username',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (amountController.text.isEmpty || double.tryParse(amountController.text) == null) {
      Get.snackbar(
        'Error',
        'Please enter a valid amount',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      AppLogger.log('Starting transfer process...');
      isProcessingTransfer.value = true;
      
      final amount = double.parse(amountController.text);
      final recipient = receiverUsernameOrEmailController.text.trim();

      AppLogger.log('Transfer details - Recipient: $recipient, Amount: $amount, Currency: ${walletName.value}');

      // Normalize currency - default to USD if unsupported
      String currency = walletName.value.toUpperCase();
      if (!['USD', 'GBP', 'BDT'].contains(currency)) {
        currency = 'USD';
      }
      
      AppLogger.log('Normalized currency: $currency');
      
      // Show processing dialog
      Get.dialog(
        AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing transfer...'),
            ],
          ),
        ),
        barrierDismissible: false,
      );
      
      // Process actual transfer using Moov API
      final transferResult = await _processP2PTransfer(
        recipientEmail: recipient,
        amount: amount,
        currency: currency,
        paymentMethod: selectedPaymentMethod.value,
      );
      
      // Close processing dialog
      if (Get.isDialogOpen ?? false) Get.back();
      
      if (transferResult['success'] == true) {
        AppLogger.log('Transfer completed successfully');
        // Show success and navigate to confirmation
        Get.snackbar(
          'Transfer Successful',
          'Transfer of \$${amount.toStringAsFixed(2)} to $recipient completed successfully\nTransaction ID: ${transferResult['transferId']}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
        );
        
        // Clear form fields
        receiverUsernameOrEmailController.clear();
        amountController.text = '0';
        
        // Navigate to confirmation screen
        navigateToConfirmTransferMoneyScreen();
      } else {
        throw transferResult['error'] ?? 'Transfer failed';
      }
      
    } catch (e) {
      AppLogger.log('Transfer error caught in processTransfer: $e');
      AppLogger.log('Error type: ${e.runtimeType}');
      AppLogger.log('Stack trace: ${StackTrace.current}');
      
      // Close processing dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Transfer Failed',
        'Failed to process transfer: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } finally {
      isProcessingTransfer.value = false;
    }
  }

  void navigateToTransferMoneyScanQrCodeScreen() {
    Get.toNamed(Routes.transferMoneyScanQrCodeScreen);
  }

  // Process P2P transfer using Moov API
  Future<Map<String, dynamic>> _processP2PTransfer({
    required String recipientEmail,
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    try {
      AppLogger.log('Starting P2P transfer: recipient=$recipientEmail amount=$amount $currency via $paymentMethod');
      
      // Get current user from AuthService
      AppLogger.log('Getting current user from AuthService...');
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) {
        AppLogger.log('ERROR: Transfer failed - no authenticated user');
        return {'success': false, 'error': 'User not authenticated'};
      }
      AppLogger.log('Current user ID: ${user.uid}');

      // Fetch sender profile from Firestore to ensure consistent userId and names
      AppLogger.log('Fetching sender profile from Firestore...');
      try {
        final senderDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        UserModel? senderModel;
        if (senderDoc.exists && senderDoc.data() != null) {
          try {
            final senderData = senderDoc.data() as Map<String, dynamic>;
            AppLogger.log('Sender data retrieved: ${senderData.keys.toList()}');
            senderModel = UserModel.fromMap(senderData);
            AppLogger.log('Sender profile loaded from Firestore: ${senderModel.emailAddress}');
          } catch (e) {
            AppLogger.log('Error parsing sender profile: $e');
            AppLogger.log('Error type: ${e.runtimeType}');
          }
        } else {
          AppLogger.log('Sender Firestore profile not found, falling back to Firebase Auth fields');
        }

        final senderUserId = senderModel?.userId.isNotEmpty == true ? senderModel!.userId : user.uid;
        final senderEmail = senderModel?.emailAddress.isNotEmpty == true ? senderModel!.emailAddress : (user.email ?? '');
        final senderFirstName = senderModel?.firstName.isNotEmpty == true
            ? senderModel!.firstName
            : (user.displayName?.split(' ').first ?? 'User');
        final senderLastName = senderModel?.lastName.isNotEmpty == true
            ? senderModel!.lastName
            : (user.displayName?.split(' ').skip(1).join(' ') ?? '');
        final senderPhone = senderModel?.mobile.isNotEmpty == true ? senderModel!.mobile : (user.phoneNumber ?? '');

        AppLogger.log('Sender details - ID: $senderUserId, Email: $senderEmail, Name: $senderFirstName $senderLastName');

        // Get or create Moov account for sender
        AppLogger.log('Creating/getting sender Moov account...');
        final senderMoovAccountId = await _moovService.getOrCreateUserAccount(
          userId: senderUserId,
          email: senderEmail,
          firstName: senderFirstName,
          lastName: senderLastName,
          phone: senderPhone,
        );
        AppLogger.log('Sender Moov account ID: $senderMoovAccountId');

        if (senderMoovAccountId == null) {
          AppLogger.log('ERROR: Failed to get/create Moov account for sender');
          return {'success': false, 'error': 'Failed to create sender Moov account'};
        }

        // Find recipient by email in Firestore
        AppLogger.log('Finding recipient by email: $recipientEmail');
        Map<String, dynamic>? recipientData = await _findRecipientByEmail(recipientEmail);
        if (recipientData == null) {
          AppLogger.log('Recipient not found in Firestore: $recipientEmail');
          if (MoovConfig.testMode) {
            AppLogger.log('Test mode enabled - creating synthetic recipient');
            // Create a synthetic recipient for test mode
            final localPart = recipientEmail.contains('@') ? recipientEmail.split('@').first : 'Test';
            final testRecipientId = 'test_recipient_${recipientEmail.hashCode.abs()}';
            recipientData = {
              'userId': testRecipientId,
              'email': recipientEmail,
              'firstName': localPart.isNotEmpty ? localPart : 'Test',
              'lastName': 'User',
              'phone': '',
            };
            AppLogger.log('Test mode: Using synthetic recipient $recipientEmail with ID $testRecipientId');
          } else {
            AppLogger.log('ERROR: Recipient not found and not in test mode');
            return {'success': false, 'error': 'Recipient not found'};
          }
        }

        AppLogger.log('Recipient ready: ${recipientData['email']} (${recipientData['userId']})');

        // Get or create Moov account for recipient
        AppLogger.log('Creating/getting recipient Moov account...');
        final recipientMoovAccountId = await _moovService.getOrCreateUserAccount(
          userId: recipientData['userId'],
          email: recipientData['email'],
          firstName: recipientData['firstName'],
          lastName: recipientData['lastName'],
          phone: recipientData['phone'],
        );
        AppLogger.log('Recipient Moov account ID: $recipientMoovAccountId');

        if (recipientMoovAccountId == null) {
          AppLogger.log('ERROR: Failed to get/create Moov account for recipient');
          return {'success': false, 'error': 'Failed to create recipient Moov account'};
        }

        // Ensure currency is uppercase and supported by Moov (fallback to USD in test mode)
        final normalizedCurrency = ['USD', 'GBP', 'BDT'].contains(currency.toUpperCase()) ? currency.toUpperCase() : (MoovConfig.testMode ? 'USD' : currency.toUpperCase());
        AppLogger.log('Normalized currency: $normalizedCurrency');

        // Process P2P transfer through Moov
        AppLogger.log('Processing Moov P2P transfer...');
        final transferResult = await _moovService.processP2PTransfer(
          senderAccountId: senderMoovAccountId,
          recipientAccountId: recipientMoovAccountId,
          amount: amount,
          currency: normalizedCurrency,
          description: 'P2P Transfer via $paymentMethod to $recipientEmail',
        );
        AppLogger.log('Transfer result: $transferResult');

        if (transferResult?['success'] == true) {
          AppLogger.log('Transfer succeeded: ${transferResult?['transferId']}');
        } else {
          AppLogger.log('Transfer failed: ${transferResult?['error']}');
        }

        return transferResult ?? {'success': false, 'error': 'Transfer processing failed'};
      } catch (e) {
        AppLogger.log('ERROR in Firestore operations: $e');
        AppLogger.log('Error type: ${e.runtimeType}');
        rethrow;
      }
    } catch (e) {
      AppLogger.log('ERROR in _processP2PTransfer: $e');
      AppLogger.log('Error type: ${e.runtimeType}');
      return {'success': false, 'error': 'Transfer error: ${e.toString()}'};
    }
  }

  // Find recipient user data by email
  Future<Map<String, dynamic>?> _findRecipientByEmail(String email) async {
    try {
      AppLogger.log('Searching for recipient with email: $email');
      
      // Query Firestore users collection by email_address field
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email_address', isEqualTo: email)
          .limit(1)
          .get();

      AppLogger.log('Query completed. Found ${query.docs.length} documents');

      if (query.docs.isEmpty) {
        AppLogger.log('No recipient found with email: $email');
        return null;
      }

      final data = query.docs.first.data();
      AppLogger.log('Recipient data keys: ${data.keys.toList()}');
      
      final user = UserModel.fromMap(data);
      AppLogger.log('Recipient model created successfully: ${user.emailAddress}');
      
      return {
        'userId': user.userId,
        'email': user.emailAddress,
        'firstName': user.firstName,
        'lastName': user.lastName,
        'phone': user.mobile,
      };
    } catch (e) {
      AppLogger.log('ERROR in _findRecipientByEmail: $e');
      AppLogger.log('Error type: ${e.runtimeType}');
      return null;
    }
  }
}
