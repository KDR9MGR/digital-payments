import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:xpay/controller/cards_controller.dart';
import 'package:xpay/utils/custom_color.dart';
import 'package:xpay/utils/custom_style.dart';
import 'package:xpay/utils/dimensions.dart';
import 'package:xpay/utils/input_formatters.dart';
import 'package:xpay/utils/strings.dart';
import 'package:xpay/widgets/buttons/primary_button.dart';
import 'package:xpay/widgets/inputs/text_field_input_widget.dart';
import 'package:xpay/widgets/primary_appbar.dart';
import '../../services/card_tokenization_service.dart';
import '../../data/card_model.dart';

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
  String _detectedCardType = 'Unknown';
  bool _isSecurityInfoVisible = false;

  @override
  void initState() {
    super.initState();
    _cardsController = Get.put(CardsController());
    
    // Listen for card number changes to detect card type
    _cardNumberController.addListener(() {
      final cleanNumber = _cardNumberController.text.replaceAll(' ', '');
      if (cleanNumber.length >= 4) {
        setState(() {
          _detectedCardType = CardModel.getCardType(cleanNumber);
        });
      }
    });
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
          // Security Information Banner
          _buildSecurityBanner(),
          const SizedBox(height: 20),
          
          // Card Number with Type Detection
          _buildInputWithLabel('Card Number'),
          TextFieldInputWidget(
            controller: _cardNumberController,
            hintText: 'Enter card number (13-19 digits)',
            keyboardType: TextInputType.number,
            suffixIcon: _detectedCardType != 'Unknown' 
                 ? Icons.credit_card
                 : null,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter card number';
              }
              final cleanNumber = value.replaceAll(' ', '');
              if (!CardTokenizationService.validateCardNumber(cleanNumber)) {
                return 'Please enter a valid card number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Card Holder Name
          _buildInputWithLabel('Card Holder Name'),
          TextFieldInputWidget(
            controller: _cardHolderController,
            hintText: 'Enter card holder name as shown on card',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter card holder name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                return 'Name should contain only letters and spaces';
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
                        if (!CardTokenizationService.validateExpiryDate(value)) {
                          return 'Invalid or expired date';
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
                      hintText: _detectedCardType == 'American Express' ? 'XXXX' : 'XXX',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (!CardTokenizationService.validateCvv(value, _detectedCardType)) {
                          final expectedLength = _detectedCardType == 'American Express' ? 4 : 3;
                          return '$expectedLength digits required';
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
          
          // Security Features Info
          _buildSecurityFeatures(),
          const SizedBox(height: 30),
          
          // Add Card Button
          PrimaryButton(
            title: _cardsController.isLoading ? 'Securing Card...' : 'Add Card Securely',
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

  Widget _buildSecurityBanner() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.green, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Card Storage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  'Your card data is encrypted and tokenized for maximum security',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSecurityFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isSecurityInfoVisible = !_isSecurityInfoVisible;
            });
          },
          child: Row(
            children: [
              Icon(
                _isSecurityInfoVisible ? Icons.expand_less : Icons.expand_more,
                color: CustomColor.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'Security Features',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: CustomColor.primaryColor,
                ),
              ),
            ],
          ),
        ),
        if (_isSecurityInfoVisible) ...[
          SizedBox(height: 12),
          _buildSecurityFeatureItem(
            Icons.lock,
            'End-to-End Encryption',
            'Card data is encrypted before storage',
          ),
          _buildSecurityFeatureItem(
            Icons.token,
            'Tokenization',
            'Real card numbers are replaced with secure tokens',
          ),
          _buildSecurityFeatureItem(
            Icons.fingerprint,
            'Duplicate Detection',
            'Prevents saving the same card multiple times',
          ),
          _buildSecurityFeatureItem(
            Icons.verified,
            'Luhn Validation',
            'Advanced card number validation algorithm',
          ),
        ],
      ],
    );
  }
  
  Widget _buildSecurityFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        // Small delay to ensure any loading dialogs are dismissed
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Navigate back to home screen
        Get.offAllNamed('/navigationScreen');
      }
    }
  }
}