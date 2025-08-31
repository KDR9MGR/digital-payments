import 'package:flutter/material.dart';

import '../utils/custom_color.dart';
import '../utils/dimensions.dart';
import 'premium_badge_widget.dart';

class TransactionsItemWidget extends StatelessWidget {
  const TransactionsItemWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.dateAndTime,
    required this.phoneNumber,
    required this.transactionId,
    required this.amount,
    required this.isMoneyOut,
    this.isPremiumUser = false,
  });
  final String imagePath;
  final String title;
  final String dateAndTime;
  final String phoneNumber;
  final String transactionId;
  final String amount;
  final bool isMoneyOut;
  final bool isPremiumUser;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 8,
      child: Row(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height / 10,
            width: MediaQuery.of(context).size.height / 12,
            child: CircleAvatar(
              backgroundColor: CustomColor.primaryColor.withValues(alpha: 0.5),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(
            width: Dimensions.widthSize,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: CustomColor.primaryTextColor,
                                fontSize: Dimensions.smallTextSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isPremiumUser) ...[
                            SizedBox(width: 8),
                            PremiumBadgeWidget(
                              size: PremiumBadgeSize.small,
                              showText: false,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      dateAndTime,
                      style: TextStyle(
                        color: CustomColor.primaryTextColor.withValues(alpha: 0.8),
                        fontSize: Dimensions.smallestTextSize * 0.8,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ],
                 ),
                SizedBox(
                  height: Dimensions.heightSize * 0.5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Trans ID: $transactionId',
                        style: TextStyle(
                          color: CustomColor.primaryTextColor.withValues(alpha: 0.5),
                          fontSize: Dimensions.smallestTextSize * 0.8,
                          fontWeight: FontWeight.w200,
                        ),
                      ),
                    ),
                    Text(
                      '- \$ $amount',
                      style: TextStyle(
                        color: isMoneyOut ? Colors.red : Colors.green,
                        fontSize: Dimensions.smallestTextSize * 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
