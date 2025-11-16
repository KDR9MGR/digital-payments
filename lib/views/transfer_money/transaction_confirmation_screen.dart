import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:xpay/controller/transfer_money_controller.dart';
import 'package:xpay/widgets/buttons/primary_button.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widgets/primary_appbar.dart';

class TransactionConfirmationScreen extends StatefulWidget {
  const TransactionConfirmationScreen({super.key});

  @override
  State<TransactionConfirmationScreen> createState() => _TransactionConfirmationScreenState();
}

class _TransactionConfirmationScreenState extends State<TransactionConfirmationScreen>
    with TickerProviderStateMixin {
  late TransferMoneyController controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    controller = Get.find<TransferMoneyController>();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getRecipientName() {
    final recipient = controller.selectedRecipient.value;
    if (recipient == null) return 'Unknown Recipient';
    
    final firstName = recipient['firstName'] ?? recipient['first_name'] ?? '';
    final lastName = recipient['lastName'] ?? recipient['last_name'] ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    } else {
      final email = recipient['email'] ?? recipient['email_address'] ?? '';
      if (email.isNotEmpty) {
        return email.split('@').first;
      }
      return 'Unknown Recipient';
    }
  }

  String _getRecipientEmail() {
    final recipient = controller.selectedRecipient.value;
    return recipient?['email'] ?? recipient?['email_address'] ?? controller.receiverUsernameOrEmailController.text;
  }

  double _getTransferAmount() {
    return double.tryParse(controller.amountController.text) ?? 0.0;
  }

  double _getTransferFee() {
    final amount = _getTransferAmount();
    return 2.00 + (amount * 0.01); // $2 + 1% fee
  }

  double _getTotalAmount() {
    return _getTransferAmount() + _getTransferFee();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          'Confirm Transfer',
          style: CustomStyle.commonTextTitleWhite.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        appBar: AppBar(),
        backgroundColor: CustomColor.appBarColor,
        autoLeading: false,
        elevation: 0,
        appbarColor: CustomColor.appBarColor,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTransferSummaryCard(),
                const SizedBox(height: 24),
                _buildRecipientCard(),
                const SizedBox(height: 24),
                _buildAmountBredownCard(),
                const SizedBox(height: 24),
                _buildPaymentMethodCard(),
                const SizedBox(height: 32),
                _buildConfirmationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColor.primaryColor.withValues(alpha: 0.2),
            CustomColor.appBarColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Ionicons.send,
            color: CustomColor.primaryColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Transfer Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your transfer details',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Ionicons.person,
                color: CustomColor.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Recipient',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CustomColor.primaryColor.withValues(alpha: 0.2),
                child: Text(
                  _getRecipientName().isNotEmpty ? _getRecipientName()[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: CustomColor.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getRecipientName(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRecipientEmail(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountBredownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Ionicons.calculator,
                color: CustomColor.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Amount Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAmountRow('Transfer Amount', _getTransferAmount(), false),
          const SizedBox(height: 12),
          _buildAmountRow('Transfer Fee', _getTransferFee(), false),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          _buildAmountRow('Total Amount', _getTotalAmount(), true),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isTotal ? 1.0 : 0.7),
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isTotal ? CustomColor.primaryColor : Colors.white,
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Ionicons.card,
                color: CustomColor.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Method',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  _getPaymentMethodIcon(),
                  color: CustomColor.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.selectedPaymentMethod.value.isNotEmpty
                            ? controller.selectedPaymentMethod.value
                            : 'No payment method selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Secure payment processing',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon() {
    final method = controller.selectedPaymentMethod.value.toLowerCase();
    if (method.contains('bank')) return Ionicons.business;
    if (method.contains('debit')) return Ionicons.card;
    if (method.contains('credit')) return Ionicons.card;
    if (method.contains('wallet')) return Ionicons.wallet;
    return Ionicons.card;
  }

  Widget _buildConfirmationButtons() {
    return Column(
      children: [
        Obx(() => PrimaryButton(
          title: controller.isProcessingTransfer.value ? 'Processing...' : 'Confirm Transfer',
          onPressed: () {
            if (!controller.isProcessingTransfer.value) {
              controller.processTransfer();
            }
          },
          borderColorName: Colors.transparent,
        )),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'Cancel Transfer',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Ionicons.information_circle,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please review all details carefully. This transaction cannot be reversed once confirmed.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}