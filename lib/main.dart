import 'dart:async';
import '/utils/app_logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xpay/firebase_options.dart';
import 'package:xpay/routes/routes.dart';
import 'package:xpay/utils/language/local_strings.dart';
import 'package:xpay/utils/threading_utils.dart';
import 'package:xpay/views/auth/login_vm.dart';
import 'package:xpay/views/auth/wallet_view_model.dart';
import 'controller/auth_controller.dart';
import 'controller/subscription_controller.dart';
import 'services/platform_payment_service.dart';
import 'services/subscription_service.dart';

import 'widgets/app_lifecycle_detector.dart';

import 'utils/custom_color.dart';
import 'utils/strings.dart';
import 'views/auth/user_provider.dart';

void main() async {
  // Add crash prevention wrapper
  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        // Initialize Firebase with timeout
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 10));
          AppLogger.log('Firebase initialized successfully');
        } catch (e) {
          AppLogger.log('Firebase initialization error: $e');
          // Continue without Firebase if it fails
        }

        // Lock Device Orientation with timeout
        try {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]).timeout(const Duration(seconds: 5));
        } catch (e) {
          AppLogger.log('Device orientation error: $e');
          // Continue without orientation lock if it fails
        }

        // Initialize storage with timeout
        bool storageInitialized = false;
        try {
          await GetStorage.init().timeout(const Duration(seconds: 5));
          storageInitialized = true;
          AppLogger.log('Storage initialized successfully');
        } catch (e) {
          AppLogger.log('Storage initialization error: $e');
          AppLogger.log('Warning: Firebase cache services may not work properly without storage');
          // Continue without storage if it fails
        }
        
        // Store storage status for Firebase services
        if (storageInitialized) {
          AppLogger.log('Storage available for Firebase cache services');
        } else {
          AppLogger.log('Storage unavailable - Firebase services will use fallback mode');
        }

        // Initialize services in background (non-blocking)
        _initializeServicesInBackground();

        // Initialize services first
        Get.put(SubscriptionService());
        
        // Initialize controllers
        Get.put(AuthController());
        Get.put(SubscriptionController());
        
        
        // Run the app immediately
        runApp(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LoginViewModel>(
                create: (context) {
                  try {
                    return LoginViewModel();
                  } catch (e) {
                    AppLogger.log('LoginViewModel creation error: $e');
                    return LoginViewModel();
                  }
                },
              ),
              ChangeNotifierProvider(create: (_) => UserProvider()),
              ChangeNotifierProvider(create: (_) => WalletViewModel()),
            ],
            child: const AppLifecycleDetector(
              child: MyApp(),
            ),
          ),
        );
      } catch (e) {
        AppLogger.log('Critical error during app initialization: $e');
        // Run minimal error app
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'App Initialization Error',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('$e', textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    },
    (error, stack) {
      AppLogger.log('Uncaught error: $error');
    },
  );
}

// Initialize services in background without blocking app startup
void _initializeServicesInBackground() {
  Future.delayed(Duration.zero, () async {
    try {
      await PlatformPaymentService.init().timeout(const Duration(seconds: 10));
      AppLogger.log('Platform Payment Service initialized successfully');
    } catch (e) {
      AppLogger.log('Platform Payment Service initialization error: $e');
    }
    
    
    
    try {
      await Get.find<SubscriptionService>().initialize().timeout(const Duration(seconds: 10));
      AppLogger.log('Subscription Service initialized successfully');
    } catch (e) {
      AppLogger.log('Subscription Service initialization error: $e');
    }

    // SubscriptionController is already initialized in main initialization
    AppLogger.log('Background services initialization completed');
  });
}

// This widget is the root of your application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(414, 896),
      minTextAdapt: true,
      splitScreenMode: true,
      builder:
          (context, child) => GetMaterialApp(
            title: Strings.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.dark(
                primary: CustomColor.primaryColor,
                secondary: CustomColor.secondaryColor,
                surface: CustomColor.surfaceColor,
                onPrimary: CustomColor.onPrimaryTextColor,
                onSecondary: CustomColor.onPrimaryTextColor,
                onSurface: CustomColor.primaryTextColor,
                error: CustomColor.errorColor,
                outline: CustomColor.outlineColor,
              ),
              scaffoldBackgroundColor: CustomColor.screenBGColor,
              appBarTheme: AppBarTheme(
                backgroundColor: CustomColor.appBarColor,
                foregroundColor: CustomColor.primaryTextColor,
                elevation: 0,
                centerTitle: true,
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColor.primaryColor,
                  foregroundColor: CustomColor.onPrimaryTextColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                color: CustomColor.surfaceColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: CustomColor.outlineColor, width: 1),
                ),
              ),
              textTheme: GoogleFonts.josefinSansTextTheme(
                Theme.of(context).textTheme.apply(
                  bodyColor: CustomColor.primaryTextColor,
                  displayColor: CustomColor.primaryTextColor,
                ),
              ),
            ),
            navigatorKey: Get.key,
            initialRoute: Routes.splashScreen,
            getPages: Routes.list,
            builder: (context, widget) {
              ScreenUtil.init(context);
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.0)),
                child: widget!,
              );
            },
            translations: LocalString(),
            locale: const Locale('en', 'US'),
            fallbackLocale: const Locale('en', 'US'),
            onInit: () {
              // Initialize any app-wide threading resources
            },
            onDispose: () {
              // Clean up threading resources when app is disposed
              ThreadingUtils.dispose();
            },
          ),
    );
  }
}
