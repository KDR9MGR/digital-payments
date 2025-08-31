import 'package:flutter/material.dart';
import '/utils/app_logger.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_guard_service.dart';
import 'package:digital_payments_fixed/controller/auth_controller.dart';
import 'package:digital_payments_fixed/data/user_model.dart';
import 'package:digital_payments_fixed/routes/routes.dart';
import 'package:digital_payments_fixed/utils/storage_service.dart';
import 'package:digital_payments_fixed/views/auth/login_vm.dart';
import 'package:digital_payments_fixed/views/auth/user_provider.dart';
import 'package:digital_payments_fixed/widgets/buttons/primary_button.dart';
import 'package:digital_payments_fixed/widgets/inputs/text_field_input_widget.dart';
import 'package:digital_payments_fixed/widgets/inputs/text_label_widget.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../utils/utils.dart';
import '../../widgets/auth_nav_bar.dart';
import '../../widgets/inputs/pin_and_password_input_widget.dart';

// Static authentication function that can be safely used in isolates
class IsolateAuthHelper {
  static Future<String> performSignIn(String email, String password) async {
    try {
      final auth = FirebaseAuth.instance;
      final result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        return '';
      } else {
        return 'User is null';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'The email address is already in use.';
      } else if (e.code == 'user-disabled') {
        return 'The user account has been disabled.';
      } else if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is not formatted correctly.';
      } else if (e.code == 'invalid-credential') {
        return 'The supplied auth credential is malformed or has expired. Please check your email and password.';
      } else if (e.code == 'weak-password') {
        return 'The password provided is not strong enough.';
      } else if (e.code == 'operation-not-allowed') {
        return 'This sign-in method is not enabled.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many requests. Please try again later.';
      } else {
        return 'Error signing in: ${e.message}';
      }
    } catch (e) {
      return 'Error signing in: $e';
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  late final LoginViewModel? _loginViewModel;
  late final UserProvider _userProvider;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthController());
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: CustomColor.primaryGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: _bodyWidget(context, controller),
            ),
          ),
        ),
      ),
    );
  }

  // body widget containing all widget elements
  Padding _bodyWidget(BuildContext context, AuthController controller) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimensions.marginSize,
        right: Dimensions.marginSize,
        top: Dimensions.marginSize,
      ),
      child: ListView(
        children: [
          _naveBarWidget(context, controller),
          _loginInfoWidget(context),
          SizedBox(height: Dimensions.heightSize * 2),
          _loginInputs(context, controller),
          SizedBox(height: Dimensions.heightSize * 2),
          _buttonWidget(context, controller),
          SizedBox(height: Dimensions.heightSize),
          _googleSignInButton(context),
        ],
      ),
    );
  }

  // navigation  bar widget
  AuthNavBarWidget _naveBarWidget(
    BuildContext context,
    AuthController controller,
  ) {
    return AuthNavBarWidget(
      title: Strings.signUp.tr,
      onPressed: () {
        controller.navigateToRegisterScreen();
      },
    );
  }

  // Login input and info
  Container _loginInputs(BuildContext context, AuthController controller) {
    return Container(
      padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
      decoration: BoxDecoration(
        color: CustomColor.secondaryColor,
        borderRadius: BorderRadius.circular(Dimensions.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _loginInputWidget(context, controller),
          SizedBox(height: Dimensions.heightSize),
          GestureDetector(
            onTap: () {
              controller.navigateToForgetPinScreen();
              // _incorrectPassword(context, controller);
            },
            child: Text(
              Strings.forgetPassword.tr,
              style: TextStyle(
                color: CustomColor.primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: Dimensions.smallTextSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // login info
  Container _loginInfoWidget(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Dimensions.heightSize * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.signIn.tr,
            style: CustomStyle.commonLargeTextTitleWhite.copyWith(
              fontSize: Dimensions.extraLargeTextSize * 1.3,
            ),
          ),
          SizedBox(height: Dimensions.heightSize * 0.5),
          Text(
            Strings.loginMessage.tr,
            style: CustomStyle.commonTextSubTitleWhite.copyWith(
              fontSize: Dimensions.mediumTextSize,
            ),
          ),
        ],
      ),
    );
  }

  // input widget containing all input field
  Form _loginInputWidget(BuildContext context, AuthController controller) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextLabelWidget(text: Strings.emailAddress.tr),
          TextFieldInputWidget(
            hintText: Strings.enterEmailHint.tr,
            keyboardType: TextInputType.emailAddress,
            controller: controller.emailAuthController,
            validator:
                MultiValidator([
                  RequiredValidator(errorText: 'Please enter an email address'),
                  EmailValidator(
                    errorText: 'Please enter a valid email address',
                  ),
                ]).call,
            color: CustomColor.secondaryColor,
          ),
          SizedBox(height: Dimensions.heightSize),
          TextLabelWidget(text: Strings.password.tr),
          PinAndPasswordInputWidget(
            hintText: Strings.enterPasswordHint.tr,
            keyboardType: TextInputType.visiblePassword,
            controller: controller.pinLoginController,
            validator:
                MultiValidator([
                  RequiredValidator(errorText: 'Please enter a password'),
                  LengthRangeValidator(
                    min: 6,
                    max: 16,
                    errorText:
                        'Password should be minimum 6 and max 16 characters',
                  ),
                ]).call,
            borderColor: CustomColor.primaryColor,
            color: CustomColor.secondaryColor,
          ),
        ],
      ),
    );
  }

  // Login Button
  PrimaryButton _buttonWidget(BuildContext context, AuthController controller) {
    return PrimaryButton(
      title: Strings.signIn.tr,
      onPressed: () async {
        if (formKey.currentState!.validate()) {
          try {
            Utils.showLoadingDialog(context);

            final email = controller.emailAuthController.text.trim().toLowerCase();
            final password = controller.pinLoginController.text.trim();

            AppLogger.log('Attempting sign in with: $email');

            final authService = AuthService();
            final result = await authService.signInWithEmailAndPassword(email, password);

            if (result.isSuccess) {
              // Handle successful sign in
              AppLogger.log('Sign in successful, saving login state...');

              // Storage operations
              final storageService = StorageService();
              await storageService.saveValue(Strings.isLoggedIn, true);

              // Fetch and store user data
              final userData = await authService.getCurrentUserData();
              if (userData != null) {
                _userProvider.updateUserDirectly(userData);
              }

              if (mounted) {
                Navigator.pop(context);
                Get.offAllNamed(Routes.dashboardScreen);
              }
            } else {
              // Handle sign in failure
              if (mounted) {
                Navigator.pop(context);
                Utils.showDialogMessage(context, 'Sign In Failed', result.errorMessage ?? 'Unknown error');
              }
            }
          } catch (ex) {
            AppLogger.log('Login error: $ex');
            if (mounted) {
              Navigator.pop(context);
              Utils.showDialogMessage(
                context,
                'Sign In Failed',
                'Failed to sign in. $ex',
              );
            }
          }
        }
      },
      borderColorName: CustomColor.primaryColor,
      borderWidth: 0,
    );
  }

  // Google Sign-In Button
  Widget _googleSignInButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          try {
            Utils.showLoadingDialog(context);
            
            final authService = AuthService();
            final result = await authService.signInWithGoogle();
            
            if (result.isSuccess) {
              // Handle successful Google sign in
              AppLogger.log('Google sign in successful, saving login state...');
              
              // Storage operations
              final storageService = StorageService();
              await storageService.saveValue(Strings.isLoggedIn, true);
              
              // Fetch and store user data
              final userData = await authService.getCurrentUserData();
              if (userData != null) {
                _userProvider.updateUserDirectly(userData);
              }
              
              if (mounted) {
                Navigator.pop(context);
                Get.offAllNamed(Routes.dashboardScreen);
              }
            } else {
              // Handle Google sign in failure
              if (mounted) {
                Navigator.pop(context);
                Utils.showDialogMessage(context, 'Google Sign In Failed', result.errorMessage ?? 'Unknown error');
              }
            }
          } catch (ex) {
            AppLogger.log('Google sign in error: $ex');
            if (mounted) {
              Navigator.pop(context);
              Utils.showDialogMessage(
                context,
                'Google Sign In Failed',
                'Failed to sign in with Google. $ex',
              );
            }
          }
        },
        icon: Icon(
          Icons.login,
          color: CustomColor.primaryColor,
        ),
        label: Text(
          'Sign in with Google',
          style: TextStyle(
            color: CustomColor.primaryColor,
            fontSize: Dimensions.mediumTextSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: CustomColor.primaryColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.radius),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loginViewModel = Provider.of<LoginViewModel>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
  }
}
