import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/internal_transfer_service.dart';
import '../utils/app_logger.dart';
import '../routes/routes.dart';

class InternalTransferController extends GetxController {
  final InternalTransferService _transferService = InternalTransferService();

  // Form controllers
  final TextEditingController recipientEmailController =
      TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  // Observable variables
  final RxString selectedCurrency = 'USD'.obs;
  final RxBool isLoading = false.obs;
  final RxBool isValidatingRecipient = false.obs;
  final RxBool isRecipientValid = false.obs;
  final RxString recipientName = ''.obs;
  final RxString recipientValidationMessage = ''.obs;
  final RxDouble currentBalance = 0.0.obs;
  final RxDouble transferFee = 0.0.obs;
  final RxDouble transferAmount = 0.0.obs;

  // Available currencies
  final List<String> currencies = ['USD', 'EUR', 'GBP', 'CAD'];

  // Transfer limits
  final double minTransferAmount = 1.0;
  final double maxTransferAmount = 10000.0;
  final double feePercentage = 0.0; // No fee for internal transfers
  final double fixedFee = 0.0; // No fixed fee for internal transfers

  @override
  void onInit() {
    super.onInit();
    _loadCurrentBalance();

    // Add debounced email validation
    recipientEmailController.addListener(_onEmailChanged);
    amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    recipientEmailController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  /// Load current wallet balance
  Future<void> _loadCurrentBalance() async {
    try {
      final balance = await _transferService.getWalletBalance(
        selectedCurrency.value,
      );
      currentBalance.value = balance;
    } catch (e) {
      AppLogger.error(
        'Error loading balance: $e',
        tag: 'InternalTransferController',
      );
    }
  }

  /// Handle currency change
  void onCurrencyChanged(String currency) {
    selectedCurrency.value = currency;
    _loadCurrentBalance();
    _calculateFee();
  }

  /// Handle email input changes with debouncing
  void _onEmailChanged() {
    if (recipientEmailController.text.isNotEmpty) {
      // Simple email validation
      if (GetUtils.isEmail(recipientEmailController.text)) {
        _validateRecipient();
      } else {
        isRecipientValid.value = false;
        recipientValidationMessage.value = 'Please enter a valid email address';
      }
    } else {
      isRecipientValid.value = false;
      recipientName.value = '';
      recipientValidationMessage.value = '';
    }
  }

  /// Handle amount input changes
  void _onAmountChanged() {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    transferAmount.value = amount;
    _calculateFee();
  }

  /// Validate recipient email
  Future<void> _validateRecipient() async {
    if (isValidatingRecipient.value) return;

    try {
      isValidatingRecipient.value = true;

      final result = await _transferService.validateRecipient(
        recipientEmailController.text.trim(),
      );

      isRecipientValid.value = result['valid'] ?? false;
      recipientValidationMessage.value = result['message'] ?? '';

      if (result['valid'] == true) {
        recipientName.value = result['recipientName'] ?? '';
      } else {
        recipientName.value = '';
      }
    } catch (e) {
      isRecipientValid.value = false;
      // Provide more specific error messages based on the error type
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        recipientValidationMessage.value = 'Network error. Please check your connection and try again';
      } else if (e.toString().contains('timeout')) {
        recipientValidationMessage.value = 'Request timed out. Please try again';
      } else {
        recipientValidationMessage.value = 'Unable to validate recipient. Please try again';
      }
      AppLogger.error(
        'Error validating recipient: $e',
        tag: 'InternalTransferController',
      );
    } finally {
      isValidatingRecipient.value = false;
    }
  }

  /// Calculate transfer fee
  void _calculateFee() {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    transferFee.value = (amount * feePercentage / 100) + fixedFee;
  }

  /// Get total amount (amount + fee)
  double getTotalAmount() {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    return amount + transferFee.value;
  }

  /// Validate transfer form
  String? validateForm() {
    // Check recipient
    if (recipientEmailController.text.trim().isEmpty) {
      return 'Please enter recipient email';
    }

    if (!isRecipientValid.value) {
      return 'Please enter a valid recipient email';
    }

    // Check amount
    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      return 'Please enter a valid amount';
    }

    if (amount < minTransferAmount) {
      return 'Minimum transfer amount is \$${minTransferAmount.toStringAsFixed(2)}';
    }

    if (amount > maxTransferAmount) {
      return 'Maximum transfer amount is \$${maxTransferAmount.toStringAsFixed(2)}';
    }

    // Check balance
    final totalAmount = getTotalAmount();
    if (totalAmount > currentBalance.value) {
      return 'Insufficient balance. Available: \$${currentBalance.value.toStringAsFixed(2)}';
    }

    return null;
  }

  /// Execute the transfer
  Future<void> executeTransfer() async {
    final validationError = validateForm();
    if (validationError != null) {
      Get.snackbar(
        'Validation Error',
        validationError,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;

      final amount = double.parse(amountController.text);
      final result = await _transferService.transferMoney(
        recipientEmail: recipientEmailController.text.trim(),
        amount: amount,
        currency: selectedCurrency.value,
        note:
            noteController.text.trim().isNotEmpty
                ? noteController.text.trim()
                : null,
      );

      if (result['success'] == true) {
        // Show success message
        Get.snackbar(
          'Transfer Successful',
          'Money sent successfully to ${result['recipientName']}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        // Clear form
        _clearForm();

        // Refresh balance
        await _loadCurrentBalance();

        // Navigate back or to success screen
        Get.back();
      } else {
        Get.snackbar(
          'Transfer Failed',
          result['message'] ?? 'Unknown error occurred',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Transfer Failed',
        'An error occurred while processing the transfer',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
      AppLogger.error(
        'Transfer execution error: $e',
        tag: 'InternalTransferController',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear the form
  void _clearForm() {
    recipientEmailController.clear();
    amountController.clear();
    noteController.clear();
    isRecipientValid.value = false;
    recipientName.value = '';
    recipientValidationMessage.value = '';
    transferFee.value = 0.0;
  }

  /// Navigate to transfer history
  void navigateToTransferHistory() {
    Get.toNamed(Routes.transactionsHistoryScreen);
  }

  /// Navigate back to dashboard
  void navigateToDashboard() {
    Get.toNamed(Routes.navigationScreen);
  }

  /// Refresh data
  Future<void> refreshData() async {
    await _loadCurrentBalance();
    if (recipientEmailController.text.isNotEmpty &&
        GetUtils.isEmail(recipientEmailController.text)) {
      await _validateRecipient();
    }
  }
}
