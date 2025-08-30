import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:xpay/utils/utils.dart';
import 'package:xpay/widgets/inputs/multiline_text_input_widget.dart';

import '../../controller/request_controller.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/amount_input_widget.dart';
import '../../widgets/inputs/dropdown_widget.dart';
import '../../widgets/inputs/secondary_text_input_widget.dart';
import '../../widgets/primary_appbar.dart';
import '../../widgets/request_money_wallet_info_widget.dart';
import '../../widgets/subscription_guard.dart';
import '../auth/wallet_view_model.dart';

class RequestMoneyScreen extends StatefulWidget {
  const RequestMoneyScreen({super.key});

  @override
  State<RequestMoneyScreen> createState() => _RequestMoneyScreenState();
}

class _RequestMoneyScreenState extends State<RequestMoneyScreen>
    with TickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late final WalletViewModel? _walletViewModel;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _walletViewModel = Provider.of<WalletViewModel>(context, listen: false);
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
    final controller = Get.put(RequestMoneyController());
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.requestMoney.tr,
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
         customMessage: 'Request Money feature requires a premium subscription',
         child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: _bodyWidget(context, controller),
          ),
        ),
      ),
    );
  }

  // body widget contain all the widgets
  ListView _bodyWidget(
    BuildContext context,
    RequestMoneyController controller,
  ) {
    return ListView(
      shrinkWrap: true,
      children: [
        _infoInputWidget(context, controller),
        _noteWidget(context, controller),
        SizedBox(height: Dimensions.heightSize),
        _walletInfoWidget(context, controller),
        SizedBox(height: Dimensions.heightSize * 2),
        _buttonWidget(controller),
        SizedBox(height: Dimensions.heightSize * 2),
      ],
    );
  }

  Obx _infoInputWidget(
    BuildContext context,
    RequestMoneyController controller,
  ) {
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
                    child: Icon(
                      Ionicons.card_outline,
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
                          'Request Money',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Request funds from others',
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

              // Request To Email
              _buildModernLabel('Request To'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: SecondaryTextInputWidget(
                  controller: controller.requestToController,
                  validator:
                      MultiValidator([
                        RequiredValidator(errorText: 'Enter an email address'),
                        EmailValidator(
                          errorText: 'Enter a valid email address',
                        ),
                      ]).call,
                  hintText: 'Enter email address',
                  color: Colors.transparent,
                  suffixIcon: Ionicons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Ionicons.checkmark_circle,
                    color: CustomColor.successColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Strings.validUserForTransaction.tr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CustomColor.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount Input
              _buildModernLabel('Amount to Request'),
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator:
                      MultiValidator([
                        RequiredValidator(errorText: 'Please enter an amount'),
                        MinValueValidator(5, errorText: 'Minimum amount is 5'),
                      ]).call,
                  controller: controller.amountController,
                  color: Colors.transparent,
                  suffixIcon: _amountButton(context, controller),
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

  Container _amountButton(
    BuildContext context,
    RequestMoneyController controller,
  ) {
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
  }

  //  Button widget
  Container _buttonWidget(RequestMoneyController controller) {
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
        child: PrimaryButton(
          title: Strings.requestNow.tr,
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              try {
                Utils.showLoadingDialog(context);
                await _walletViewModel!.requestMoney(
                  controller.requestToController.text.trim(),
                  double.parse(controller.amountController.text.trim()),
                  controller.walletName.value,
                  controller.optionalNoteController.text.trim().isEmpty
                      ? ''
                      : controller.optionalNoteController.text.trim(),
                );
                if (context.mounted) {
                  // TODO: Add mounted check before using context in async function
                  Navigator.pop(context);
                  Utils.showDialogMessage(
                    context,
                    'Success',
                    'Your request has been sent!',
                  );
                  controller.requestToController.clear();
                  controller.amountController.clear();
                  controller.optionalNoteController.clear();
                }
              } catch (error) {
                if (context.mounted) {
                  // TODO: Add mounted check before using context in async function
                  Navigator.pop(context);
                  Utils.showDialogMessage(
                    context,
                    'Error',
                    'Error requesting money: $error',
                  );
                }
              }
            }
          },
          borderColorName: Colors.transparent,
        ),
      ),
    );
  }

  Obx _walletInfoWidget(
    BuildContext context,
    RequestMoneyController controller,
  ) {
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
        child: RequestMoneyWalletInfoWidget(
          wallet: controller.walletName.value,
          merchant:
              controller.requestToController.text.isEmpty
                  ? 'adsent@gmail.com'
                  : controller.requestToController.text,
          transferAmount:
              '${controller.amountController.text.isNotEmpty ? controller.amountController.text : '100'} ${controller.walletName.value}',
          totalCharge:
              '${controller.calculateCharge(double.parse(controller.amountController.text.isNotEmpty ? controller.amountController.text : '100'))} ${controller.walletName.value}',
          youWillGet:
              '${double.parse(controller.amountController.text.isNotEmpty ? controller.amountController.text : '100') - controller.charge.value} ${controller.walletName.value}',
          note:
              controller.optionalNoteController.text.isEmpty
                  ? Strings.addNoteHere.tr
                  : controller.optionalNoteController.text,
        ),
      );
    });
  }

  Container _noteWidget(
    BuildContext context,
    RequestMoneyController controller,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CustomColor.primaryColor.withValues(alpha: 0.8),
                      CustomColor.appBarColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Ionicons.create_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              _buildModernLabel('Add Note (Optional)'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: MultiLineTextFieldInputWidget(
              controller: controller.optionalNoteController,
              hintText: 'Enter additional notes or payment reference...',
              color: Colors.transparent,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ],
      ),
    );
  }
}
