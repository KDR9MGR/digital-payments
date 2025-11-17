import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import '../data/user_model.dart';
import '../views/transfer_money/transaction_success_screen.dart';

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
  
  // Selected recipient for transfer
  Rx<Map<String, dynamic>?> selectedRecipient = Rx<Map<String, dynamic>?>(null);
  
  // Sila account IDs for transfer processing
  String? senderSilaAccountId;
  String? recipientSilaAccountId;
  
  

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
      
      // Process actual transfer using alternative payment processor
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
        
        // Get recipient name for success screen
        String recipientName = 'Unknown Recipient';
        if (selectedRecipient.value != null) {
          final firstName = selectedRecipient.value!['firstName'] ?? selectedRecipient.value!['first_name'] ?? '';
          final lastName = selectedRecipient.value!['lastName'] ?? selectedRecipient.value!['last_name'] ?? '';
          
          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            recipientName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            recipientName = firstName;
          } else if (lastName.isNotEmpty) {
            recipientName = lastName;
          } else {
            final email = selectedRecipient.value!['email'] ?? selectedRecipient.value!['email_address'] ?? recipient;
            if (email.isNotEmpty) {
              recipientName = email.split('@').first;
            }
          }
        } else {
          recipientName = recipient.split('@').first;
        }
        
        // Navigate to success screen with transaction details
        Get.to(() => TransactionSuccessScreen(
          transactionId: transferResult['transferId'] ?? 'N/A',
          amount: amount,
          recipientName: recipientName,
          recipientEmail: recipient,
          currency: currency,
          timestamp: DateTime.now(),
        ));
        
        // Clear form fields
        receiverUsernameOrEmailController.clear();
        amountController.text = '0';
        selectedRecipient.value = null;
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
      
      // Show detailed error dialog instead of snackbar
      Get.dialog(
        AlertDialog(
          title: Text('Transfer Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('An error occurred while processing your transfer:'),
              SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
              SizedBox(height: 16),
              Text('Please check:'),
              Text('• Internet connection'),
              Text('• Recipient email is valid'),
              Text('• Transfer amount is valid'),
              Text('• Try again in a few moments'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      isProcessingTransfer.value = false;
    }
  }

  void navigateToTransferMoneyScanQrCodeScreen() {
    Get.toNamed(Routes.transferMoneyScanQrCodeScreen);
  }

  // Process P2P transfer using alternative payment processor
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

        // Get sender account information
        AppLogger.log('Getting sender account information...');
        senderSilaAccountId = senderUserId; // Use user ID as account identifier
        AppLogger.log('Sender account ID: $senderSilaAccountId');

        if (senderSilaAccountId == null) {
          AppLogger.log('ERROR: Failed to get sender account');
          return {'success': false, 'error': 'Failed to get sender account'};
        }

        // Find recipient by email in Firestore
        AppLogger.log('Finding recipient by email: $recipientEmail');
        Map<String, dynamic>? recipientData = await _findRecipientByEmail(recipientEmail);
        if (recipientData == null) {
          AppLogger.log('Recipient not found in Firestore: $recipientEmail');
          AppLogger.log('ERROR: Recipient not found');
          return {'success': false, 'error': 'Recipient not found'};
        }

        AppLogger.log('Recipient ready: ${recipientData['email']} (${recipientData['userId']})');

        // Set recipient account ID (simplified for now)
        AppLogger.log('Setting recipient account ID...');
        recipientSilaAccountId = recipientData['userId'];
        AppLogger.log('Recipient account ID: $recipientSilaAccountId');

        if (recipientSilaAccountId == null) {
          AppLogger.log('ERROR: Failed to get/create Sila account for recipient');
          return {'success': false, 'error': 'Failed to create recipient Sila account'};
        }

        // Ensure currency is uppercase and supported (fallback to USD in test mode)
        final normalizedCurrency = ['USD', 'GBP', 'BDT'].contains(currency.toUpperCase()) ? currency.toUpperCase() : 'USD';
        AppLogger.log('Normalized currency: $normalizedCurrency');

        // TODO: Implement P2P transfer logic with appropriate payment service
        AppLogger.log('Processing P2P transfer...');
        // For now, simulate a successful transfer
        final transferResult = {'success': true, 'transferId': 'mock_transfer_${DateTime.now().millisecondsSinceEpoch}'};
        AppLogger.log('Transfer result: $transferResult');

        if (transferResult['success'] == true) {
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
