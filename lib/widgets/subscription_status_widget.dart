import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/subscription_service.dart';
import '../utils/app_logger.dart';

/// Widget that displays real-time subscription status
/// Automatically updates when subscription status changes
class SubscriptionStatusWidget extends StatefulWidget {
  final Widget Function(bool hasSubscription, bool isInGracePeriod) builder;
  final bool showGracePeriodInfo;
  
  const SubscriptionStatusWidget({
    super.key,
    required this.builder,
    this.showGracePeriodInfo = false,
  });

  @override
  State<SubscriptionStatusWidget> createState() => _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  final SubscriptionService _subscriptionService = Get.find<SubscriptionService>();
  StreamSubscription<bool>? _subscriptionStatusSubscription;
  bool _hasSubscription = false;
  bool _isInGracePeriod = false;

  @override
  void initState() {
    super.initState();
    _initializeStatus();
    _listenToSubscriptionChanges();
  }

  @override
  void dispose() {
    _subscriptionStatusSubscription?.cancel();
    super.dispose();
  }

  void _initializeStatus() {
    _hasSubscription = _subscriptionService.hasActiveSubscription;
    _isInGracePeriod = _subscriptionService.isInGracePeriod;
  }

  void _listenToSubscriptionChanges() {
    _subscriptionStatusSubscription = _subscriptionService.subscriptionStatusStream.listen((hasSubscription) {
      if (mounted) {
        setState(() {
          _hasSubscription = hasSubscription;
          _isInGracePeriod = _subscriptionService.isInGracePeriod;
        });
        AppLogger.log('Subscription status widget updated: hasSubscription=$hasSubscription, isInGracePeriod=$_isInGracePeriod');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_hasSubscription, _isInGracePeriod);
  }
}

/// Simple subscription status indicator
class SubscriptionStatusIndicator extends StatelessWidget {
  final bool showText;
  final EdgeInsets? padding;
  
  const SubscriptionStatusIndicator({
    super.key,
    this.showText = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SubscriptionStatusWidget(
      builder: (hasSubscription, isInGracePeriod) {
        Color statusColor;
        String statusText;
        IconData statusIcon;
        
        if (hasSubscription && !isInGracePeriod) {
          statusColor = Colors.green;
          statusText = 'Premium Active';
          statusIcon = Icons.verified;
        } else if (isInGracePeriod) {
          statusColor = Colors.orange;
          statusText = 'Grace Period';
          statusIcon = Icons.warning;
        } else {
          statusColor = Colors.grey;
          statusText = 'Free Plan';
          statusIcon = Icons.person;
        }
        
        return Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                statusIcon,
                size: 16,
                color: statusColor,
              ),
              if (showText) ...[
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}

/// Grace period warning widget
class GracePeriodWarning extends StatelessWidget {
  const GracePeriodWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return SubscriptionStatusWidget(
      showGracePeriodInfo: true,
      builder: (hasSubscription, isInGracePeriod) {
        if (!isInGracePeriod) {
          return const SizedBox.shrink();
        }
        
        final subscriptionService = Get.find<SubscriptionService>();
        final gracePeriodEnd = subscriptionService.gracePeriodEnd;
        final daysLeft = gracePeriodEnd?.difference(DateTime.now()).inDays ?? 0;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grace Period Active',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$daysLeft days remaining. Renew to continue premium features.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Get.toNamed('/subscription'),
                child: Text(
                  'Renew',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}