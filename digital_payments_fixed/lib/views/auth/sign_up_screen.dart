import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:digital_payments_fixed/controller/auth_controller.dart';
import 'package:digital_payments_fixed/data/user_model.dart';
import 'package:digital_payments_fixed/utils/utils.dart';
import 'package:digital_payments_fixed/widgets/buttons/primary_button.dart';
import 'package:digital_payments_fixed/widgets/inputs/phone_number_with_contry_code_input.dart';
import 'package:digital_payments_fixed/widgets/inputs/text_field_input_widget.dart';
import 'package:digital_payments_fixed/widgets/inputs/text_label_widget.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../utils/strings.dart';
import '../../widgets/auth_nav_bar.dart';
import '../../widgets/inputs/country_picker_input_widget.dart';
import '../../widgets/inputs/pin_and_password_input_widget.dart';
import 'login_vm.dart';
import '../../services/auth_service.dart';
import '../../utils/storage_service.dart';
import '../../utils/app_logger.dart';
import '../../routes/routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final companyFormKey = GlobalKey<FormState>();

  late final LoginViewModel? _loginViewModel;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthController());
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      body: SafeArea(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: ListView(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: Dimensions.marginSize,
                right: Dimensions.marginSize,
                top: Dimensions.marginSize,
              ),
              child: Column(
                children: [
                  _naveBarWidget(context, controller),
                  _registerInfoWidget(context),
                  SizedBox(height: Dimensions.heightSize),
                ],
              ),
            ),


            _registerInputs(context, controller),

          ],
        ),
        ),
      ),
    );
  }

  // navigation  bar widget
  AuthNavBarWidget _naveBarWidget(
    BuildContext context,
    AuthController controller,
  ) {
    return AuthNavBarWidget(
      title: Strings.signIn.tr,
      onPressed: () {
        controller.navigateToLoginScreen();
      },
    );
  }

  // Register input and info
  Column _registerInputs(BuildContext context, AuthController controller) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
          decoration: BoxDecoration(
            color: CustomColor.secondaryColor,
            borderRadius: BorderRadius.circular(Dimensions.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _personalAccountInputWidget(context, controller),
              SizedBox(height: Dimensions.heightSize),
              _checkBoxWidget(context, controller),
            ],
          ),
        ),
        SizedBox(height: Dimensions.heightSize),
        _buttonWidget(context, controller, Strings.user),
        SizedBox(height: Dimensions.heightSize),
        _googleSignInButton(context),
      ],
    );
  }

  // register info
  Padding _registerInfoWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Dimensions.defaultPaddingSize * 2,
      ),
      child: Column(
        children: [
          Text(Strings.signUp.tr, style: CustomStyle.commonLargeTextTitleWhite),
          SizedBox(height: Dimensions.heightSize),
          Text(
            Strings.registerMessage.tr,
            style: TextStyle(
              color: CustomColor.primaryTextColor.withValues(alpha: 0.6),
              fontSize: Dimensions.mediumTextSize,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // register inputs
  Form _personalAccountInputWidget(
    BuildContext context,
    AuthController controller,
  ) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextLabelWidget(text: Strings.firstName.tr),
          TextFieldInputWidget(
            validator:
                RequiredValidator(errorText: 'Please enter first name').call,
            keyboardType: TextInputType.name,
            controller: controller.firstNameAuthController,
            hintText: Strings.firstNameHint.tr,
            borderColor: CustomColor.primaryColor,
            color: CustomColor.secondaryColor,
          ),
          SizedBox(height: Dimensions.heightSize),
          TextLabelWidget(text: Strings.lastName.tr),
          TextFieldInputWidget(
            validator:
                RequiredValidator(errorText: 'Please enter last name').call,
            controller: controller.lastNameAuthController,
            keyboardType: TextInputType.name,
            hintText: Strings.lastNameHint.tr,
            borderColor: CustomColor.primaryColor,
            color: CustomColor.secondaryColor,
          ),
          Column(
            children: [
              SizedBox(height: Dimensions.heightSize),
              TextLabelWidget(text: Strings.country.tr),
              ProfileCountryCodePickerWidget(
                hintText: 'Select Country',
                controller: controller.countryController,
              ),
              Divider(
                thickness: 1.5,
                color: CustomColor.primaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
          SizedBox(height: Dimensions.heightSize),
          TextLabelWidget(text: Strings.mobile.tr),
          PhoneNumberWithCountryCodeInput(
            validator:
                RequiredValidator(errorText: 'Please enter mobile number').call,
            controller: controller.phoneNumberAuthController,
          ),
          SizedBox(height: Dimensions.heightSize),
          SizedBox(height: Dimensions.heightSize),
          TextLabelWidget(text: Strings.emailAddress.tr),
          TextFieldInputWidget(
            validator:
                MultiValidator([
                  RequiredValidator(errorText: 'Please enter an email address'),
                  EmailValidator(
                    errorText: 'Please enter a valid email address',
                  ),
                ]).call,
            keyboardType: TextInputType.emailAddress,
            controller: controller.emailAuthController,
            hintText: Strings.enterEmailHint.tr,
            borderColor: CustomColor.primaryColor,
            color: CustomColor.secondaryColor,
          ),
          SizedBox(height: Dimensions.heightSize),
          TextLabelWidget(text: Strings.password.tr),
          PinAndPasswordInputWidget(
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
            hintText: Strings.password.tr,
            controller: controller.passwordController,
            borderColor: CustomColor.primaryColor,
            color: CustomColor.secondaryColor,
            keyboardType: TextInputType.visiblePassword,
          ),
          SizedBox(height: Dimensions.heightSize),
          TextLabelWidget(text: Strings.confirmPassword.tr),
          PinAndPasswordInputWidget(
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
            hintText: Strings.confirmPasswordHint.tr,
            controller: controller.confirmPasswordController,
            borderColor: CustomColor.primaryColor,
            color: CustomColor.secondaryColor,
            keyboardType: TextInputType.visiblePassword,
          ),
        ],
      ),
    );
  }

  // Sign up Button
  PrimaryButton _buttonWidget(
    BuildContext context,
    AuthController controller,
    String accountType,
  ) {
    return PrimaryButton(
      title: Strings.signUp.tr,
      onPressed: () async {
        UserModel user = UserModel(
          userId: '',
          companyName:
              controller.tabController.index == 1
                  ? controller.legalNameOfCompanyController.text.trim()
                  : '',
          representativeFirstName:
              controller.tabController.index == 1
                  ? controller.representativeFirstNameController.text.trim()
                  : '',
          representativeLastName:
              controller.tabController.index == 1
                  ? controller.representativeLastNameController.text.trim()
                  : '',
          firstName: controller.firstNameAuthController.text.trim(),
          lastName: controller.lastNameAuthController.text.trim(),
          country:
              controller.countryController.text.trim().isNotEmpty
                  ? controller.countryController.text.trim()
                  : 'United States',
          emailAddress:
              controller.tabController.index == 1
                  ? controller.companyEmailAuthController.text.trim()
                  : controller.emailAuthController.text.trim().toLowerCase(),
          mobile:
              controller.tabController.index == 1
                  ? controller.companyPhoneNumberAuthController.text.trim()
                  : controller.phoneNumberAuthController.text.trim(),
          password:
              controller.tabController.index == 1
                  ? controller.companyPasswordController.text.trim()
                  : controller.passwordController.text.trim(),
          accountType: accountType,
          walletBalances: {'USD': 0.0},
          profilePhoto: '',
          zipCode: '',
          state: '',
          city: '',
          address: '',
        );

        if (accountType == Strings.user) {
          if (formKey.currentState!.validate()) {
            await _handleSignUp(context, user, controller);
          }
        } else {
          if (companyFormKey.currentState!.validate()) {
            await _handleSignUp(context, user, controller);
          }
        }
      },
      borderColorName: CustomColor.primaryColor,
    );
  }

  Obx _checkBoxWidget(BuildContext context, AuthController controller) => Obx(
    () => Row(
      children: [
        SizedBox(
          width: 25,
          child: Checkbox(
            side: BorderSide(
              color: CustomColor.primaryColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            fillColor: WidgetStateProperty.all(CustomColor.primaryColor),
            value: controller.isChecked.value,
            shape: const RoundedRectangleBorder(),
            onChanged: (value) {
              controller.isChecked.value = !controller.isChecked.value;
            },
          ),
        ),
        SizedBox(width: Dimensions.widthSize * 0.5),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: Strings.iAgree.tr,
              style: TextStyle(
                color: CustomColor.primaryTextColor,
                fontSize: Dimensions.smallestTextSize,
                fontWeight: FontWeight.bold,
              ),
              children: <TextSpan>[
                TextSpan(
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap =
                            () async => await Utils.openUrl(
                              'https://digitalpayments.live/terms-and-conditions',
                            ),
                  text: Strings.termsOfCheckBox.tr,
                  style: TextStyle(
                    color: CustomColor.primaryColor,
                    fontSize: Dimensions.smallestTextSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    _loginViewModel = Provider.of<LoginViewModel>(context, listen: false);
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
          'Sign up with Google',
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

  Future<void> _handleSignUp(
    BuildContext context,
    UserModel user,
    AuthController controller,
  ) async {
    if (controller.isChecked.value) {
      try {
        Utils.showLoadingDialog(context);
        
        final authService = AuthService();
        final result = await authService.signUpWithEmailAndPassword(
          email: user.emailAddress,
          password: user.password,
          firstName: user.firstName,
          lastName: user.lastName,
          country: user.country,
          mobile: user.mobile,
          accountType: user.accountType,
          companyName: user.companyName,
          representativeFirstName: user.representativeFirstName,
          representativeLastName: user.representativeLastName,
        );

        if (result.isSuccess) {
          // Handle successful sign up
          if (mounted) {
            Navigator.pop(context);
            Utils.showDialogMessage(
              context,
              'Registered',
              'You are now registered successfully!',
            );
          }
          // Navigate to login screen
          controller.navigateToLoginScreen();
        } else {
          // Handle sign up failure
          if (mounted) {
            Navigator.pop(context);
            Utils.showDialogMessage(context, 'Sign Up Failed', result.errorMessage ?? 'Unknown error');
          }
        }
      } catch (ex) {
        if (mounted) {
          Navigator.pop(context);
          Utils.showDialogMessage(
            context,
            'Sign Up Failed',
            'Failed to sign up. $ex',
          );
        }
      }
    } else {
      Utils.showDialogMessage(
        context,
        'Please acknowledge',
        'Please accept the Terms & Conditions before signing up',
      );
    }
  }
}
