import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xpay/services/encryption_service.dart';
import 'package:xpay/services/error_handling_service.dart';

void main() {
  group('EncryptionService Tests', () {
    late EncryptionService encryptionService;
    late ErrorHandlingService errorHandlingService;

    setUpAll(() {
      Get.testMode = true;
    });

    setUp(() async {
      // Clear any existing preferences
      SharedPreferences.setMockInitialValues({});
      
      // Initialize services
      errorHandlingService = ErrorHandlingService();
      Get.put(errorHandlingService);
      
      encryptionService = EncryptionService();
      await encryptionService.initialize();
    });

    tearDown(() async {
      Get.reset();
      encryptionService.clearCache();
    });

    group('Service Initialization', () {
      test('should initialize successfully', () async {
        expect(encryptionService, isNotNull);
        expect(() => encryptionService.initialize(), returnsNormally);
      });

      test('should be singleton', () {
        final instance1 = EncryptionService();
        final instance2 = EncryptionService();
        expect(instance1, same(instance2));
      });

      test('should generate master key on first initialization', () async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('master_encryption_key'), isTrue);
        expect(prefs.containsKey('encryption_salt'), isTrue);
      });
    });

    group('Data Encryption', () {
      test('should encrypt data successfully', () async {
        const testData = 'sensitive information';
        
        final result = await encryptionService.encryptData(testData);
        
        expect(result.success, isTrue);
        expect(result.data, isNotNull);
        expect(result.data, isNotEmpty);
        expect(result.data, isNot(equals(testData)));
        expect(result.message, equals('Data encrypted successfully'));
      });

      test('should fail to encrypt empty data', () async {
        final result = await encryptionService.encryptData('');
        
        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.message, equals('Data cannot be empty'));
      });

      test('should encrypt different data differently', () async {
        const data1 = 'first data';
        const data2 = 'second data';
        
        final result1 = await encryptionService.encryptData(data1);
        final result2 = await encryptionService.encryptData(data2);
        
        expect(result1.success, isTrue);
        expect(result2.success, isTrue);
        expect(result1.data, isNot(equals(result2.data)));
      });

      test('should encrypt same data differently each time (due to IV)', () async {
        const testData = 'same data';
        
        final result1 = await encryptionService.encryptData(testData);
        final result2 = await encryptionService.encryptData(testData);
        
        expect(result1.success, isTrue);
        expect(result2.success, isTrue);
        expect(result1.data, isNot(equals(result2.data)));
      });
    });

    group('Data Decryption', () {
      test('should decrypt data successfully', () async {
        const testData = 'sensitive information';
        
        final encryptResult = await encryptionService.encryptData(testData);
        expect(encryptResult.success, isTrue);
        
        final decryptResult = await encryptionService.decryptData(encryptResult.data!);
        
        expect(decryptResult.success, isTrue);
        expect(decryptResult.data, equals(testData));
        expect(decryptResult.message, equals('Data decrypted successfully'));
      });

      test('should fail to decrypt empty data', () async {
        final result = await encryptionService.decryptData('');
        
        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.message, equals('Encrypted data cannot be empty'));
      });

      test('should fail to decrypt invalid data', () async {
        const invalidData = 'invalid_encrypted_data';
        
        final result = await encryptionService.decryptData(invalidData);
        
        expect(result.success, isFalse);
        expect(result.data, isNull);
      });

      test('should fail to decrypt data with insufficient length', () async {
        const shortData = 'short';
        
        final result = await encryptionService.decryptData(shortData);
        
        expect(result.success, isFalse);
        expect(result.message, equals('Invalid encrypted data format'));
      });
    });

    group('Encrypt and Store', () {
      test('should encrypt and store data successfully', () async {
        const key = 'test_key';
        const data = 'test data to store';
        
        final result = await encryptionService.encryptAndStore(key, data);
        
        expect(result, isTrue);
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('encrypted_$key'), isTrue);
      });

      test('should retrieve and decrypt stored data', () async {
        const key = 'test_key';
        const data = 'test data to store';
        
        await encryptionService.encryptAndStore(key, data);
        final retrievedData = await encryptionService.retrieveAndDecrypt(key);
        
        expect(retrievedData, equals(data));
      });

      test('should return null for non-existent key', () async {
        const key = 'non_existent_key';
        
        final retrievedData = await encryptionService.retrieveAndDecrypt(key);
        
        expect(retrievedData, isNull);
      });
    });

    group('Hash Operations', () {
      test('should generate hash for data', () {
        const testData = 'data to hash';
        
        final hash = encryptionService.hashData(testData);
        
        expect(hash, isNotNull);
        expect(hash, isNotEmpty);
        expect(hash.length, equals(64)); // SHA-256 hex length
      });

      test('should generate different hashes for different data', () {
        const data1 = 'first data';
        const data2 = 'second data';
        
        final hash1 = encryptionService.hashData(data1);
        final hash2 = encryptionService.hashData(data2);
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('should generate same hash for same data', () {
        const testData = 'consistent data';
        
        final hash1 = encryptionService.hashData(testData);
        final hash2 = encryptionService.hashData(testData);
        
        expect(hash1, equals(hash2));
      });

      test('should validate data integrity correctly', () async {
        const testData = 'data to validate';
        final hash = encryptionService.hashData(testData);
        
        final isValid = await encryptionService.validateDataIntegrity(testData, hash);
        
        expect(isValid, isTrue);
      });

      test('should detect data tampering', () async {
        const originalData = 'original data';
        const tamperedData = 'tampered data';
        final hash = encryptionService.hashData(originalData);
        
        final isValid = await encryptionService.validateDataIntegrity(tamperedData, hash);
        
        expect(isValid, isFalse);
      });
    });

    group('Secure Token Generation', () {
      test('should generate secure token', () {
        final token = encryptionService.generateSecureToken();
        
        expect(token, isNotNull);
        expect(token, isNotEmpty);
        expect(token.length, equals(32)); // Default length
      });

      test('should generate token with custom length', () {
        const customLength = 16;
        final token = encryptionService.generateSecureToken(length: customLength);
        
        expect(token.length, equals(customLength));
      });

      test('should generate different tokens each time', () {
        final token1 = encryptionService.generateSecureToken();
        final token2 = encryptionService.generateSecureToken();
        
        expect(token1, isNot(equals(token2)));
      });
    });

    group('Card Data Encryption', () {
      test('should encrypt card data successfully', () async {
        final cardData = CardData(
          cardNumber: '1234567890123456',
          cvv: '123',
          holderName: 'John Doe',
          expiryMonth: 12,
          expiryYear: 2025,
          cardType: 'Visa',
        );
        
        final encryptedCard = await encryptionService.encryptCardData(cardData);
        
        expect(encryptedCard, isNotNull);
        expect(encryptedCard!.encryptedCardNumber, isNotEmpty);
        expect(encryptedCard.encryptedCvv, isNotEmpty);
        expect(encryptedCard.encryptedHolderName, isNotEmpty);
        expect(encryptedCard.expiryMonth, equals(cardData.expiryMonth));
        expect(encryptedCard.expiryYear, equals(cardData.expiryYear));
        expect(encryptedCard.cardType, equals(cardData.cardType));
      });

      test('should decrypt card data successfully', () async {
        final originalCard = CardData(
          cardNumber: '1234567890123456',
          cvv: '123',
          holderName: 'John Doe',
          expiryMonth: 12,
          expiryYear: 2025,
          cardType: 'Visa',
        );
        
        final encryptedCard = await encryptionService.encryptCardData(originalCard);
        expect(encryptedCard, isNotNull);
        
        final decryptedCard = await encryptionService.decryptCardData(encryptedCard!);
        
        expect(decryptedCard, isNotNull);
        expect(decryptedCard!.cardNumber, equals(originalCard.cardNumber));
        expect(decryptedCard.cvv, equals(originalCard.cvv));
        expect(decryptedCard.holderName, equals(originalCard.holderName));
        expect(decryptedCard.expiryMonth, equals(originalCard.expiryMonth));
        expect(decryptedCard.expiryYear, equals(originalCard.expiryYear));
        expect(decryptedCard.cardType, equals(originalCard.cardType));
      });
    });

    group('Key Management', () {
      test('should clear cache successfully', () {
        encryptionService.clearCache();
        // No exception should be thrown
        expect(() => encryptionService.clearCache(), returnsNormally);
      });

      test('should rotate keys successfully', () async {
        final prefs = await SharedPreferences.getInstance();
        final oldMasterKey = prefs.getString('master_encryption_key');
        final oldSalt = prefs.getString('encryption_salt');
        
        final result = await encryptionService.rotateKeys();
        
        expect(result, isTrue);
        
        final newMasterKey = prefs.getString('master_encryption_key');
        final newSalt = prefs.getString('encryption_salt');
        
        expect(newMasterKey, isNot(equals(oldMasterKey)));
        expect(newSalt, isNot(equals(oldSalt)));
      });

      test('should work after key rotation', () async {
        const testData = 'test data after rotation';
        
        await encryptionService.rotateKeys();
        
        final encryptResult = await encryptionService.encryptData(testData);
        expect(encryptResult.success, isTrue);
        
        final decryptResult = await encryptionService.decryptData(encryptResult.data!);
        expect(decryptResult.success, isTrue);
        expect(decryptResult.data, equals(testData));
      });
    });

    group('Error Handling', () {
      test('should handle encryption errors gracefully', () async {
        // This test would require mocking to force an error
        // For now, we test the error path with empty data
        final result = await encryptionService.encryptData('');
        
        expect(result.success, isFalse);
        expect(result.message, isNotEmpty);
      });

      test('should handle decryption errors gracefully', () async {
        final result = await encryptionService.decryptData('invalid_data');
        
        expect(result.success, isFalse);
        expect(result.message, isNotEmpty);
      });
    });

    group('Data Models', () {
      test('EncryptionResult should be created correctly', () {
        const result = EncryptionResult(
          success: true,
          data: 'encrypted_data',
          message: 'Success',
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals('encrypted_data'));
        expect(result.message, equals('Success'));
      });

      test('DecryptionResult should be created correctly', () {
        const result = DecryptionResult(
          success: true,
          data: 'decrypted_data',
          message: 'Success',
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals('decrypted_data'));
        expect(result.message, equals('Success'));
      });

      test('CardData should be created correctly', () {
        const cardData = CardData(
          cardNumber: '1234567890123456',
          cvv: '123',
          holderName: 'John Doe',
          expiryMonth: 12,
          expiryYear: 2025,
          cardType: 'Visa',
        );
        
        expect(cardData.cardNumber, equals('1234567890123456'));
        expect(cardData.cvv, equals('123'));
        expect(cardData.holderName, equals('John Doe'));
        expect(cardData.expiryMonth, equals(12));
        expect(cardData.expiryYear, equals(2025));
        expect(cardData.cardType, equals('Visa'));
      });

      test('EncryptedCardData should serialize/deserialize correctly', () {
        final timestamp = DateTime.now();
        final encryptedCard = EncryptedCardData(
          encryptedCardNumber: 'encrypted_number',
          encryptedCvv: 'encrypted_cvv',
          encryptedHolderName: 'encrypted_name',
          expiryMonth: 12,
          expiryYear: 2025,
          cardType: 'Visa',
          timestamp: timestamp,
        );
        
        final json = encryptedCard.toJson();
        final restored = EncryptedCardData.fromJson(json);
        
        expect(restored.encryptedCardNumber, equals(encryptedCard.encryptedCardNumber));
        expect(restored.encryptedCvv, equals(encryptedCard.encryptedCvv));
        expect(restored.encryptedHolderName, equals(encryptedCard.encryptedHolderName));
        expect(restored.expiryMonth, equals(encryptedCard.expiryMonth));
        expect(restored.expiryYear, equals(encryptedCard.expiryYear));
        expect(restored.cardType, equals(encryptedCard.cardType));
        expect(restored.timestamp.millisecondsSinceEpoch, 
               equals(encryptedCard.timestamp.millisecondsSinceEpoch));
      });
    });
  });
}