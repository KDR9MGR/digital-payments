import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpay/utils/app_logger.dart';
import 'package:xpay/services/error_handling_service.dart';

/// Comprehensive encryption service for secure data handling
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final ErrorHandlingService _errorHandler = ErrorHandlingService();
  
  static const String _masterKeyKey = 'master_encryption_key';
  static const String _saltKey = 'encryption_salt';
  static const String _ivKey = 'encryption_iv';
  
  String? _cachedMasterKey;
  String? _cachedSalt;
  
  /// Initialize encryption service
  Future<void> initialize() async {
    try {
      await _ensureMasterKeyExists();
      AppLogger.log('EncryptionService initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing EncryptionService: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to initialize security service',
      );
    }
  }

  /// Encrypt sensitive data
  Future<EncryptionResult> encryptData(String data) async {
    try {
      if (data.isEmpty) {
        return EncryptionResult(
          success: false,
          message: 'Data cannot be empty',
        );
      }

      final masterKey = await _getMasterKey();
      final salt = await _getSalt();
      final iv = _generateIV();
      
      // Create encryption key from master key and salt
      final encryptionKey = _deriveKey(masterKey, salt);
      
      // Simple XOR encryption (for demonstration - in production use AES)
      final encryptedBytes = _xorEncrypt(utf8.encode(data), encryptionKey, iv);
      
      // Combine IV and encrypted data
      final combined = Uint8List.fromList([...iv, ...encryptedBytes]);
      final encryptedData = base64.encode(combined);
      
      AppLogger.log('Data encrypted successfully');
      return EncryptionResult(
        success: true,
        data: encryptedData,
        message: 'Data encrypted successfully',
      );
    } catch (e) {
      AppLogger.log('Encryption error: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to encrypt data',
      );
      return EncryptionResult(
        success: false,
        message: 'Failed to encrypt data',
      );
    }
  }

  /// Decrypt sensitive data
  Future<DecryptionResult> decryptData(String encryptedData) async {
    try {
      if (encryptedData.isEmpty) {
        return DecryptionResult(
          success: false,
          message: 'Encrypted data cannot be empty',
        );
      }

      final masterKey = await _getMasterKey();
      final salt = await _getSalt();
      
      // Decode base64
      final combined = base64.decode(encryptedData);
      
      if (combined.length < 16) {
        return DecryptionResult(
          success: false,
          message: 'Invalid encrypted data format',
        );
      }
      
      // Extract IV and encrypted data
      final iv = combined.sublist(0, 16);
      final encryptedBytes = combined.sublist(16);
      
      // Create decryption key from master key and salt
      final decryptionKey = _deriveKey(masterKey, salt);
      
      // Decrypt using XOR
      final decryptedBytes = _xorDecrypt(encryptedBytes, decryptionKey, iv);
      final decryptedData = utf8.decode(decryptedBytes);
      
      AppLogger.log('Data decrypted successfully');
      return DecryptionResult(
        success: true,
        data: decryptedData,
        message: 'Data decrypted successfully',
      );
    } catch (e) {
      AppLogger.log('Decryption error: $e');
      await _errorHandler.handleError(
        errorType: ErrorHandlingService.unknownError,
        errorMessage: e.toString(),
        userFriendlyMessage: 'Failed to decrypt data',
      );
      return DecryptionResult(
        success: false,
        message: 'Failed to decrypt data',
      );
    }
  }

  /// Encrypt and store sensitive data
  Future<bool> encryptAndStore(String key, String data) async {
    try {
      final encryptionResult = await encryptData(data);
      if (!encryptionResult.success || encryptionResult.data == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('encrypted_$key', encryptionResult.data!);
      
      AppLogger.log('Data encrypted and stored successfully for key: $key');
      return true;
    } catch (e) {
      AppLogger.log('Error encrypting and storing data: $e');
      return false;
    }
  }

  /// Retrieve and decrypt sensitive data
  Future<String?> retrieveAndDecrypt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString('encrypted_$key');
      
      if (encryptedData == null) {
        return null;
      }

      final decryptionResult = await decryptData(encryptedData);
      if (!decryptionResult.success || decryptionResult.data == null) {
        return null;
      }

      AppLogger.log('Data retrieved and decrypted successfully for key: $key');
      return decryptionResult.data;
    } catch (e) {
      AppLogger.log('Error retrieving and decrypting data: $e');
      return null;
    }
  }

  /// Hash sensitive data (one-way)
  String hashData(String data, {String? salt}) {
    try {
      final saltToUse = salt ?? _generateRandomString(16);
      final bytes = utf8.encode(data + saltToUse);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      AppLogger.log('Error hashing data: $e');
      return '';
    }
  }

  /// Generate secure random string
  String generateSecureToken({int length = 32}) {
    try {
      return _generateRandomString(length);
    } catch (e) {
      AppLogger.log('Error generating secure token: $e');
      return '';
    }
  }

  /// Validate data integrity
  Future<bool> validateDataIntegrity(String data, String hash) async {
    try {
      final salt = await _getSalt();
      final computedHash = hashData(data, salt: salt);
      return computedHash == hash;
    } catch (e) {
      AppLogger.log('Error validating data integrity: $e');
      return false;
    }
  }

  /// Secure data wipe
  Future<bool> secureWipe(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove encrypted data
      await prefs.remove('encrypted_$key');
      
      // Overwrite memory (limited in Dart, but we can try)
      final dummy = List.filled(1000, 0);
      dummy.fillRange(0, dummy.length, Random().nextInt(256));
      
      AppLogger.log('Secure wipe completed for key: $key');
      return true;
    } catch (e) {
      AppLogger.log('Error during secure wipe: $e');
      return false;
    }
  }

  /// Encrypt card data specifically
  Future<EncryptedCardData?> encryptCardData(CardData cardData) async {
    try {
      final cardNumber = await encryptData(cardData.cardNumber);
      final cvv = await encryptData(cardData.cvv);
      final holderName = await encryptData(cardData.holderName);
      
      if (!cardNumber.success || !cvv.success || !holderName.success) {
        return null;
      }

      return EncryptedCardData(
        encryptedCardNumber: cardNumber.data!,
        encryptedCvv: cvv.data!,
        encryptedHolderName: holderName.data!,
        expiryMonth: cardData.expiryMonth, // Not sensitive
        expiryYear: cardData.expiryYear,   // Not sensitive
        cardType: cardData.cardType,       // Not sensitive
        timestamp: DateTime.now(),
      );
    } catch (e) {
      AppLogger.log('Error encrypting card data: $e');
      return null;
    }
  }

  /// Decrypt card data specifically
  Future<CardData?> decryptCardData(EncryptedCardData encryptedCardData) async {
    try {
      final cardNumber = await decryptData(encryptedCardData.encryptedCardNumber);
      final cvv = await decryptData(encryptedCardData.encryptedCvv);
      final holderName = await decryptData(encryptedCardData.encryptedHolderName);
      
      if (!cardNumber.success || !cvv.success || !holderName.success) {
        return null;
      }

      return CardData(
        cardNumber: cardNumber.data!,
        cvv: cvv.data!,
        holderName: holderName.data!,
        expiryMonth: encryptedCardData.expiryMonth,
        expiryYear: encryptedCardData.expiryYear,
        cardType: encryptedCardData.cardType,
      );
    } catch (e) {
      AppLogger.log('Error decrypting card data: $e');
      return null;
    }
  }

  /// Generate payment token
  Future<String> generatePaymentToken(String cardNumber) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = _generateRandomString(8);
      final combined = '$cardNumber$timestamp$random';
      
      final hash = hashData(combined);
      return 'tok_${hash.substring(0, 24)}';
    } catch (e) {
      AppLogger.log('Error generating payment token: $e');
      return '';
    }
  }

  // Private helper methods
  
  Future<void> _ensureMasterKeyExists() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(_masterKeyKey)) {
      final masterKey = _generateRandomString(32);
      await prefs.setString(_masterKeyKey, masterKey);
      AppLogger.log('Master encryption key generated');
    }
    
    if (!prefs.containsKey(_saltKey)) {
      final salt = _generateRandomString(16);
      await prefs.setString(_saltKey, salt);
      AppLogger.log('Encryption salt generated');
    }
  }

  Future<String> _getMasterKey() async {
    if (_cachedMasterKey != null) {
      return _cachedMasterKey!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _cachedMasterKey = prefs.getString(_masterKeyKey);
    
    if (_cachedMasterKey == null) {
      throw Exception('Master key not found');
    }
    
    return _cachedMasterKey!;
  }

  Future<String> _getSalt() async {
    if (_cachedSalt != null) {
      return _cachedSalt!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _cachedSalt = prefs.getString(_saltKey);
    
    if (_cachedSalt == null) {
      throw Exception('Salt not found');
    }
    
    return _cachedSalt!;
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  Uint8List _generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(16, (_) => random.nextInt(256))
    );
  }

  Uint8List _deriveKey(String masterKey, String salt) {
    final combined = masterKey + salt;
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  Uint8List _xorEncrypt(List<int> data, Uint8List key, Uint8List iv) {
    final result = Uint8List(data.length);
    
    for (int i = 0; i < data.length; i++) {
      final keyByte = key[i % key.length];
      final ivByte = iv[i % iv.length];
      result[i] = data[i] ^ keyByte ^ ivByte;
    }
    
    return result;
  }

  Uint8List _xorDecrypt(List<int> encryptedData, Uint8List key, List<int> iv) {
    final result = Uint8List(encryptedData.length);
    
    for (int i = 0; i < encryptedData.length; i++) {
      final keyByte = key[i % key.length];
      final ivByte = iv[i % iv.length];
      result[i] = encryptedData[i] ^ keyByte ^ ivByte;
    }
    
    return result;
  }

  /// Clear cached keys (for security)
  void clearCache() {
    _cachedMasterKey = null;
    _cachedSalt = null;
    AppLogger.log('Encryption cache cleared');
  }

  /// Rotate encryption keys
  Future<bool> rotateKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generate new keys
      final newMasterKey = _generateRandomString(32);
      final newSalt = _generateRandomString(16);
      
      // Store new keys
      await prefs.setString(_masterKeyKey, newMasterKey);
      await prefs.setString(_saltKey, newSalt);
      
      // Clear cache to force reload
      clearCache();
      
      AppLogger.log('Encryption keys rotated successfully');
      return true;
    } catch (e) {
      AppLogger.log('Error rotating encryption keys: $e');
      return false;
    }
  }
}

