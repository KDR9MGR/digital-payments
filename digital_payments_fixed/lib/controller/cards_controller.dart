import '../data/card_model.dart';
import '/utils/app_logger.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardsController extends GetxController {
  static const String _cardsKey = 'saved_cards';
  
  final RxList<CardModel> _cards = <CardModel>[].obs;
  final RxBool _isLoading = false.obs;

  List<CardModel> get cards => _cards;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    loadCards();
  }

  // Load cards from local storage
  Future<void> loadCards() async {
    try {
      _isLoading.value = true;
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = prefs.getString(_cardsKey);
      
      if (cardsJson != null) {
        final List<dynamic> cardsList = json.decode(cardsJson);
        _cards.value = cardsList.map((cardJson) => CardModel.fromJson(cardJson)).toList();
      }
    } catch (e) {
      AppLogger.log('Error loading cards: $e');
      Get.snackbar('Error', 'Failed to load saved cards');
    } finally {
      _isLoading.value = false;
    }
  }

  // Save cards to local storage
  Future<void> _saveCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = json.encode(_cards.map((card) => card.toJson()).toList());
      await prefs.setString(_cardsKey, cardsJson);
    } catch (e) {
      AppLogger.log('Error saving cards: $e');
      throw Exception('Failed to save cards');
    }
  }

  // Add a new card
  Future<bool> addCard({
    required String cardNumber,
    required String cardHolderName,
    required String expiryDate,
    required String cvv,
  }) async {
    try {
      _isLoading.value = true;

      // Validate card data
      if (!_validateCardData(cardNumber, cardHolderName, expiryDate, cvv)) {
        return false;
      }

      // Check if card already exists
      final cleanCardNumber = cardNumber.replaceAll(' ', '');
      if (_cards.any((card) => card.cardNumber.replaceAll(' ', '') == cleanCardNumber)) {
        Get.snackbar('Error', 'This card is already saved');
        return false;
      }

      // Create new card
      final newCard = CardModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cardNumber: cleanCardNumber,
        cardHolderName: cardHolderName.trim(),
        expiryDate: expiryDate.trim(),
        cvv: cvv.trim(),
        cardType: CardModel.getCardType(cleanCardNumber),
        isDefault: _cards.isEmpty, // First card becomes default
        createdAt: DateTime.now(),
      );

      _cards.add(newCard);
      await _saveCards();
      
      Get.snackbar('Success', 'Card added successfully');
      return true;
    } catch (e) {
      AppLogger.log('Error adding card: $e');
      Get.snackbar('Error', 'Failed to add card');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Remove a card
  Future<bool> removeCard(String cardId) async {
    try {
      _isLoading.value = true;
      
      final cardIndex = _cards.indexWhere((card) => card.id == cardId);
      if (cardIndex == -1) {
        Get.snackbar('Error', 'Card not found');
        return false;
      }

      final removedCard = _cards[cardIndex];
      _cards.removeAt(cardIndex);

      // If removed card was default, make first remaining card default
      if (removedCard.isDefault && _cards.isNotEmpty) {
        _cards[0] = _cards[0].copyWith(isDefault: true);
      }

      await _saveCards();
      Get.snackbar('Success', 'Card removed successfully');
      return true;
    } catch (e) {
      AppLogger.log('Error removing card: $e');
      Get.snackbar('Error', 'Failed to remove card');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Set default card
  Future<bool> setDefaultCard(String cardId) async {
    try {
      _isLoading.value = true;
      
      // Remove default from all cards
      for (int i = 0; i < _cards.length; i++) {
        _cards[i] = _cards[i].copyWith(isDefault: false);
      }

      // Set new default
      final cardIndex = _cards.indexWhere((card) => card.id == cardId);
      if (cardIndex == -1) {
        Get.snackbar('Error', 'Card not found');
        return false;
      }

      _cards[cardIndex] = _cards[cardIndex].copyWith(isDefault: true);
      await _saveCards();
      
      Get.snackbar('Success', 'Default card updated');
      return true;
    } catch (e) {
      AppLogger.log('Error setting default card: $e');
      Get.snackbar('Error', 'Failed to update default card');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  // Get default card
  CardModel? get defaultCard {
    try {
      return _cards.firstWhere((card) => card.isDefault);
    } catch (e) {
      return _cards.isNotEmpty ? _cards.first : null;
    }
  }

  // Validate card data with comprehensive checks
  bool _validateCardData(String cardNumber, String cardHolderName, String expiryDate, String cvv) {
    // Clean card number
    final cleanCardNumber = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Validate card number length and format
    if (cleanCardNumber.isEmpty) {
      Get.snackbar('Error', 'Please enter a card number');
      return false;
    }

    if (cleanCardNumber.length < 13 || cleanCardNumber.length > 19) {
      Get.snackbar('Error', 'Card number must be between 13-19 digits');
      return false;
    }

    // Validate card number using Luhn algorithm
    if (!_isValidCardNumberLuhn(cleanCardNumber)) {
      Get.snackbar('Error', 'Please enter a valid card number');
      return false;
    }

    // Validate card holder name
    if (cardHolderName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter card holder name');
      return false;
    }

    if (cardHolderName.trim().length < 2) {
      Get.snackbar('Error', 'Card holder name must be at least 2 characters');
      return false;
    }

    if (cardHolderName.trim().length > 50) {
      Get.snackbar('Error', 'Card holder name must be less than 50 characters');
      return false;
    }

    // Validate card holder name contains only letters and spaces
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(cardHolderName.trim())) {
      Get.snackbar('Error', 'Card holder name should contain only letters and spaces');
      return false;
    }

    // Validate expiry date format (MM/YY)
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(expiryDate.trim())) {
      Get.snackbar('Error', 'Please enter expiry date in MM/YY format (e.g., 12/25)');
      return false;
    }

    final parts = expiryDate.trim().split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    
    if (month == null || year == null || month < 1 || month > 12) {
      Get.snackbar('Error', 'Please enter a valid expiry date');
      return false;
    }

    // Check if card is expired (more precise validation)
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    final expiryYear = 2000 + year;
    final cardExpiryDate = DateTime(expiryYear, month + 1, 0); // Last day of expiry month
    
    if (cardExpiryDate.isBefore(DateTime.now())) {
      Get.snackbar('Error', 'Card has expired');
      return false;
    }

    // Check if expiry date is too far in future (more than 10 years)
    final maxExpiryDate = DateTime.now().add(Duration(days: 365 * 10));
    if (cardExpiryDate.isAfter(maxExpiryDate)) {
      Get.snackbar('Error', 'Invalid expiry date - too far in the future');
      return false;
    }

    // Validate CVV based on card type
    final cardType = CardModel.getCardType(cleanCardNumber);
    final expectedCvvLength = (cardType == 'American Express') ? 4 : 3;
    
    if (cvv.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter CVV');
      return false;
    }

    if (!RegExp(r'^\d+$').hasMatch(cvv.trim())) {
      Get.snackbar('Error', 'CVV should contain only digits');
      return false;
    }

    if (cvv.trim().length != expectedCvvLength) {
      Get.snackbar('Error', 'CVV should be $expectedCvvLength digits for $cardType');
      return false;
    }

    return true;
  }

  // Luhn algorithm for card number validation
  bool _isValidCardNumberLuhn(String cardNumber) {
    if (cardNumber.isEmpty) return false;
    
    int sum = 0;
    bool alternate = false;
    
    // Process digits from right to left
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.tryParse(cardNumber[i]) ?? 0;
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return (sum % 10) == 0;
  }

  // Additional validation for card security
  bool _isCardSecure(String cardNumber, String cardHolderName) {
    final cleanCardNumber = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Check for sequential numbers (e.g., 1234567890123456)
    bool isSequential = true;
    for (int i = 1; i < cleanCardNumber.length; i++) {
      int current = int.tryParse(cleanCardNumber[i]) ?? 0;
      int previous = int.tryParse(cleanCardNumber[i - 1]) ?? 0;
      if (current != (previous + 1) % 10) {
        isSequential = false;
        break;
      }
    }
    
    if (isSequential) {
      Get.snackbar('Error', 'Invalid card number - sequential digits not allowed');
      return false;
    }
    
    // Check for repeated digits (e.g., 1111111111111111)
    final firstDigit = cleanCardNumber[0];
    if (cleanCardNumber.split('').every((digit) => digit == firstDigit)) {
      Get.snackbar('Error', 'Invalid card number - repeated digits not allowed');
      return false;
    }
    
    return true;
  }

  // Clear all cards (for testing or reset)
  Future<void> clearAllCards() async {
    try {
      _cards.clear();
      await _saveCards();
      Get.snackbar('Success', 'All cards cleared');
    } catch (e) {
      AppLogger.log('Error clearing cards: $e');
      Get.snackbar('Error', 'Failed to clear cards');
    }
  }
}
