import 'package:flutter/material.dart';

import 'custom_color.dart';
import 'dimensions.dart';

class CustomStyle {
  // Material 3 Common Styles
  static var commonTextTitle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var commonLargeTextTitleWhite = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.largeTextSize,
    fontWeight: FontWeight.w700,
  );
  
  static var commonTextTitleWhite = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var commonSubTextTitle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w500,
  );
  
  static var commonTextSubTitleWhite = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w400,
  );
  
  static var commonSubTextTitleSmall = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallestTextSize - 2,
    fontWeight: FontWeight.w400,
  );

  static var commonSubTextTitleBlack = TextStyle(
    color: CustomColor.onPrimaryTextColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w400,
  );

  static var hintTextStyle = TextStyle(
    color: CustomColor.onSurfaceVariant,
    fontSize: Dimensions.smallestTextSize + 3,
    fontWeight: FontWeight.w400,
  );

  static var onboardTitleStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.defaultTextSize,
    fontWeight: FontWeight.w500,
  );

  // Material 3 Button Styles
  static var defaultButtonStyle = TextStyle(
    color: CustomColor.onPrimaryTextColor,
    fontSize: Dimensions.largeTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var secondaryButtonTextStyle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: Dimensions.largeTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var secondaryButtonStyle = ElevatedButton.styleFrom(
    elevation: 0,
    backgroundColor: CustomColor.surfaceColor,
    foregroundColor: CustomColor.primaryColor,
    side: BorderSide(
      color: CustomColor.primaryColor,
      width: 1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  // Category
  static var categoryButtonStyle = ElevatedButton.styleFrom(
    elevation: 0,
    backgroundColor: CustomColor.surfaceColor,
    foregroundColor: CustomColor.primaryTextColor,
    side: BorderSide(
      color: CustomColor.outlineColor,
      width: 1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  // Send money
  static var sendMoneyTextStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var purposeUnselectedStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w500,
  );
  
  static var sendMoneyConfirmTextStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var sendMoneyConfirmSubTextStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w400,
  );

  // mobile recharge
  static var purposeTextStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w500,
  );

  // bank to XPay review style
  static var bankToXPayReviewStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static var bankToXPayReviewStyleSub = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallTextSize - 2,
    fontWeight: FontWeight.w400,
  );

  // savings section
  static var savingRules = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w500,
  );

  // Material 3 specific styles
  static var cardTitleStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );

  static var cardSubtitleStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w400,
  );

  static var chipTextStyle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w500,
  );
}
