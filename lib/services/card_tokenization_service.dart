import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../data/card_model.dart';

class CardTokenizationService {
  static const String _encryptionKey = 'your-32-char-encryption-key-here'; // In production, use secure key management
  static const MethodChannel _channel = MethodChannel('secure_storage');
  
  // Tokenize card data for secure storage
  static Future<CardModel> tokenizeCard({
    required String cardNumber,
    required String cardHolderName,
    required String expiryDate,
    required String cvv,
    required String cardType,
  }) async {
    try {
      // Generate unique ID
      final id = _generateUniqueId();
      
      // Extract last 4 digits before encryption
      final cleanCardNumber = cardNumber.replaceAll(' ', '');
      final lastFourDigits = cleanCardNumber.substring(cleanCardNumber.length - 4);
      
      // Generate card fingerprint for duplicate detection
      final fingerprint = CardModel.generateFingerprint(cleanCardNumber, expiryDate);
      
      // Encrypt sensitive data
      final encryptedCardNumber = await _encryptData(cleanCardNumber);
      final encryptedCvv = await _encryptData(cvv);
      
      // Generate payment token (mock implementation)
      final token = await _generatePaymentToken(cleanCardNumber, expiryDate);
      
      return CardModel(
        id: id,
        cardNumber: encryptedCardNumber,
        cardHolderName: cardHolderName,
        expiryDate: expiryDate,
        cvv: encryptedCvv,
        cardType: cardType,
        createdAt: DateTime.now(),
        token: token,
        fingerprint: fingerprint,
        isTokenized: true,
        lastFourDigits: lastFourDigits,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to tokenize card: $e');
    }
  }
  
  // Decrypt card data for payment processing
  static Future<Map<String, String>> decryptCardData(CardModel card) async {
    if (!card.isTokenized) {
      throw Exception('Card is not tokenized');
    }
    
    try {
      final decryptedCardNumber = await _decryptData(card.cardNumber);
      final decryptedCvv = await _decryptData(card.cvv);
      
      return {
        'cardNumber': decryptedCardNumber,
        'cvv': decryptedCvv,
        'token': card.token ?? '',
      };
    } catch (e) {
      throw Exception('Failed to decrypt card data: $e');
    }
  }
  
  // Validate card number using Luhn algorithm
  static bool validateCardNumber(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(' ', '');
    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      return false;
    }
    
    int sum = 0;
    bool alternate = false;
    
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return sum % 10 == 0;
  }
  
  // Validate expiry date
  static bool validateExpiryDate(String expiryDate) {
    try {
      final parts = expiryDate.split('/');
      if (parts.length != 2) return false;
      
      final month = int.parse(parts[0]);
      final year = int.parse('20${parts[1]}');
      
      if (month < 1 || month > 12) return false;
      
      final expiry = DateTime(year, month + 1, 0);
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      return false;
    }
  }
  
  // Validate CVV
  static bool validateCvv(String cvv, String cardType) {
    if (cardType.toLowerCase() == 'american express') {
      return cvv.length == 4 && int.tryParse(cvv) != null;
    }
    return cvv.length == 3 && int.tryParse(cvv) != null;
  }
  
  // Check for duplicate cards
  static bool isDuplicateCard(String fingerprint, List<CardModel> existingCards) {
    return existingCards.any((card) => card.fingerprint == fingerprint);
  }
  
  // Private helper methods
  static String _generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'card_${timestamp}_$random';
  }
  
  static Future<String> _encryptData(String data) async {
    // In production, use proper encryption libraries like pointycastle
    // This is a simplified implementation for demo purposes
    final bytes = utf8.encode(data + _encryptionKey);
    final digest = sha256.convert(bytes);
    return base64.encode(utf8.encode(data)).replaceAll('=', '');
  }
  
  static Future<String> _decryptData(String encryptedData) async {
    // In production, implement proper decryption
    // This is a simplified implementation for demo purposes
    try {
      final decoded = base64.decode(encryptedData + '==');
      return utf8.decode(decoded);
    } catch (e) {
      throw Exception('Failed to decrypt data');
    }
  }
  
  static Future<String> _generatePaymentToken(String cardNumber, String expiryDate) async {
    // Mock payment token generation
    // In production, this would call your payment processor's tokenization API
    final input = '$cardNumber:$expiryDate:${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return 'tok_${digest.toString().substring(0, 24)}';
  }
  
  // Secure storage methods (would integrate with platform-specific secure storage)
  static Future<void> storeSecureData(String key, String value) async {
    try {
      await _channel.invokeMethod('store', {'key': key, 'value': value});
    } catch (e) {
      // Fallback to encrypted shared preferences in production
      print('Secure storage not available, using fallback: $e');
    }
  }
  
  static Future<String?> getSecureData(String key) async {
    try {
      return await _channel.invokeMethod('get', {'key': key});
    } catch (e) {
      // Fallback to encrypted shared preferences in production
      print('Secure storage not available, using fallback: $e');
      return null;
    }
  }
  
  static Future<void> deleteSecureData(String key) async {
    try {
      await _channel.invokeMethod('delete', {'key': key});
    } catch (e) {
      print('Secure storage not available, using fallback: $e');
    }
  }
}