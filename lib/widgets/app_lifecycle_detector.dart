import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/subscription_controller.dart';
import '../utils/app_logger.dart';

class AppLifecycleDetector extends StatefulWidget {
  final Widget child;
  
  const AppLifecycleDetector({super.key, required this.child});
  
  @override
  State<AppLifecycleDetector> createState() => _AppLifecycleDetectorState();
}

class _AppLifecycleDetectorState extends State<AppLifecycleDetector> with WidgetsBindingObserver {
  late SubscriptionController _subscriptionController;
  DateTime? _backgroundTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptionController = Get.find<SubscriptionController>();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    AppLogger.log('App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundTime = DateTime.now();
        AppLogger.log('App went to background at: $_backgroundTime');
        break;
        
      case AppLifecycleState.resumed:
        _handleAppResume();
        break;
        
      case AppLifecycleState.inactive:
        // App is transitioning between foreground and background
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        break;
    }
  }
  
  void _handleAppResume() {
    AppLogger.log('App resumed from background');
    
    if (_backgroundTime != null) {
      final backgroundDuration = DateTime.now().difference(_backgroundTime!);
      AppLogger.log('App was in background for: ${backgroundDuration.inSeconds} seconds');
      
      // If app was in background for more than 5 seconds and there's a pending session,
      // it's likely the user returned from Play Store
      if (backgroundDuration.inSeconds > 5 && _subscriptionController.hasActivePendingSession) {
        AppLogger.log('Detected potential return from Play Store');
        _subscriptionController.handlePlayStoreReturn();
      }
      
      _backgroundTime = null;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}