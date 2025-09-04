import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import '../../routes/routes.dart';

import '../../utils/error_debug_helper.dart';
import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widgets/primary_appbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    return Scaffold(
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.settings.tr,
          style: CustomStyle.commonTextTitleWhite,
        ),
        appBar: AppBar(),
        backgroundColor: CustomColor.appBarColor,
        autoLeading: false,
        elevation: 0,
        appbarColor: CustomColor.appBarColor,
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
      body: Container(
        decoration: BoxDecoration(gradient: CustomColor.primaryGradient),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: _bodyWidget(context, controller),
        ),
      ),
    );
  }

  // body widget contain all the widgets
  Container _bodyWidget(BuildContext context, SettingsController controller) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(children: [_selectOptionWidget(context, controller)]),
    );
  }

  Expanded _selectOptionWidget(
    BuildContext context,
    SettingsController controller,
  ) {
    return Expanded(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            settingsItemWidget(
              controller,
              onTap: () {
                controller.navigateToUpdateProfileScreen();
              },
              title: Strings.updateProfile.tr,
              icon: Icons.person_outline,
            ),
            SizedBox(height: Dimensions.heightSize),
            // Subscription Management Option
            settingsItemWidget(
              controller,
              onTap: () {
                Get.toNamed(Routes.subscriptionScreen);
              },
              title: 'Subscription Management',
              icon: Icons.subscriptions_outlined,
              isPremium: true,
            ),
            SizedBox(height: Dimensions.heightSize),
            settingsItemWidget(
              controller,
              onTap: () {
                controller.navigateToChangePasswordScreen();
              },
              title: Strings.changePassword.tr,
              icon: Icons.lock_outline,
            ),
            SizedBox(height: Dimensions.heightSize),
            // Delete Account Option
            settingsItemWidget(
              controller,
              onTap: () {
                controller.showDeleteAccountConfirmation();
              },
              title: 'Delete Account',
              icon: Icons.delete_forever_outlined,
              isDestructive: true,
            ),
            SizedBox(height: Dimensions.heightSize),
            // Debug Error Management (only show if there are errors)
            _debugErrorManagementWidget(),

            SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }



  Widget _debugErrorManagementWidget() {
    final Map<String, dynamic> errorStats = ErrorDebugHelper.getErrorStats();
    final int totalErrors = errorStats['totalErrors'] ?? 0;

    // Only show if there are errors to clear
    if (totalErrors == 0) {
      return SizedBox.shrink();
    }

    return settingsItemWidget(
      Get.find<SettingsController>(),
      onTap: () {
        Get.toNamed(Routes.errorDebugScreen);
      },
      title: 'Debug Error Management ($totalErrors errors)',
      icon: Icons.bug_report_outlined,
      isDestructive: true,
    );
  }

  InkWell settingsItemWidget(
    SettingsController controller, {
    required VoidCallback onTap,
    required String title,
    IconData? icon,
    bool isPremium = false,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: CustomColor.secondaryColor,
          borderRadius: BorderRadius.circular(Dimensions.radius * 2),
          border:
              isPremium
                  ? Border.all(
                    color: CustomColor.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  )
                  : isDestructive
                  ? Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  )
                  : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isPremium
                          ? CustomColor.primaryColor.withValues(alpha: 0.2)
                          : isDestructive
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color:
                      isPremium
                          ? CustomColor.primaryColor
                          : isDestructive
                          ? Colors.red
                          : Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? Colors.red : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: Dimensions.smallTextSize,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPremium) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            CustomColor.primaryColor,
                            CustomColor.primaryColor.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: CustomColor.primaryColor,
              size: Dimensions.iconSizeDefault * 1.5,
            ),
          ],
        ),
      ),
    );
  }
}
