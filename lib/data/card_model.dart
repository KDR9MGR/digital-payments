import 'dart:convert';
import 'package:crypto/crypto.dart';

class CardModel {
  final String id;
  final String cardNumber; // This will store encrypted/tokenized data
  final String cardHolderName;
  final String expiryDate;
  final String cvv; // This will store encrypted data
  final String cardType;
  final bool isDefault;
  final DateTime createdAt;
  
  // Security and tokenization fields
  final String? token; // Payment processor token
  final String? fingerprint; // Card fingerprint for duplicate detection
  final bool isTokenized;
  final String? lastFourDigits; // Store last 4 digits separately for display
  final DateTime? lastUsed;
  final bool isActive;

  CardModel({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryDate,
    required this.cvv,
    required this.cardType,
    this.isDefault = false,
    required this.createdAt,
    this.token,
    this.fingerprint,
    this.isTokenized = false,
    this.lastFourDigits,
    this.lastUsed,
    this.isActive = true,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardNumber': cardNumber, // Already encrypted/tokenized
      'cardHolderName': cardHolderName,
      'expiryDate': expiryDate,
      'cvv': cvv, // Already encrypted
      'cardType': cardType,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'token': token,
      'fingerprint': fingerprint,
      'isTokenized': isTokenized,
      'lastFourDigits': lastFourDigits,
      'lastUsed': lastUsed?.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Create from JSON
  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      cardNumber: json['cardNumber'],
      cardHolderName: json['cardHolderName'],
      expiryDate: json['expiryDate'],
      cvv: json['cvv'],
      cardType: json['cardType'],
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      token: json['token'],
      fingerprint: json['fingerprint'],
      isTokenized: json['isTokenized'] ?? false,
      lastFourDigits: json['lastFourDigits'],
      lastUsed: json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
      isActive: json['isActive'] ?? true,
    );
  }

  // Get masked card number for display
  String get maskedCardNumber {
    if (lastFourDigits != null) {
      return '**** **** **** $lastFourDigits';
    }
    // Fallback for legacy cards
    if (cardNumber.length >= 4) {
      return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
    }
    return '**** **** **** ****';
  }

  // Determine card type from card number
  static String getCardType(String cardNumber) {
    cardNumber = cardNumber.replaceAll(' ', '');
    
    if (cardNumber.startsWith('4')) {
      return 'Visa';
    } else if (cardNumber.startsWith('5') || 
               (cardNumber.length >= 2 && 
                int.tryParse(cardNumber.substring(0, 2)) != null &&
                int.parse(cardNumber.substring(0, 2)) >= 51 &&
                int.parse(cardNumber.substring(0, 2)) <= 55)) {
      return 'Mastercard';
    } else if (cardNumber.startsWith('3')) {
      return 'American Express';
    } else {
      return 'Unknown';
    }
  }

  // Generate card fingerprint for duplicate detection
  static String generateFingerprint(String cardNumber, String expiryDate) {
    final input = '${cardNumber.replaceAll(' ', '')}:$expiryDate';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Check if card is expired
  bool get isExpired {
    try {
      final parts = expiryDate.split('/');
      if (parts.length != 2) return true;
      
      final month = int.parse(parts[0]);
      final year = int.parse('20${parts[1]}');
      final expiry = DateTime(year, month + 1, 0); // Last day of expiry month
      
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return true;
    }
  }
  
  // Check if card is valid for payments
  bool get isValidForPayment {
    return isActive && !isExpired && (isTokenized || cardNumber.isNotEmpty);
  }
  
  // Update last used timestamp
  CardModel markAsUsed() {
    return copyWith(lastUsed: DateTime.now());
  }
  
  // Copy with method for updates
  CardModel copyWith({
    String? id,
    String? cardNumber,
    String? cardHolderName,
    String? expiryDate,
    String? cvv,
    String? cardType,
    bool? isDefault,
    DateTime? createdAt,
    String? token,
    String? fingerprint,
    bool? isTokenized,
    String? lastFourDigits,
    DateTime? lastUsed,
    bool? isActive,
  }) {
    return CardModel(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      expiryDate: expiryDate ?? this.expiryDate,
      cvv: cvv ?? this.cvv,
      cardType: cardType ?? this.cardType,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
      fingerprint: fingerprint ?? this.fingerprint,
      isTokenized: isTokenized ?? this.isTokenized,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      lastUsed: lastUsed ?? this.lastUsed,
      isActive: isActive ?? this.isActive,
    );
  }
}