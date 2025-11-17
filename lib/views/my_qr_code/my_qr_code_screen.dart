import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:xpay/routes/routes.dart';

import 'package:firebase_auth/firebase_auth.dart';
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
          child: _bodyWidget(context, qrService),
        ),
      ),
    );
  }

  // body widget contain all the widgets
  Widget _bodyWidget(BuildContext context, QrGenerationService qrService) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Dimensions.marginSize),
      child: Column(
        children: [
          _qrCodeDisplayWidget(context, qrService),
          SizedBox(height: Dimensions.heightSize * 2),
          _qrCodeDisplayWidget(context, qrService),
          SizedBox(height: Dimensions.heightSize * 2),
          _actionButtonsWidget(context),
        ],
      ),
    );
  }

  // Widget for when no bank accounts are available
  

  // Bank account selector widget
  

  // QR code display widget
  Widget _qrCodeDisplayWidget(BuildContext context, QrGenerationService qrService) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final qrData = qrService.generateUserQrData(uid);
    
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
            qrService.getUserQrDisplayText(uid),
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
  Widget _actionButtonsWidget(BuildContext context) {
    return Column(
      children: [
        PrimaryButton(
          title: 'Copy QR Data',
          onPressed: () {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final qrData = QrGenerationService.instance.generateUserQrData(uid);
            Clipboard.setData(ClipboardData(text: qrData));
            Get.snackbar('Success', 'QR data copied to clipboard');
          },
          borderColorName: CustomColor.primaryColor,
        ),
        SizedBox(height: Dimensions.heightSize),
        
      ],
    );
  }
}
