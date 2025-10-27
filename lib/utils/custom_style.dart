import 'package:flutter/material.dart';

import 'custom_color.dart';
import 'dimensions.dart';

class CustomStyle {
  // Material 3 Common Styles
  static TextStyle commonTextTitle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle commonLargeTextTitleWhite = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.largeTextSize,
    fontWeight: FontWeight.w700,
  );
  
  static TextStyle commonTextTitleWhite = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle commonSubTextTitle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w500,
  );
  
  static TextStyle commonTextSubTitleWhite = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle commonSubTextTitleSmall = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallestTextSize - 2,
    fontWeight: FontWeight.w400,
  );

  static TextStyle commonSubTextTitleBlack = TextStyle(
    color: CustomColor.onPrimaryTextColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w400,
  );

  static TextStyle hintTextStyle = TextStyle(
    color: CustomColor.onSurfaceVariant,
    fontSize: Dimensions.smallestTextSize + 3,
    fontWeight: FontWeight.w400,
  );

  static TextStyle onboardTitleStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.defaultTextSize,
    fontWeight: FontWeight.w500,
  );

  // Material 3 Button Styles
  static TextStyle defaultButtonStyle = TextStyle(
    color: CustomColor.onPrimaryTextColor,
    fontSize: Dimensions.largeTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle secondaryButtonTextStyle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: Dimensions.largeTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
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
  static ButtonStyle categoryButtonStyle = ElevatedButton.styleFrom(
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
  static TextStyle sendMoneyTextStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle purposeUnselectedStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w500,
  );
  
  static TextStyle sendMoneyConfirmTextStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle sendMoneyConfirmSubTextStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w400,
  );

  // mobile recharge
  static TextStyle purposeTextStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w500,
  );

  // bank to XPay review style
  static TextStyle bankToXPayReviewStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle bankToXPayReviewStyleSub = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallTextSize - 2,
    fontWeight: FontWeight.w400,
  );

  // savings section
  static TextStyle savingRules = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w500,
  );

  // Material 3 specific styles
  static TextStyle cardTitleStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: Dimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );

  static TextStyle cardSubtitleStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: Dimensions.smallTextSize,
    fontWeight: FontWeight.w400,
  );

  static TextStyle chipTextStyle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: Dimensions.smallestTextSize,
    fontWeight: FontWeight.w500,
  );
}
