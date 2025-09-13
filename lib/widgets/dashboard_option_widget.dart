import 'package:flutter/material.dart';

import '../utils/custom_color.dart';

import '../utils/dimensions.dart';

class DashboardOptionWidget extends StatelessWidget {
  const DashboardOptionWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: CustomColor.surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: CustomColor.outlineColor,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CustomColor.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: CustomColor.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(height: Dimensions.heightSize),
                Text(
                  title,
                  style: TextStyle(
                    color: CustomColor.primaryTextColor,
                    fontSize: Dimensions.smallTextSize,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: CustomColor.secondaryTextColor,
                    fontSize: Dimensions.smallestTextSize,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
