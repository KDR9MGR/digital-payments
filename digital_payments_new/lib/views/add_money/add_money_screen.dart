import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:xpay/controller/add_money_controller.dart';
import 'package:xpay/controller/subscription_controller.dart';
import 'package:xpay/utils/input_formatters.dart';
import 'package:xpay/utils/utils.dart';
import 'package:xpay/views/auth/user_provider.dart';
import 'package:xpay/views/auth/wallet_view_model.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widgets/add_money_wallet_info_widget.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/go_premium_widget.dart';
import '../../widgets/subscription_guard.dart';

import '../../widgets/inputs/dropdown_widget.dart';
import '../../widgets/primary_appbar.dart';

class AddMoneyMoneyScreen extends StatefulWidget {
  const AddMoneyMoneyScreen({super.key});

  @override
  State<AddMoneyMoneyScreen> createState() => _AddMoneyMoneyScreenState();
}

class _AddMoneyMoneyScreenState extends State<AddMoneyMoneyScreen>
    with TickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  final controller = Get.put(AddMoneyController());
  late final WalletViewModel? _walletViewModel;
  late final UserProvider _userProvider;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _walletViewModel = Provider.of<WalletViewModel>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
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
          Strings.addMoney.tr,
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
            onPressed: () {
              Get.back();
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
        ),
      ),
      body: SubscriptionGuard(
        customMessage: 'Add Money feature requires a premium subscription',
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
        // Show Go Premium widget if user doesn't have active subscription
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
                          CustomColor.successColor,
                          Colors.green.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CustomColor.successColor.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Ionicons.add_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Money',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Top up your wallet balance',
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
              _buildModernLabel('Your Wallet'),
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

              // Gateway Selection
              _buildModernLabel('Payment Gateway'),
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
                  items: controller.gatewayList,
                  color: Colors.transparent,
                  hintText: Strings.selectTermHint.tr,
                  value: controller.gatewayName.value,
                  onChanged: (value) {
                    controller.gatewayName.value = value!;
                  },
                ),
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
                child: TextFormField(
                  controller: controller.amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  validator:
                      MultiValidator([
                        RequiredValidator(errorText: 'Please enter an amount'),
                        MinValueValidator(5, errorText: 'Minimum amount is 5'),
                      ]).call,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: _amountButton(context),
                  ),
                ),
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
                          '${Strings.limit.tr}: 5.00 - 2,500.00 USD',
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
              colors: [CustomColor.successColor, Colors.green.shade400],
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
            colors: [CustomColor.successColor, Colors.green.shade400],
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: CustomColor.successColor.withValues(alpha: 0.3),
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
            colors: [CustomColor.successColor, Colors.green.shade400],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CustomColor.successColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: PrimaryButton(
          title: Strings.addMoney.tr,
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              _showCardDetailsDialog(context, _walletViewModel!);
            }
          },
          borderColorName: Colors.transparent,
        ),
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
        child: AddMoneyWalletInfoWidget(
          wallet: controller.walletName.value,
          gateWay: controller.gatewayName.value,
          addAmount:
              '${controller.amountController.text.isNotEmpty ? controller.amountController.text : '100'} ${controller.walletName.value}',
          totalCharge:
              '${controller.calculateCharge(double.parse(controller.amountController.text.isNotEmpty ? controller.amountController.text : '100'))} ${controller.walletName.value}',
          payableAmount:
              '${double.parse(controller.amountController.text.isNotEmpty ? controller.amountController.text : '100') + controller.charge.value} ${controller.walletName.value}',
        ),
      );
    });
  }

  void _showCardDetailsDialog(
    BuildContext context,
    WalletViewModel walletViewModel,
  ) {
    final formKey = GlobalKey<FormState>();
    final cardNumberController = TextEditingController();
    final expiryDateController = TextEditingController();
    final cvvController = TextEditingController();
    final cardHolderNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: CustomColor.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [CustomColor.successColor, Colors.green.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Ionicons.card_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Enter Card Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModernTextField(
                    controller: cardNumberController,
                    labelText: 'Card Number',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (value.length < 16) {
                        return 'Card number must be 16 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: expiryDateController,
                    labelText: 'Expiry Date (MM/YY)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ExpiryDateInputFormatter()],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter expiry date';
                      }
                      if (!RegExp(
                        r'^\d{2}/\d{2}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid expiry date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: cvvController,
                    labelText: 'CVV',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter CVV';
                      }
                      if (value.length < 3) {
                        return 'CVV must be 3 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: cardHolderNameController,
                    labelText: 'Cardholder Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter cardholder name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [CustomColor.successColor, Colors.green.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context); // Close the dialog
                    Utils.showLoadingDialog(context);
                    try {
                      await walletViewModel.addMoney(
                        double.parse(controller.amountController.text.trim()),
                        controller.walletName.value,
                      );
                      await _userProvider.fetchUserDetails();
                      if (context.mounted) {
                        Navigator.pop(context); // Close the loading dialog
                        Utils.showDialogMessage(
                          context,
                          'Success',
                          'Amount has been added to wallet!',
                        );
                        controller.amountController.clear();
                      }
                    } catch (error) {
                      Navigator.pop(context); // Close the loading dialog
                      Utils.showDialogMessage(
                        context,
                        'Error',
                        'Something went wrong: $error',
                      );
                    }
                  }
                },
                child: Text(
                  'Submit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        inputFormatters: inputFormatters,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
