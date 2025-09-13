import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/card_model.dart';

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
      print('Error loading cards: $e');
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
      print('Error saving cards: $e');
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
      print('Error adding card: $e');
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
      print('Error removing card: $e');
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
      print('Error setting default card: $e');
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

  // Validate card data
  bool _validateCardData(String cardNumber, String cardHolderName, String expiryDate, String cvv) {
    // Clean card number
    final cleanCardNumber = cardNumber.replaceAll(' ', '');
    
    // Validate card number
    if (cleanCardNumber.isEmpty || cleanCardNumber.length < 13 || cleanCardNumber.length > 19) {
      Get.snackbar('Error', 'Please enter a valid card number');
      return false;
    }

    if (!RegExp(r'^\d+$').hasMatch(cleanCardNumber)) {
      Get.snackbar('Error', 'Card number should contain only digits');
      return false;
    }

    // Validate card holder name
    if (cardHolderName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter card holder name');
      return false;
    }

    // Validate expiry date (MM/YY format)
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiryDate)) {
      Get.snackbar('Error', 'Please enter expiry date in MM/YY format');
      return false;
    }

    final parts = expiryDate.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    
    if (month == null || year == null || month < 1 || month > 12) {
      Get.snackbar('Error', 'Please enter a valid expiry date');
      return false;
    }

    // Check if card is expired
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      Get.snackbar('Error', 'Card has expired');
      return false;
    }

    // Validate CVV
    if (cvv.trim().isEmpty || !RegExp(r'^\d{3,4}$').hasMatch(cvv.trim())) {
      Get.snackbar('Error', 'Please enter a valid CVV (3-4 digits)');
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
      print('Error clearing cards: $e');
      Get.snackbar('Error', 'Failed to clear cards');
    }
  }
} 