import 'package:flutter/material.dart';

class PremiumBadgeWidget extends StatelessWidget {
  const PremiumBadgeWidget({
    super.key,
    this.size = PremiumBadgeSize.small,
    this.showText = true,
  });

  final PremiumBadgeSize size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final double iconSize = _getIconSize();
    final double fontSize = _getFontSize();
    final EdgeInsets padding = _getPadding();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.9),
            Colors.orange.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: iconSize,
          ),
          if (showText) ...[
            SizedBox(width: 4),
            Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ]
        ],
      ),
    );
  }

  double _getIconSize() {
    switch (size) {
      case PremiumBadgeSize.small:
        return 12;
      case PremiumBadgeSize.medium:
        return 14;
      case PremiumBadgeSize.large:
        return 16;
    }
  }

  double _getFontSize() {
    switch (size) {
      case PremiumBadgeSize.small:
        return 8;
      case PremiumBadgeSize.medium:
        return 10;
      case PremiumBadgeSize.large:
        return 12;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case PremiumBadgeSize.small:
        return EdgeInsets.symmetric(horizontal: 6, vertical: 2);
      case PremiumBadgeSize.medium:
        return EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case PremiumBadgeSize.large:
        return EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    }
  }
}

enum PremiumBadgeSize {
  small,
  medium,
  large,
}