import 'package:flutter/material.dart';
import '../../lib/utils/custom_color.dart';
import 'mock_dimensions.dart';

class MockCustomStyle {
  // Material 3 Common Styles
  static TextStyle commonTextTitle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: MockDimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle commonLargeTextTitleWhite = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.largeTextSize,
    fontWeight: FontWeight.w700,
  );
  
  static TextStyle commonTextTitleWhite = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle commonSubTextTitle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.smallTextSize,
    fontWeight: FontWeight.w500,
  );
  
  static TextStyle commonTextSubTitleWhite = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.smallestTextSize,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle commonSubTextTitleSmall = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.smallestTextSize - 2,
    fontWeight: FontWeight.w400,
  );

  static TextStyle commonSubTextTitleBlack = TextStyle(
    color: CustomColor.onPrimaryTextColor,
    fontSize: MockDimensions.smallestTextSize,
    fontWeight: FontWeight.w400,
  );

  static TextStyle hintTextStyle = TextStyle(
    color: CustomColor.onSurfaceVariant,
    fontSize: MockDimensions.smallestTextSize + 3,
    fontWeight: FontWeight.w400,
  );

  static TextStyle onboardTitleStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.defaultTextSize,
    fontWeight: FontWeight.w500,
  );

  // Material 3 Button Styles
  static TextStyle defaultButtonStyle = TextStyle(
    color: CustomColor.onPrimaryTextColor,
    fontSize: MockDimensions.largeTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle secondaryButtonTextStyle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: MockDimensions.largeTextSize,
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
    fontSize: MockDimensions.smallTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle purposeUnselectedStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.mediumTextSize,
    fontWeight: FontWeight.w500,
  );
  
  static TextStyle sendMoneyConfirmTextStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle sendMoneyConfirmSubTextStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.smallTextSize,
    fontWeight: FontWeight.w400,
  );

  // mobile recharge
  static TextStyle purposeTextStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.smallestTextSize,
    fontWeight: FontWeight.w500,
  );

  // bank to XPay review style
  static TextStyle bankToXPayReviewStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.smallTextSize,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle bankToXPayReviewStyleSub = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.smallTextSize - 2,
    fontWeight: FontWeight.w400,
  );

  // savings section
  static TextStyle savingRules = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.mediumTextSize,
    fontWeight: FontWeight.w500,
  );

  // Material 3 specific styles
  static TextStyle cardTitleStyle = TextStyle(
    color: CustomColor.primaryTextColor,
    fontSize: MockDimensions.mediumTextSize,
    fontWeight: FontWeight.w600,
  );

  static TextStyle cardSubtitleStyle = TextStyle(
    color: CustomColor.secondaryTextColor,
    fontSize: MockDimensions.smallTextSize,
    fontWeight: FontWeight.w400,
  );

  static TextStyle chipTextStyle = TextStyle(
    color: CustomColor.primaryColor,
    fontSize: MockDimensions.smallestTextSize,
    fontWeight: FontWeight.w500,
  );
}