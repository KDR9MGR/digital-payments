import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:digital_payments_fixed/routes/routes.dart';

import '../../controller/bank_accounts_controller.dart';
import '../../data/bank_account_model.dart';
import '../../services/qr_generation_service.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/primary_appbar.dart';
import '../../widgets/subscription_guard.dart';

class MyQrCodeScreen extends StatelessWidget {
  const MyQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bankController = Get.find<BankAccountsController>();
    final qrService = QrGenerationService.instance;
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.myQRcode.tr,
          style: CustomStyle.commonTextTitleWhite,
        ),
        appBar: AppBar(),
        backgroundColor: CustomColor.primaryColor,
        autoLeading: false,
        elevation: 1,
        appbarColor: CustomColor.secondaryColor,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: Dimensions.iconSizeDefault * 1.4,
          ),
        ),
      ),
      body: SubscriptionGuard(
        customMessage: 'My QR Code feature requires a premium subscription. Upgrade now to generate and share your QR code.',
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Obx(() => _bodyWidget(context, bankController, qrService)),
        ),
      ),
    );
  }

  // body widget contain all the widgets
  Widget _bodyWidget(BuildContext context, BankAccountsController bankController, QrGenerationService qrService) {
    if (bankController.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (bankController.bankAccounts.isEmpty) {
      return _noBankAccountsWidget(context, bankController);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(Dimensions.marginSize),
      child: Column(
        children: [
          _bankAccountSelectorWidget(context, bankController),
          SizedBox(height: Dimensions.heightSize * 2),
          _qrCodeDisplayWidget(context, bankController, qrService),
          SizedBox(height: Dimensions.heightSize * 2),
          _actionButtonsWidget(context, bankController),
        ],
      ),
    );
  }

  // Widget for when no bank accounts are available
  Widget _noBankAccountsWidget(BuildContext context, BankAccountsController bankController) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Dimensions.marginSize),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            SizedBox(height: Dimensions.heightSize * 2),
            Text(
              'No Bank Accounts Found',
              style: CustomStyle.commonTextTitleWhite,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Dimensions.heightSize),
            Text(
              'Add a bank account to generate QR codes for payments',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: Dimensions.mediumTextSize,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Dimensions.heightSize * 3),
            PrimaryButton(
              title: 'Add Bank Account',
              onPressed: () {
                Get.toNamed(Routes.bankInfoScreen);
              },
              borderColorName: CustomColor.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // Bank account selector widget
  Widget _bankAccountSelectorWidget(BuildContext context, BankAccountsController bankController) {
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.secondaryColor,
        borderRadius: BorderRadius.circular(Dimensions.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Bank Account',
            style: CustomStyle.commonTextTitleWhite,
          ),
          SizedBox(height: Dimensions.heightSize),
          DropdownButtonFormField<BankAccountModel>(
            initialValue: bankController.selectedBankAccount,
            decoration: InputDecoration(
              filled: true,
              fillColor: CustomColor.primaryColor.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Dimensions.radius * 0.5),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: CustomColor.primaryColor,
            style: TextStyle(color: Colors.white),
            items: bankController.bankAccounts.map((account) {
              return DropdownMenuItem<BankAccountModel>(
                value: account,
                child: Text(
                  '${account.bankName} - ${account.maskedAccountNumber}',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (BankAccountModel? account) {
              if (account != null) {
                bankController.setSelectedAccount(account);
              }
            },
          ),
        ],
      ),
    );
  }

  // QR code display widget
  Widget _qrCodeDisplayWidget(BuildContext context, BankAccountsController bankController, QrGenerationService qrService) {
    final selectedAccount = bankController.selectedBankAccount;
    
    if (selectedAccount == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: CustomColor.secondaryColor,
          borderRadius: BorderRadius.circular(Dimensions.radius),
        ),
        child: Center(
          child: Text(
            'Select a bank account to generate QR code',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: Dimensions.mediumTextSize,
            ),
          ),
        ),
      );
    }

    if (!qrService.canGenerateQr(selectedAccount)) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: CustomColor.secondaryColor,
          borderRadius: BorderRadius.circular(Dimensions.radius),
        ),
        child: Center(
          child: Text(
            'Selected account has incomplete information',
            style: TextStyle(
              color: Colors.red.withValues(alpha: 0.7),
              fontSize: Dimensions.mediumTextSize,
            ),
          ),
        ),
      );
    }

    final qrData = qrService.generateQrData(selectedAccount);
    
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.secondaryColor,
        borderRadius: BorderRadius.circular(Dimensions.radius),
      ),
      child: Column(
        children: [
          Text(
            'Payment QR Code',
            style: CustomStyle.commonTextTitleWhite,
          ),
          SizedBox(height: Dimensions.heightSize),
          Container(
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Dimensions.radius * 0.5),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          SizedBox(height: Dimensions.heightSize),
          Text(
            qrService.getQrDisplayText(selectedAccount),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: Dimensions.smallTextSize,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Action buttons widget
  Widget _actionButtonsWidget(BuildContext context, BankAccountsController bankController) {
    return Column(
      children: [
        PrimaryButton(
          title: 'Copy QR Data',
          onPressed: () {
            final selectedAccount = bankController.selectedBankAccount;
            if (selectedAccount != null) {
              final qrData = QrGenerationService.instance.generateQrData(selectedAccount);
              Clipboard.setData(ClipboardData(text: qrData));
              Get.snackbar('Success', 'QR data copied to clipboard');
            }
          },
          borderColorName: CustomColor.primaryColor,
        ),
        SizedBox(height: Dimensions.heightSize),
        PrimaryButton(
          title: 'Manage Bank Accounts',
          onPressed: () {
            Get.toNamed(Routes.bankInfoScreen);
          },
          borderColorName: CustomColor.secondaryColor,
        ),
      ],
    );
  }
}
