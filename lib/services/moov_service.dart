import '../utils/app_logger.dart';
import '../config/moov_config.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoovService {
  static final MoovService _instance = MoovService._internal();
  factory MoovService() => _instance;
  MoovService._internal();

  // Rate limiting tracking
  final Map<String, int> _dailyTransferCounts = {};
  final Map<String, DateTime> _lastTransferDates = {};

  // Initialize Moov service
  static Future<void> init() async {
    try {
      AppLogger.log('Initializing Moov service...');
      AppLogger.log('Environment: ${MoovConfig.environmentStatus}');

      if (!MoovConfig.isConfigured) {
        throw Exception('Moov service is not properly configured');
      }
      
      if (MoovConfig.isProduction && !MoovConfig.isProductionReady) {
        throw Exception('Moov service is not ready for production');
      }
      
      AppLogger.log('Moov Service initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing Moov Service: $e');
      rethrow;
    }
  }

  // Create a customer account
  Future<Map<String, dynamic>?> createAccount({
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
    required String userId,
  }) async {
    // In test mode, return a mock account ID
    if (MoovConfig.testMode) {
      AppLogger.log('Test mode: Creating mock Moov account for: $email');
      await Future.delayed(Duration(milliseconds: 300));
      return {
        'success': true,
        'accountId': 'test_account_${userId.substring(0, 8)}',
      };
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createMoovAccount');
      final result = await callable.call({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        if (phone != null) 'phone': phone,
      });
      final data = Map<String, dynamic>.from(result.data ?? {});
      return data;
    } catch (e) {
      AppLogger.log('Error creating account via function: $e');
      return {
        'success': false,
        'error': 'Failed to create account',
      };
    }
  }

  // Get account details
  Future<Map<String, dynamic>?> getAccount(String accountId) async {
    try {
      if (MoovConfig.testMode) {
        return {'success': true, 'data': {'accountID': accountId, 'status': 'active'}};
      }
      final callable = FirebaseFunctions.instance.httpsCallable('getMoovAccount');
      final result = await callable.call({'accountId': accountId});
      final data = Map<String, dynamic>.from(result.data ?? {});
      return data;
    } catch (e) {
      AppLogger.log('Error getting account via function: $e');
      return {'success': false, 'error': 'Failed to get account'};
    }
  }

  // Get payment methods for an account
  Future<List<Map<String, dynamic>>> getPaymentMethods(String accountId) async {
    if (MoovConfig.testMode) {
      return [
        {
          'paymentMethodID': 'pm_test_wallet',
          'type': 'moov-wallet',
          'status': 'active'
        }
      ];
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('listPaymentMethods');
      final result = await callable.call({'accountId': accountId});
      final data = Map<String, dynamic>.from(result.data ?? {});
      final list = data['data'];
      if (list is List) {
        return List<Map<String, dynamic>>.from(list);
      }
      return [];
    } catch (e) {
      AppLogger.log('Error getting payment methods via function: $e');
      return [];
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(
    String accountId,
    String paymentMethodId,
  ) async {
    try {
      if (MoovConfig.testMode) return true;
      final callable = FirebaseFunctions.instance.httpsCallable('deletePaymentMethod');
      final result = await callable.call({
        'accountId': accountId,
        'paymentMethodId': paymentMethodId,
      });
      final data = Map<String, dynamic>.from(result.data ?? {});
      return data['success'] == true;
    } catch (e) {
      AppLogger.log('Error deleting payment method via function: $e');
      return false;
    }
  }

  // Process P2P transfer with rate limiting and validation
  Future<Map<String, dynamic>?> processP2PTransfer({
    required String senderAccountId,
    required String recipientAccountId,
    required double amount,
    required String currency,
    String? description,
  }) async {
    try {
      // Validate transfer amount
      if (amount < MoovConfig.minTransferAmount) {
        return {
          'success': false,
          'error': 'Transfer amount must be at least \$${MoovConfig.minTransferAmount}',
        };
      }
      
      if (amount > MoovConfig.maxTransferAmount) {
        return {
          'success': false,
          'error': 'Transfer amount cannot exceed \$${MoovConfig.maxTransferAmount}',
        };
      }
      
      // Check rate limiting
      if (!_checkRateLimit(senderAccountId)) {
        return {
          'success': false,
          'error': 'Daily transfer limit exceeded. Maximum ${MoovConfig.maxTransfersPerDay} transfers per day.',
        };
      }
      
      if (MoovConfig.testMode) {
        AppLogger.log('Test mode: Simulating P2P transfer ${amount.toStringAsFixed(2)} $currency from $senderAccountId to $recipientAccountId');
        await Future.delayed(Duration(milliseconds: 300));
        _incrementTransferCount(senderAccountId);
        return {
          'success': true,
          'transferId': 'test_tx_${DateTime.now().millisecondsSinceEpoch}',
          'status': 'completed',
          'data': {
            'transferID': 'test_tx_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'completed'
          }
        };
      }
      AppLogger.log('Processing P2P transfer from $senderAccountId to $recipientAccountId');

      // Try to get wallet IDs for more efficient transfers
      String? senderWalletId;
      String? recipientWalletId;
      
      try {
        // Get sender wallet ID from Firestore
        final senderQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('moovAccountId', isEqualTo: senderAccountId)
            .limit(1)
            .get();
        
        if (senderQuery.docs.isNotEmpty) {
          senderWalletId = senderQuery.docs.first.data()['moovWalletId'];
          AppLogger.log('Found sender wallet ID: $senderWalletId');
        }
        
        // Get recipient wallet ID from Firestore
        final recipientQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('moovAccountId', isEqualTo: recipientAccountId)
            .limit(1)
            .get();
        
        if (recipientQuery.docs.isNotEmpty) {
          recipientWalletId = recipientQuery.docs.first.data()['moovWalletId'];
          AppLogger.log('Found recipient wallet ID: $recipientWalletId');
        }
      } catch (e) {
        AppLogger.log('Warning: Could not fetch wallet IDs, using account IDs as fallback: $e');
      }

      int attempts = 0;
      while (attempts < MoovConfig.maxRetries) {
        attempts++;
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('createP2PTransfer');
          final result = await callable.call({
            // Pass wallet IDs if available, otherwise fallback to account IDs
            if (senderWalletId != null) 'senderWalletId': senderWalletId,
            if (recipientWalletId != null) 'recipientWalletId': recipientWalletId,
            'senderAccountId': senderAccountId,
            'recipientAccountId': recipientAccountId,
            'amount': amount,
            'currency': currency,
            if (description != null) 'description': description,
          });
          final data = Map<String, dynamic>.from(result.data ?? {});
          if (data['success'] == true) {
            _incrementTransferCount(senderAccountId);
            return data;
          } else if (attempts < MoovConfig.maxRetries) {
            AppLogger.log('Server error, retrying... Attempt $attempts/${MoovConfig.maxRetries}');
            await Future.delayed(MoovConfig.retryDelay * attempts);
            continue;
          } else {
            return data;
          }
        } catch (e) {
          if (attempts < MoovConfig.maxRetries) {
            AppLogger.log('Network error, retrying... Attempt $attempts/${MoovConfig.maxRetries}: $e');
            await Future.delayed(MoovConfig.retryDelay * attempts);
            continue;
          } else {
            AppLogger.log('Error processing P2P transfer: $e');
            return {'success': false, 'error': 'Network error: $e'};
          }
        }
      }

      return {
        'success': false,
        'error': 'Transfer failed after ${MoovConfig.maxRetries} attempts',
      };
    } catch (e) {
      AppLogger.log('Error processing P2P transfer: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get or create Moov account for user
  Future<String?> getOrCreateUserAccount({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      if (MoovConfig.testMode) {
        return 'test_account_${userId.substring(0, 8)}';
      }

      // Try to read from backend (will throw if missing)
      try {
        final callableGet = FirebaseFunctions.instance.httpsCallable('getOrCreateMoovAccount');
        final result = await callableGet.call({});
        final data = Map<String, dynamic>.from(result.data ?? {});
        if (data['success'] == true && data['accountId'] is String) {
          return data['accountId'] as String;
        }
      } catch (_) {
        // fall through to create
      }

      // Create new account if not exists
      final result = await createAccount(
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        userId: userId,
      );

      if (result?['success'] == true) {
        return result?['accountId'];
      }
      return null;
    } catch (e) {
      AppLogger.log('Error getting or creating user account: $e');
      return null;
    }
  }

  // Verify bank account with Moov using micro-deposit confirmation (server-driven)
  Future<Map<String, dynamic>> verifyBankAccount({
    required String accountId,
    required String bankAccountId,
    required List<int> microDeposits,
  }) async {
    try {
      if (MoovConfig.testMode) {
        await Future.delayed(Duration(milliseconds: 300));
        return {
          'status': 'verified',
          'success': true,
          'message': 'Test mode verification successful',
        };
      }

      final callable = FirebaseFunctions.instance.httpsCallable('verifyBankAccount');
      final result = await callable.call({
        'accountId': accountId,
        'bankAccountId': bankAccountId,
        'microDeposits': microDeposits,
      });
      final data = Map<String, dynamic>.from(result.data ?? {});
      if (data['success'] == true) {
        return {
          'status': 'verified',
          'success': true,
          'message': data['message'] ?? 'Verification successful',
        };
      }
      return {
        'status': 'failed',
        'success': false,
        'error': data['error'] ?? 'Verification failed',
      };
    } catch (e) {
      AppLogger.log('Error verifying bank account via function: $e');
      return {
        'status': 'failed',
        'error': 'Verification failed: $e',
      };
    }
  }

  // Initiate bank account verification from raw bank details (legacy/UI flow)
  // In live mode this will initiate micro-deposits via a Cloud Function and return a pending status
  // In test mode, this will immediately return verified for smoother local testing
  Future<Map<String, dynamic>> startBankAccountVerification({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
    required String accountNumber,
    required String routingNumber,
    required String accountType,
    required String accountHolderName,
  }) async {
    try {
      // Ensure the user has a Moov account
      final moovAccountId = await getOrCreateUserAccount(
        userId: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      if (moovAccountId == null) {
        return {
          'status': 'failed',
          'success': false,
          'error': 'Unable to create or load Moov account',
        };
      }

      if (MoovConfig.testMode) {
        return {
          'status': 'verified',
          'success': true,
          'message': 'Test mode verification successful',
          'moovAccountId': moovAccountId,
        };
      }

      // Attempt to kick off bank linking + micro-deposit verification on the server
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('linkBankAccount');
        await callable.call({
          'accountId': moovAccountId,
          'accountHolderName': accountHolderName,
          'accountNumber': accountNumber,
          'routingNumber': routingNumber,
          'accountType': accountType,
        });
      } catch (e) {
        // Log but still return pending to allow UI to reflect state
        AppLogger.log('Error initiating bank account linking: $e');
      }

      return {
        'status': 'pending',
        'success': true,
        'message': 'Verification initiated. Please confirm micro-deposits when available.',
        'moovAccountId': moovAccountId,
      };
    } catch (e) {
      AppLogger.log('Error starting bank account verification: $e');
      return {
        'status': 'failed',
        'success': false,
        'error': 'Failed to start verification: $e',
      };
    }
  }

  // Rate limiting helper methods
  bool _checkRateLimit(String accountId) {
    final today = DateTime.now();
    final lastTransferDate = _lastTransferDates[accountId];
    
    // Reset counter if it's a new day
    if (lastTransferDate == null || 
        !_isSameDay(lastTransferDate, today)) {
      _dailyTransferCounts[accountId] = 0;
      _lastTransferDates[accountId] = today;
    }
    
    final currentCount = _dailyTransferCounts[accountId] ?? 0;
    return currentCount < MoovConfig.maxTransfersPerDay;
  }
  
  void _incrementTransferCount(String accountId) {
    _dailyTransferCounts[accountId] = (_dailyTransferCounts[accountId] ?? 0) + 1;
    _lastTransferDates[accountId] = DateTime.now();
  }
  
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}
