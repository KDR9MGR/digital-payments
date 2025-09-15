import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:ionicons/ionicons.dart';
import 'package:xpay/controller/transfer_money_controller.dart';
import 'package:xpay/controller/subscription_controller.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../utils/utils.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/amount_input_widget.dart';
import '../../widgets/inputs/dropdown_widget.dart';
import '../../widgets/inputs/validated_dropdown_widget.dart';
import '../../widgets/inputs/secondary_text_input_widget.dart';
import '../../widgets/user_search_widget.dart';
import 'transaction_confirmation_screen.dart';
import 'transaction_history_screen.dart';
import '../../widgets/primary_appbar.dart';
import '../../widgets/wallet_info_widget.dart';
import '../../widgets/go_premium_widget.dart';
import '../../widgets/subscription_guard.dart';

class TransferMoneyScreen extends StatefulWidget {
  const TransferMoneyScreen({super.key});

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends State<TransferMoneyScreen>
    with TickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late TransferMoneyController controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    controller = Get.put(TransferMoneyController());
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.transferMoneyTitle.tr,
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
        action: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: IconButton(
              onPressed: () => Get.to(() => const TransactionHistoryScreen()),
              icon: Icon(Ionicons.receipt_outline, color: Colors.white, size: 20),
              tooltip: 'Transaction History',
            ),
          ),
        ],
      ),
      body: SubscriptionGuard(
        customMessage: 'Transfer money feature requires a premium subscription. Upgrade now to send money securely.',
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: _bodyWidget(context),
          ),
        ),
      ),
    );
  }

  // body widget contain all the widgets
  ListView _bodyWidget(BuildContext context) {
    final subscriptionController = Get.find<SubscriptionController>();
    return ListView(
      shrinkWrap: true,
      children: [
        _infoInputWidget(context),
        _walletInfoWidget(context),
        // Show Go Premium widget only if user doesn't have active subscription
        Obx(() {
          if (!subscriptionController.hasActiveSubscription) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: GoPremiumBanner(
                showCloseButton: false,
              ),
            );
          }
          return SizedBox.shrink();
        }),
        SizedBox(height: Dimensions.heightSize * 2),
        _buttonWidget(context),
        SizedBox(height: Dimensions.heightSize * 2),
      ],
    );
  }

  Obx _infoInputWidget(BuildContext context) {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CustomColor.surfaceColor.withValues(alpha: 0.9),
              CustomColor.surfaceColor.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          CustomColor.primaryColor,
                          CustomColor.appBarColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CustomColor.primaryColor.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Ionicons.send, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Money',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Transfer funds securely',
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
              const SizedBox(height: 32),

              // Wallet Selection
              _buildModernLabel('Sender'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: DropDownInputWidget(
                  items: controller.walletList,
                  color: Colors.transparent,
                  hintText: Strings.selectTermHint.tr,
                  value: controller.walletName.value,
                  onChanged: (value) {
                    controller.walletName.value = value!;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Recipient Search
              _buildModernLabel('Receiver'),
              const SizedBox(height: 12),
              UserSearchWidget(
                controller: controller.receiverUsernameOrEmailController,
                hintText: 'Search by email or phone number',
                onUserSelected: (user) {
                  controller.selectedRecipient.value = user;
                },
                onScanQR: () {
                  controller.navigateToTransferMoneyScanQrCodeScreen();
                },
              ),
              const SizedBox(height: 24),

              // Amount Input
              _buildModernLabel('Amount'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: AmountInputWidget(
                  hintText: '0.00',
                  validator:
                      MultiValidator([
                        RequiredValidator(errorText: 'Please enter an amount'),
                        MinValueValidator(
                          5,
                          errorText: 'Minimum amount is 5.00',
                        ),
                        MaxValueValidator(
                          2500,
                          errorText: 'Maximum amount is 2500.00',
                        ),
                      ]).call,
                  controller: controller.amountController,
                  color: Colors.transparent,
                  suffixIcon: _amountButton(context),
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method Selection
              _buildModernLabel('Payment Method'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Obx(() {
                  // Ensure payment methods are available
                  controller.refreshPaymentMethods();
                  return ValidatedDropDownInputWidget(
                    items: controller.paymentMethods,
                    color: Colors.transparent,
                    hintText: 'Select Payment Method',
                    value: controller.getCurrentPaymentMethod().isEmpty 
                        ? null 
                        : controller.getCurrentPaymentMethod(),
                    onChanged: (value) {
                      controller.selectedPaymentMethod.value = value ?? '';
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a payment method';
                      }
                      if (!controller.paymentMethods.contains(value)) {
                        return 'Invalid payment method selected';
                      }
                      return null;
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Limit and charge info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Ionicons.information_circle_outline,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${Strings.limit}: 5.00 - 2,500.00 USD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Ionicons.card_outline,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${Strings.charge.tr}: 2.00 USD + 1%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildModernLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [CustomColor.primaryColor, CustomColor.appBarColor],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Obx _amountButton(BuildContext context) {
    return Obx(() {
      return Container(
        width: MediaQuery.of(context).size.width * 0.20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CustomColor.primaryColor, CustomColor.appBarColor],
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: CustomColor.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              controller.walletName.value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: Dimensions.mediumTextSize,
              ),
            ),
          ],
        ),
      );
    });
  }

  //  Button widget
  Container _buttonWidget(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [CustomColor.primaryColor, CustomColor.appBarColor],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CustomColor.primaryColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Obx(() => PrimaryButton(
          title: controller.isProcessingTransfer.value 
              ? 'Processing...' 
              : Strings.transferNow.tr,
          onPressed: () {
            if (!controller.isProcessingTransfer.value && formKey.currentState!.validate()) {
              // Validate form before proceeding
              if (controller.selectedRecipient.value == null) {
                Get.snackbar(
                  'Error',
                  'Please select a recipient',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (controller.amountController.text.isEmpty || 
                  double.tryParse(controller.amountController.text) == null ||
                  double.parse(controller.amountController.text) <= 0) {
                Get.snackbar(
                  'Error',
                  'Please enter a valid amount',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              if (controller.selectedPaymentMethod.value.isEmpty) {
                Get.snackbar(
                  'Error',
                  'Please select a payment method',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              
              // Navigate to confirmation screen
              Get.to(() => const TransactionConfirmationScreen());
            }
          },
          borderColorName: Colors.transparent,
        )),
      ),
    );
  }

  Obx _walletInfoWidget(BuildContext context) {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CustomColor.surfaceColor.withValues(alpha: 0.8),
              CustomColor.surfaceColor.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: WalletInfoWidget(
          wallet: controller.walletName.value,
          recipient:
              controller.receiverUsernameOrEmailController.text.isEmpty
                  ? 'adsent@gmail.com'
                  : controller.receiverUsernameOrEmailController.text,
          transferAmount:
              controller.amountController.text.isEmpty
                  ? '0 ${controller.walletName.value}'
                  : '${controller.amountController.text} ${controller.walletName.value}',
          totalCharge:
              controller.amountController.text.isEmpty
                  ? '0 ${controller.walletName.value}'
                  : '${controller.calculateCharge(double.tryParse(controller.amountController.text) ?? 0)} ${controller.walletName.value}',
          payableAmount:
              controller.amountController.text.isEmpty
                  ? '0 ${controller.walletName.value}'
                  : '${(double.tryParse(controller.amountController.text) ?? 0) + controller.charge.value} ${controller.walletName.value}',
        ),
      );
    });
  }
}

class MaxValueValidator extends TextFieldValidator {
  final int max;
  MaxValueValidator(this.max, {String? errorText})
    : super(errorText ?? 'Value cannot be greater than $max');

  @override
  bool get ignoreEmptyValues => true;

  @override
  bool isValid(String? value) {
    if (value == null || value.isEmpty) {
      return true;
    }
    final int? number = int.tryParse(value);
    if (number == null) {
      return true;
    }
    return number <= max;
  }
}
