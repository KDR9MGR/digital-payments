import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/subscription_service.dart';
import '../utils/app_logger.dart';

/// Widget that displays real-time subscription status
/// Automatically updates when subscription status changes
class SubscriptionStatusWidget extends StatefulWidget {
  final Widget Function(bool hasSubscription) builder;
  
  const SubscriptionStatusWidget({
    super.key,
    required this.builder,
  });

  @override
  State<SubscriptionStatusWidget> createState() => _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  final SubscriptionService _subscriptionService = Get.find<SubscriptionService>();
  StreamSubscription<bool>? _subscriptionStatusSubscription;
  bool _hasSubscription = false;

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
  }

  void _listenToSubscriptionChanges() {
    _subscriptionStatusSubscription = _subscriptionService.subscriptionStatusStream.listen((hasSubscription) {
      if (mounted) {
        setState(() {
          _hasSubscription = hasSubscription;
        });
        AppLogger.log('Subscription status widget updated: hasSubscription=$hasSubscription');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_hasSubscription);
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
      builder: (hasSubscription) {
        Color statusColor;
        String statusText;
        IconData statusIcon;
        
        if (hasSubscription) {
          statusColor = Colors.green;
          statusText = 'Premium Active';
          statusIcon = Icons.verified;
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

/// Removed GracePeriodWarning widget - grace period functionality eliminated