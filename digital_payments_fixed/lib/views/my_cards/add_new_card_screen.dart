import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:digital_payments_fixed/controller/cards_controller.dart';
import 'package:digital_payments_fixed/utils/custom_color.dart';
import 'package:digital_payments_fixed/utils/custom_style.dart';
import 'package:digital_payments_fixed/utils/dimensions.dart';
import 'package:digital_payments_fixed/utils/input_formatters.dart';
import 'package:digital_payments_fixed/utils/strings.dart';
import 'package:digital_payments_fixed/widgets/buttons/primary_button.dart';
import 'package:digital_payments_fixed/widgets/inputs/text_field_input_widget.dart';
import 'package:digital_payments_fixed/widgets/primary_appbar.dart';

class AddNewCardScreen extends StatefulWidget {
  const AddNewCardScreen({super.key});

  @override
  State<AddNewCardScreen> createState() => _AddNewCardScreenState();
}

class _AddNewCardScreenState extends State<AddNewCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  
  late final CardsController _cardsController;

  @override
  void initState() {
    super.initState();
    _cardsController = Get.put(CardsController());
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.addCard,
          style: CustomStyle.commonTextTitleWhite,
        ),
        appBar: AppBar(),
        backgroundColor: CustomColor.primaryColor,
        autoLeading: false,
        elevation: 0,
        appbarColor: CustomColor.primaryColor,
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
      body: Obx(() => _bodyWidget(context)),
    );
  }

  Widget _bodyWidget(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
        children: [
          // Card Number
          _buildInputWithLabel('Card Number'),
          TextFieldInputWidget(
            controller: _cardNumberController,
            hintText: 'Enter card number (16 digits)',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter card number';
              }
              final cleanNumber = value.replaceAll(' ', '');
              if (cleanNumber.length < 13 || cleanNumber.length > 19) {
                return 'Please enter a valid card number';
              }
              if (!RegExp(r'^\d+$').hasMatch(cleanNumber)) {
                return 'Card number should contain only digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Card Holder Name
          _buildInputWithLabel('Card Holder Name'),
          TextFieldInputWidget(
            controller: _cardHolderController,
            hintText: 'Enter card holder name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter card holder name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Expiry Date and CVV
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputWithLabel('Expiry Date'),
                    TextFieldInputWidget(
                      controller: _expiryDateController,
                      hintText: 'MM/YY',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ExpiryDateInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                          return 'Use MM/YY format';
                        }
                        final parts = value.split('/');
                        final month = int.tryParse(parts[0]);
                        if (month == null || month < 1 || month > 12) {
                          return 'Invalid month';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputWithLabel('CVV'),
                    TextFieldInputWidget(
                      controller: _cvvController,
                      hintText: 'CVV',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (!RegExp(r'^\d{3,4}$').hasMatch(value)) {
                          return 'Invalid CVV';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // Add Card Button
          PrimaryButton(
            title: _cardsController.isLoading ? 'Adding...' : Strings.addCard,
            onPressed: _addCard,
          ),
        ],
      ),
    );
  }

  Widget _buildInputWithLabel(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CustomStyle.commonTextTitleWhite.copyWith(color: Colors.black87),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  void _addCard() async {
    if (_cardsController.isLoading) return;
    
    if (_formKey.currentState!.validate()) {
      final success = await _cardsController.addCard(
        cardNumber: _cardNumberController.text,
        cardHolderName: _cardHolderController.text,
        expiryDate: _expiryDateController.text,
        cvv: _cvvController.text,
      );

      if (success) {
        Get.back(); // Return to cards list
      }
    }
  }
}