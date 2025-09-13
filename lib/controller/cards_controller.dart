import '../data/card_model.dart';
import '/utils/app_logger.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_batch_service.dart';
import '../services/card_tokenization_service.dart';
import '../services/error_handling_service.dart';
import '../services/user_feedback_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/pin_auth_service.dart';
import '../services/encryption_service.dart';

class CardsController extends GetxController {
  static const String _cardsKey = 'saved_cards';

  final RxList<CardModel> _cards = <CardModel>[].obs;
  final RxBool _isLoading = false.obs;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseBatchService _batchService = FirebaseBatchService();
  final ErrorHandlingService _errorHandler = ErrorHandlingService();
  final UserFeedbackService _feedbackService = UserFeedbackService();
  final BiometricAuthService _biometricAuth = BiometricAuthService();
  final PinAuthService _pinAuth = PinAuthService();
  final EncryptionService _encryption = EncryptionService();

  List<CardModel> get cards => _cards;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    _initializeSecurityServices();
    loadCards();
  }

  Future<void> _initializeSecurityServices() async {
    try {
      await _encryption.initialize();
      await _pinAuth.initialize();
      AppLogger.log('Security services initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing security services: $e');
    }
  }

  /// Authenticate user using biometric or PIN
  Future<bool> _authenticateUser(String reason) async {
    try {
      // Check if biometric authentication is available
      final biometricAvailable = await _biometricAuth.isBiometricAvailable();
      
      if (biometricAvailable) {
        final biometricResult = await _biometricAuth.authenticate(
          reason: 'Please authenticate to $reason',
        );
        
        if (biometricResult.success) {
          return true;
        }
        
        // If biometric fails, fallback to PIN
        if (biometricResult.errorType == BiometricErrorType.authenticationFailed ||
            biometricResult.errorType == BiometricErrorType.notEnrolled) {
          return await _pinAuth.secureAuthenticate(
            operation: reason,
          );
        }
      }
      
      // Use PIN authentication as primary or fallback
      return await _pinAuth.secureAuthenticate(
        operation: reason,
      );
    } catch (e) {
      AppLogger.log('Authentication error: $e');
      return false;
    }
  }

  // Load cards from server and local storage
  Future<void> loadCards() async {
    try {
      _isLoading.value = true;

      // Try to load from server first if user is authenticated
      if (_auth.currentUser != null) {
        await _loadCardsFromServer();
      } else {
        // Fallback to local storage if not authenticated
        await _loadCardsFromLocal();
      }
    } catch (e) {
      AppLogger.log('Error loading cards: $e');
      // Fallback to local storage on server error
      await _loadCardsFromLocal();
    } finally {
      _isLoading.value = false;
    }
  }

  // Load cards from server
  Future<void> _loadCardsFromServer() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        final savedCards = userData['saved_cards'] as List<dynamic>?;

        if (savedCards != null) {
          _cards.value =
              savedCards
                  .map(
                    (cardData) =>
                        CardModel.fromJson(cardData as Map<String, dynamic>),
                  )
                  .toList();

          // Also save to local storage for offline access
          await _saveCardsToLocal();
          AppLogger.log('Loaded ${_cards.length} cards from server');
        }
      }
    } catch (e) {
      AppLogger.log('Error loading cards from server: $e');
      throw e;
    }
  }

  // Load cards from local storage
  Future<void> _loadCardsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = prefs.getString(_cardsKey);

      if (cardsJson != null) {
        final List<dynamic> cardsList = json.decode(cardsJson);
        _cards.value =
            cardsList.map((cardJson) => CardModel.fromJson(cardJson)).toList();
        AppLogger.log('Loaded ${_cards.length} cards from local storage');
      }
    } catch (e) {
      AppLogger.log('Error loading cards from local storage: $e');
      Get.snackbar('Error', 'Failed to load saved cards');
    }
  }

  // Save cards to both server and local storage
  Future<void> _saveCards() async {
    try {
      // Save to server if user is authenticated
      if (_auth.currentUser != null) {
        await _saveCardsToServer();
      }

      // Always save to local storage as backup
      await _saveCardsToLocal();
    } catch (e) {
      AppLogger.log('Error saving cards: $e');
      throw Exception('Failed to save cards');
    }
  }

  // Save cards to server
  Future<void> _saveCardsToServer() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final cardsData = _cards.map((card) => card.toJson()).toList();

      await _batchService.addUpdate(
        collection: 'users',
        documentId: userId,
        data: {'saved_cards': cardsData},
      );
      await _batchService.flushBatch();

      AppLogger.log('Saved ${_cards.length} cards to server');
    } catch (e) {
      AppLogger.log('Error saving cards to server: $e');
      throw e;
    }
  }

  // Save cards to local storage
  Future<void> _saveCardsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = json.encode(
        _cards.map((card) => card.toJson()).toList(),
      );
      await prefs.setString(_cardsKey, cardsJson);
      AppLogger.log('Saved ${_cards.length} cards to local storage');
    } catch (e) {
      AppLogger.log('Error saving cards to local storage: $e');
    }
  }

  // Add a new card with enhanced security
  Future<bool> addCard({
    required String cardNumber,
    required String cardHolderName,
    required String expiryDate,
    required String cvv,
  }) async {
    // Require authentication for adding cards
    final authenticated = await _authenticateUser('add a new card');
    if (!authenticated) {
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.authError,
        errorMessage: 'Authentication failed',
        userFriendlyMessage: 'Authentication required to add cards',
      );
      return false;
    }

    return await _feedbackService.executeWithLoading(
      operation: () async {
        // Validate card data
        if (!_validateCardData(cardNumber, cardHolderName, expiryDate, cvv)) {
          return false;
        }

        // Additional security validation
        if (!_isCardSecure(cardNumber, cardHolderName)) {
          return false;
        }

        final cleanCardNumber = cardNumber.replaceAll(' ', '');
        final cardType = CardModel.getCardType(cleanCardNumber);
        
        // Generate fingerprint for duplicate detection
        final fingerprint = CardModel.generateFingerprint(cleanCardNumber, expiryDate);
        
        // Check if card already exists using fingerprint
        if (CardTokenizationService.isDuplicateCard(fingerprint, _cards)) {
          await _errorHandler.handleValidationError(
            field: 'Card',
            message: 'This card is already saved to your account',
          );
          return false;
        }

        // Encrypt sensitive card data
        final cardData = CardData(
          cardNumber: cleanCardNumber,
          cvv: cvv.trim(),
          holderName: cardHolderName.trim(),
          expiryMonth: int.parse(expiryDate.split('/')[0]),
          expiryYear: 2000 + int.parse(expiryDate.split('/')[1]),
          cardType: cardType,
        );

        final encryptedCardData = await _encryption.encryptCardData(cardData);
        if (encryptedCardData == null) {
          await _errorHandler.handleError(
            errorType: ErrorHandlingService.unknownError,
            errorMessage: 'Failed to encrypt card data',
            userFriendlyMessage: 'Failed to secure card data. Please try again.',
          );
          return false;
        }

        // Tokenize card data securely
        final tokenizedCard = await CardTokenizationService.tokenizeCard(
          cardNumber: cleanCardNumber,
          cardHolderName: cardHolderName.trim(),
          expiryDate: expiryDate.trim(),
          cvv: cvv.trim(),
          cardType: cardType,
        );

        // Generate secure token for the card
        final cardToken = await _encryption.generatePaymentToken(cleanCardNumber);

        // Set as default if first card
        final newCard = tokenizedCard.copyWith(
          isDefault: _cards.isEmpty,
        );

        // Store encrypted card data separately
        await _encryption.encryptAndStore(
          'card_${newCard.id}',
          jsonEncode(encryptedCardData.toJson()),
        );

        // Store card token
        await _encryption.encryptAndStore(
          'token_${newCard.id}',
          cardToken,
        );

        _cards.add(newCard);
        await _saveCards();

        AppLogger.log('Card added and secured successfully: ${newCard.maskedCardNumber}');
        return true;
      },
      loadingMessage: 'Adding and securing your card...',
      successMessage: 'Card added and secured successfully! You can now use it for payments.',
      errorMessage: 'Failed to add card. Please try again.',
      showErrorDialog: true,
    ) ?? false;
  }

  // Remove a card with enhanced security
  Future<bool> removeCard(String cardId) async {
    // Require authentication for removing cards
    final authenticated = await _authenticateUser('remove this card');
    if (!authenticated) {
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.authError,
        errorMessage: 'Authentication failed',
        userFriendlyMessage: 'Authentication required to remove cards',
      );
      return false;
    }

    final cardIndex = _cards.indexWhere((card) => card.id == cardId);
    if (cardIndex == -1) {
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.validationError,
        errorMessage: 'Card not found',
        userFriendlyMessage: 'The selected card could not be found.',
      );
      return false;
    }

    final cardToRemove = _cards[cardIndex];
    final confirmed = await _feedbackService.showConfirmation(
      title: 'Remove Card',
      message: 'Are you sure you want to remove this card? This action cannot be undone.\n\n${cardToRemove.maskedCardNumber}',
      confirmText: 'Remove',
      isDestructive: true,
    );

    if (!confirmed) return false;

    return await _feedbackService.executeWithLoading(
      operation: () async {
        final removedCard = _cards[cardIndex];
        _cards.removeAt(cardIndex);

        // Securely wipe encrypted card data
        await _encryption.secureWipe('card_$cardId');
        await _encryption.secureWipe('token_$cardId');

        // If removed card was default, make first remaining card default
        if (removedCard.isDefault && _cards.isNotEmpty) {
          _cards[0] = _cards[0].copyWith(isDefault: true);
        }

        await _saveCards();
        AppLogger.log('Card removed and data wiped successfully: ${removedCard.maskedCardNumber}');
        return true;
      },
      loadingMessage: 'Removing card and wiping data...',
      successMessage: 'Card removed and data securely wiped',
      errorMessage: 'Failed to remove card. Please try again.',
    ) ?? false;
  }

  // Set default card
  Future<bool> setDefaultCard(String cardId) async {
    return await _feedbackService.executeWithLoading(
      operation: () async {
        // Remove default from all cards
        for (int i = 0; i < _cards.length; i++) {
          _cards[i] = _cards[i].copyWith(isDefault: false);
        }

        // Set new default
        final cardIndex = _cards.indexWhere((card) => card.id == cardId);
        if (cardIndex == -1) {
          await _errorHandler.handleError(
            errorType: ErrorHandlingService.validationError,
            errorMessage: 'Card not found',
            userFriendlyMessage: 'The selected card could not be found.',
          );
          return false;
        }

        _cards[cardIndex] = _cards[cardIndex].copyWith(isDefault: true);
        await _saveCards();

        AppLogger.log('Default card updated');
        return true;
      },
      loadingMessage: 'Updating default card...',
      successMessage: 'Default card updated successfully',
      errorMessage: 'Failed to update default card. Please try again.',
    ) ?? false;
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
  bool _validateCardData(
    String cardNumber,
    String cardHolderName,
    String expiryDate,
    String cvv,
  ) {
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

    // Validate card number using enhanced validation from tokenization service
    if (!CardTokenizationService.validateCardNumber(cleanCardNumber)) {
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
      Get.snackbar(
        'Error',
        'Card holder name should contain only letters and spaces',
      );
      return false;
    }

    // Validate expiry date using tokenization service
    if (!CardTokenizationService.validateExpiryDate(expiryDate.trim())) {
      Get.snackbar(
        'Error',
        'Please enter a valid expiry date in MM/YY format (e.g., 12/25)',
      );
      return false;
    }

    // Validate CVV using tokenization service
    final cardType = CardModel.getCardType(cleanCardNumber);
    if (!CardTokenizationService.validateCvv(cvv.trim(), cardType)) {
      final expectedLength = (cardType == 'American Express') ? 4 : 3;
      Get.snackbar(
        'Error',
        'CVV should be $expectedLength digits for $cardType',
      );
      return false;
    }

    return true;
  }

  // Get active cards for payments
  List<CardModel> get activeCards {
    return _cards.where((card) => card.isValidForPayment).toList();
  }
  
  // Get card for payment processing
  Future<Map<String, String>?> getCardForPayment(String cardId) async {
    try {
      final card = _cards.firstWhere((c) => c.id == cardId);
      if (!card.isValidForPayment) {
        Get.snackbar('Error', 'Card is not valid for payments');
        return null;
      }
      
      // Mark card as used and decrypt for payment
      final updatedCard = card.markAsUsed();
      final cardIndex = _cards.indexWhere((c) => c.id == cardId);
      _cards[cardIndex] = updatedCard;
      await _saveCards();
      
      return await CardTokenizationService.decryptCardData(updatedCard);
    } catch (e) {
      AppLogger.log('Error getting card for payment: $e');
      Get.snackbar('Error', 'Failed to process card for payment');
      return null;
    }
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
      Get.snackbar(
        'Error',
        'Invalid card number - sequential digits not allowed',
      );
      return false;
    }

    // Check for repeated digits (e.g., 1111111111111111)
    final firstDigit = cleanCardNumber[0];
    if (cleanCardNumber.split('').every((digit) => digit == firstDigit)) {
      Get.snackbar(
        'Error',
        'Invalid card number - repeated digits not allowed',
      );
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
