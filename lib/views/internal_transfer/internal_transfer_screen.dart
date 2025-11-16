import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:ionicons/ionicons.dart';
import '../../controller/internal_transfer_controller.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../utils/utils.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/amount_input_widget.dart';
import '../../widgets/inputs/dropdown_widget.dart';
import '../../widgets/inputs/secondary_text_input_widget.dart';
import '../../widgets/primary_appbar.dart';

class InternalTransferScreen extends StatefulWidget {
  const InternalTransferScreen({super.key});

  @override
  State<InternalTransferScreen> createState() => _InternalTransferScreenState();
}

class _InternalTransferScreenState extends State<InternalTransferScreen>
    with TickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late InternalTransferController controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    controller = Get.put(InternalTransferController());
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
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
          'Internal Transfer',
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
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
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
              onPressed: controller.navigateToTransferHistory,
              icon: const Icon(
                Ionicons.time_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: _bodyWidget(context),
          ),
        ),
      ),
    );
  }

  Widget _bodyWidget(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _balanceCard(),
          const SizedBox(height: 24),
          _transferForm(),
          const SizedBox(height: 24),
          _transferButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CustomColor.primaryColor.withOpacity(0.8),
              CustomColor.appBarColor.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CustomColor.primaryColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Ionicons.wallet_outline,
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
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.currentBalance.value.toStringAsFixed(2)} ${controller.selectedCurrency.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: controller.refreshData,
                  icon: Icon(
                    Ionicons.refresh_outline,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _transferForm() {
    return Container(
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
            color: Colors.black.withValues(alpha: 0.1),
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
            // Header
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
                        color: CustomColor.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Ionicons.send,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send Money',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Transfer funds instantly',
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

            // Currency Selection
            _buildLabel('Currency'),
            const SizedBox(height: 12),
            Obx(
              () => Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: DropDownInputWidget(
                  items: controller.currencies,
                  color: Colors.transparent,
                  hintText: 'Select Currency',
                  value: controller.selectedCurrency.value,
                  onChanged: (value) => controller.onCurrencyChanged(value!),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recipient Email
            _buildLabel('Recipient Email'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SecondaryTextInputWidget(
                controller: controller.recipientEmailController,
                validator:
                    MultiValidator([
                      RequiredValidator(errorText: 'Enter recipient email'),
                      EmailValidator(errorText: 'Enter a valid email address'),
                    ]).call,
                hintText: 'Enter recipient email address',
                color: Colors.transparent,
                keyboardType: TextInputType.emailAddress,
                suffixIcon: Icons.email,
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.recipientName.value.isNotEmpty) {
                return Row(
                  children: [
                    Icon(
                      Ionicons.checkmark_circle,
                      color: CustomColor.successColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recipient: ${controller.recipientName.value}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: CustomColor.successColor,
                      ),
                    ),
                  ],
                );
              }
              if (controller.recipientValidationMessage.value.isNotEmpty &&
                  !controller.isRecipientValid.value) {
                return Row(
                  children: [
                    Icon(
                      Ionicons.alert_circle,
                      color: Colors.red.shade400,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.recipientValidationMessage.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 24),

            // Amount Input
            _buildLabel('Amount'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: AmountInputWidget(
                hintText: '0.00',
                validator:
                    MultiValidator([
                      RequiredValidator(errorText: 'Please enter an amount'),
                      MinValueValidator(
                        controller.minTransferAmount,
                        errorText:
                            'Minimum amount is \$${controller.minTransferAmount.toStringAsFixed(2)}',
                      ),
                      // MaxValueValidator(
                      //   controller.maxTransferAmount.toInt(),
                      //   errorText: 'Maximum amount is \$${controller.maxTransferAmount.toStringAsFixed(2)}',
                      // ),
                    ]).call,
                controller: controller.amountController,
                color: Colors.transparent,
              ),
            ),
            const SizedBox(height: 24),

            // Note (Optional)
            _buildLabel('Note (Optional)'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SecondaryTextInputWidget(
                controller: controller.noteController,
                hintText: 'Add a note for this transfer',
                color: Colors.transparent,
              ),
            ),
            const SizedBox(height: 24),

            // Transfer Summary
            Obx(() {
              if (controller.transferAmount.value > 0) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transfer Amount:',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${controller.transferAmount.value.toStringAsFixed(2)} ${controller.selectedCurrency.value}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transfer Fee:',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'FREE',
                            style: TextStyle(
                              color: CustomColor.successColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${controller.getTotalAmount().toStringAsFixed(2)} ${controller.selectedCurrency.value}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _transferButton() {
    return Obx(
      () => PrimaryButton(
        title: controller.isLoading.value ? 'Processing...' : 'Send Money',
        onPressed:
            controller.isLoading.value
                ? () {}
                : () => controller.executeTransfer(),
        borderColorName: CustomColor.primaryColor,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