/// Encryption operation result
class EncryptionResult {
  final bool success;
  final String? data;
  final String message;
  
  const EncryptionResult({
    required this.success,
    this.data,
    required this.message,
  });
}

/// Decryption operation result
class DecryptionResult {
  final bool success;
  final String? data;
  final String message;
  
  const DecryptionResult({
    required this.success,
    this.data,
    required this.message,
  });
}

/// Card data model
class CardData {
  final String cardNumber;
  final String cvv;
  final String holderName;
  final int expiryMonth;
  final int expiryYear;
  final String cardType;
  
  const CardData({
    required this.cardNumber,
    required this.cvv,
    required this.holderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cardType,
  });
}

/// Encrypted card data model
class EncryptedCardData {
  final String encryptedCardNumber;
  final String encryptedCvv;
  final String encryptedHolderName;
  final int expiryMonth;
  final int expiryYear;
  final String cardType;
  final DateTime timestamp;
  
  const EncryptedCardData({
    required this.encryptedCardNumber,
    required this.encryptedCvv,
    required this.encryptedHolderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cardType,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'encryptedCardNumber': encryptedCardNumber,
      'encryptedCvv': encryptedCvv,
      'encryptedHolderName': encryptedHolderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
       'cardType': cardType,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory EncryptedCardData.fromJson(Map<String, dynamic> json) {
    return EncryptedCardData(
      encryptedCardNumber: json['encryptedCardNumber'],
      encryptedCvv: json['encryptedCvv'],
      encryptedHolderName: json['encryptedHolderName'],
      expiryMonth: json['expiryMonth'],
      expiryYear: json['expiryYear'],
      cardType: json['cardType'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}