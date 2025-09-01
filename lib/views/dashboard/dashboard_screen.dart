import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:xpay/views/auth/user_provider.dart';
import 'package:xpay/widgets/video_player_widget.dart';

import '../../routes/routes.dart';

import '../../controller/dashboard_controller.dart';
import '../../controller/subscription_controller.dart';
import '../../services/subscription_service.dart';
import '../../screens/paywall_screen.dart';
import '../../utils/app_logger.dart';
import '../../utils/custom_color.dart';

import '../../widgets/navigation_drawer_widget.dart';
import '../../widgets/slider_widget.dart';
import '../../widgets/subscription_status_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final List<SliderWidget> sliderList = [
    const SliderWidget(),
    const SliderWidget(),
    const SliderWidget(),
    const SliderWidget(),
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  // Removed automatic subscription verification - features will check individually

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _modernAppBarWidget(context, controller),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 24),
                      _subscriptionStatusBanner(context),
                      SizedBox(height: 24),
                      _quickActionsWidget(context, controller),
                      SizedBox(height: 32),
                      // _featuredServicesWidget(context, controller), // Removed non-working services
                      _videoShowcaseWidget(
                        context,
                        controller,
                      ), // Added video showcase
                      SizedBox(height: 32),
                      _additionalFeaturesWidget(context, controller),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      endDrawer: const NavigationDrawerWidget(),
    );
  }

  // Modern app bar with glassmorphism effect
  Widget _modernAppBarWidget(
    BuildContext context,
    DashboardController controller,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColor.appBarColor,
            CustomColor.appBarColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: CustomColor.appBarColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Consumer<UserProvider>(
        builder: (
          BuildContext context,
          UserProvider userProvider,
          Widget? child,
        ) {
          return Row(
            children: [
              // Enhanced Profile section
              Expanded(
                child: InkWell(
                  onTap: () => Get.toNamed('/updateProfileScreen'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.2),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child:
                                  (userProvider
                                              .user
                                              ?.profilePhoto
                                              ?.isNotEmpty ==
                                          true)
                                      ? CircleAvatar(
                                        radius: 30,
                                        backgroundImage: NetworkImage(
                                          userProvider.user?.profilePhoto ?? '',
                                        ),
                                      )
                                      : CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.1),
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: CustomColor.successColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 4),
                              GetBuilder<SubscriptionController>(
                                init: SubscriptionController(),
                                builder: (subscriptionController) {
                                  return Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userProvider.user?.firstName ??
                                              'User',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      if (subscriptionController
                                          .hasActiveSubscription) ...[
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.amber.withValues(
                                                  alpha: 0.9,
                                                ),
                                                Colors.orange.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withValues(
                                                  alpha: 0.3,
                                                ),
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
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'PREMIUM',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Enhanced Menu button
              Builder(
                builder:
                    (context) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                        icon: Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Enhanced quick actions with modern design
  Widget _quickActionsWidget(
    BuildContext context,
    DashboardController controller,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: CustomColor.appBarColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Essential Services',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          // First row - Send Money and QR Scanning
          Row(
            children: [
              Expanded(
                child: _modernActionCard(
                  context,
                  icon: Icons.send_rounded,
                  title: 'Send Money',
                  subtitle: 'Transfer funds',
                  color: CustomColor.successColor,
                  onTap: () => controller.navigateToMoneyOutScreen(),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _modernActionCard(
                  context,
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'QR Pay',
                  subtitle: 'Scan & send',
                  color: CustomColor.appBarColor,
                  onTap: () => Get.toNamed('/scanQeCodeScreen'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Second row - Save Cards and Save Bank Info
          Row(
            children: [
              Expanded(
                child: _modernActionCard(
                  context,
                  icon: Icons.credit_card_rounded,
                  title: 'Save Cards',
                  subtitle: 'Manage cards',
                  color: CustomColor.warningColor,
                  onTap: () {
                    final subscriptionController =
                        Get.find<SubscriptionController>();
                    if (subscriptionController.hasActiveSubscription) {
                      Get.toNamed(Routes.myCardsScreen);
                    } else {
                      Get.to(
                        () => const PaywallScreen(),
                        fullscreenDialog: true,
                        transition: Transition.cupertino,
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _modernActionCard(
                  context,
                  icon: Icons.account_balance_rounded,
                  title: 'Bank Info',
                  subtitle: 'Save bank details',
                  color: Colors.purple,
                  onTap: () {
                    final subscriptionController =
                        Get.find<SubscriptionController>();
                    if (subscriptionController.hasActiveSubscription) {
                      Get.toNamed(Routes.bankInfoScreen);
                    } else {
                      Get.to(
                        () => const PaywallScreen(),
                        fullscreenDialog: true,
                        transition: Transition.cupertino,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern action card with enhanced design
  Widget _modernActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColor.surfaceColor.withValues(alpha: 0.8),
            CustomColor.surfaceColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced more services section
  Widget _additionalFeaturesWidget(
    BuildContext context,
    DashboardController controller,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: CustomColor.appBarColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'More Services',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CustomColor.surfaceColor.withValues(alpha: 0.8),
                  CustomColor.surfaceColor.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _modernServiceListTile(
                  icon: Icons.history_rounded,
                  title: 'Transactions',
                  subtitle: 'View history',
                  onTap: () => controller.navigateToTransactionHistoryScreen(),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                _modernServiceListTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Support',
                  subtitle: 'Get help',
                  onTap: () => controller.navigateToSupportScreen(),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                _modernServiceListTile(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'Manage account',
                  onTap: () => controller.navigateToSettingScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern service list tile
  Widget _modernServiceListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CustomColor.appBarColor.withValues(alpha: 0.3),
                      CustomColor.appBarColor.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: CustomColor.appBarColor, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Video showcase widget to replace removed features
  Widget _videoShowcaseWidget(
    BuildContext context,
    DashboardController controller,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: CustomColor.appBarColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Digital Payment in Action',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Responsive video container
          LayoutBuilder(
            builder: (context, constraints) {
              double videoHeight =
                  constraints.maxWidth * 0.6; // 16:10 aspect ratio
              videoHeight = videoHeight.clamp(200.0, 300.0); // Min 200, Max 300

              return Container(
                width: double.infinity,
                height: videoHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: YouTubeVideoWidget(
                  height: videoHeight,
                  borderRadius: BorderRadius.circular(22),
                ),
              );
            },
          ),
          SizedBox(height: 24), // Increased spacing
          // Enhanced description container
          Container(
            padding: EdgeInsets.all(24), // Increased padding
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CustomColor.surfaceColor.withValues(alpha: 0.9),
                  CustomColor.surfaceColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            CustomColor.appBarColor,
                            CustomColor.appBarColor.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: CustomColor.appBarColor.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.people_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure Digital Payments',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Experience secure, fast, and reliable digital payments you can trust',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Secure', 'Payments'),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    _buildStatItem('24/7', 'Support'),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    _buildStatItem('99.9%', 'Uptime'),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for stats items
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: CustomColor.appBarColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Subscription status banner
  Widget _subscriptionStatusBanner(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: SubscriptionStatusWidget(
        builder: (hasSubscription) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    hasSubscription
                        ? [
                          CustomColor.successColor.withValues(alpha: 0.8),
                          CustomColor.successColor.withValues(alpha: 0.6),
                        ]
                        : [
                          CustomColor.primaryColor.withValues(alpha: 0.8),
                          CustomColor.primaryColor.withValues(alpha: 0.6),
                        ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Get.toNamed(Routes.subscriptionScreen),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          hasSubscription
                              ? Icons.star_rounded
                              : Icons.diamond_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  hasSubscription
                                      ? 'Premium Active'
                                      : 'Go Premium',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (hasSubscription) ...[
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'ACTIVE',
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
                            SizedBox(height: 4),
                            Text(
                              hasSubscription
                                  ? 'Enjoying all premium features • \$1.99/month'
                                  : 'Unlock premium features for just \$1.99/month',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
