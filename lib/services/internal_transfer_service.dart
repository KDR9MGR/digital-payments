import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/user_model.dart';
import '../data/transaction_model.dart';
import '../utils/app_logger.dart';
import '../utils/threading_utils.dart';
import '../utils/crash_prevention.dart';
import 'firebase_batch_service.dart';
import 'firebase_cache_service.dart';
import 'firebase_query_optimizer.dart';
import 'api_service.dart';

class InternalTransferService {
  static final InternalTransferService _instance =
      InternalTransferService._internal();
  factory InternalTransferService() => _instance;
  InternalTransferService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseBatchService _batchService = FirebaseBatchService();
  final FirebaseCacheService _cacheService = FirebaseCacheService();
  final FirebaseQueryOptimizer _queryOptimizer = FirebaseQueryOptimizer();
  final ApiService _apiService = ApiService();

  /// Transfer money between users via backend API
  Future<Map<String, dynamic>> transferMoneyViaAPI({
    required String recipientAccountId,
    required double amount,
    required String currency,
    String? description,
  }) async {
    try {
      // Security validation
      if (amount <= 0) {
        throw Exception('Transfer amount must be greater than zero');
      }

      if (amount > 10000) {
        throw Exception('Transfer amount exceeds daily limit of \$10,000');
      }

      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's account ID from Firestore
      final userData = await _queryOptimizer.getUserData(currentUser.uid);
      if (userData == null) {
        throw Exception('User data not found');
      }

      final sourceAccountId = userData['accountId'];
      if (sourceAccountId == null) {
        throw Exception('Source account not found. Please create an account first.');
      }

      AppLogger.log('Creating transfer via backend API: $sourceAccountId -> $recipientAccountId');

      // Create transfer via backend API
      final response = await _apiService.createTransfer(
        sourceAccountId: sourceAccountId,
        destinationAccountId: recipientAccountId,
        amount: amount,
        currency: currency,
        description: description,
      );

      if (response.isSuccess) {
        final transferId = response.data?['transferId'];
        AppLogger.log('Transfer created successfully: $transferId');

        // Create local transaction record for tracking
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final transactionId = '${timestamp}_${currentUser.uid.substring(0, 8)}_api_transfer';

        final transaction = TransactionModel(
          transactionId: transactionId,
          userId: currentUser.uid,
          amount: -amount, // Negative for outgoing
          timestamp: DateTime.now(),
          type: 'api_transfer_send',
          currency: currency,
        );

        final transactionData = transaction.toMap();
        transactionData['recipient_account_id'] = recipientAccountId;
        transactionData['transfer_id'] = transferId;
        transactionData['backend_transfer_data'] = response.data;
        if (description != null && description.isNotEmpty) {
          transactionData['description'] = description;
        }

        // Save transaction record to Firestore
        await _batchService.addWrite(
          collection: 'transactions',
          documentId: transaction.transactionId,
          data: transactionData,
        );
        await _batchService.flushBatch();

        // Invalidate user cache
        await _cacheService.invalidateUserCaches(currentUser.uid);

        return {
          'success': true,
          'transferId': transferId,
          'transactionId': transactionId,
          'amount': amount,
          'currency': currency,
          'message': 'Transfer completed successfully',
          'data': response.data,
        };
      } else {
        AppLogger.log('Transfer failed: ${response.error}');
        return {
          'success': false,
          'error': response.error ?? 'Transfer failed',
        };
      }
    } catch (e) {
      AppLogger.log('Transfer error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Transfer money between users with enhanced security (Firebase-based fallback)
  Future<Map<String, dynamic>> transferMoney({
    required String recipientEmail,
    required double amount,
    required String currency,
    String? note,
  }) async {
    // Security validation
    if (amount <= 0) {
      throw Exception('Transfer amount must be greater than zero');
    }

    if (amount > 10000) {
      throw Exception('Transfer amount exceeds daily limit of \$10,000');
    }

    // Rate limiting check
    await _checkRateLimit();

    // Fraud detection
    await _performFraudCheck(recipientEmail, amount);

    try {
      return await CrashPrevention.safeExecute(() async {
        return await ThreadingUtils.runFirebaseOperation(() async {
          // Validate inputs
          if (amount <= 0) {
            throw ArgumentError('Amount must be greater than zero');
          }
          if (currency.isEmpty) {
            throw ArgumentError('Currency cannot be empty');
          }
          if (recipientEmail.isEmpty) {
            throw ArgumentError('Recipient email cannot be empty');
          }

          User? currentUser = _auth.currentUser;
          if (currentUser == null) {
            throw Exception('User not authenticated');
          }

          // Get sender data
          final senderData = await _queryOptimizer.getUserData(currentUser.uid);
          if (senderData == null) {
            throw Exception('Sender not found');
          }

          UserModel sender = UserModel.fromMap(senderData);

          // Find recipient by email
          final recipientQuery =
              await _firestore
                  .collection('users')
                  .where('email_address', isEqualTo: recipientEmail)
                  .limit(1)
                  .get();

          if (recipientQuery.docs.isEmpty) {
            throw Exception('Recipient with email $recipientEmail not found');
          }

          UserModel recipient = UserModel.fromMap(
            recipientQuery.docs.first.data(),
          );

          // Prevent self-transfer
          if (sender.userId == recipient.userId) {
            throw Exception('Cannot transfer money to yourself');
          }

          // Initialize wallet balances if empty
          if (sender.walletBalances.isEmpty) {
            sender.walletBalances = <String, dynamic>{};
          }
          if (recipient.walletBalances.isEmpty) {
            recipient.walletBalances = <String, dynamic>{};
          }

          // Check sender balance
          double senderBalance =
              (sender.walletBalances[currency] ?? 0.0).toDouble();
          if (senderBalance < amount) {
            throw Exception(
              'Insufficient balance. Available: $senderBalance $currency',
            );
          }

          // Calculate new balances
          sender.walletBalances[currency] = senderBalance - amount;
          recipient.walletBalances[currency] =
              ((recipient.walletBalances[currency] ?? 0.0).toDouble()) + amount;

          // Generate unique transaction IDs
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final senderTransactionId =
              '${timestamp}_${sender.userId.substring(0, 8)}_send';
          final recipientTransactionId =
              '${timestamp}_${recipient.userId.substring(0, 8)}_receive';

          // Create transaction records
          final senderTransaction = TransactionModel(
            transactionId: senderTransactionId,
            userId: sender.userId,
            amount: -amount, // Negative for outgoing
            timestamp: DateTime.now(),
            type: 'internal_transfer_send',
            currency: currency,
          );

          final recipientTransaction = TransactionModel(
            transactionId: recipientTransactionId,
            userId: recipient.userId,
            amount: amount, // Positive for incoming
            timestamp: DateTime.now(),
            type: 'internal_transfer_receive',
            currency: currency,
          );

          // Create detailed transfer records with additional metadata
          final senderTransferData = senderTransaction.toMap();
          senderTransferData['recipient_id'] = recipient.userId;
          senderTransferData['recipient_email'] = recipientEmail;
          senderTransferData['recipient_name'] =
              '${recipient.firstName} ${recipient.lastName}';
          if (note != null && note.isNotEmpty) {
            senderTransferData['note'] = note;
          }

          final recipientTransferData = recipientTransaction.toMap();
          recipientTransferData['sender_id'] = sender.userId;
          recipientTransferData['sender_email'] = sender.emailAddress;
          recipientTransferData['sender_name'] =
              '${sender.firstName} ${sender.lastName}';
          if (note != null && note.isNotEmpty) {
            recipientTransferData['note'] = note;
          }

          // Use batch operations for atomicity
          await _batchService.addUpdate(
            collection: 'users',
            documentId: sender.userId,
            data: {'wallet_balances': sender.walletBalances},
          );

          await _batchService.addUpdate(
            collection: 'users',
            documentId: recipient.userId,
            data: {'wallet_balances': recipient.walletBalances},
          );

          await _batchService.addWrite(
            collection: 'transactions',
            documentId: senderTransaction.transactionId,
            data: senderTransferData,
          );

          await _batchService.addWrite(
            collection: 'transactions',
            documentId: recipientTransaction.transactionId,
            data: recipientTransferData,
          );

          // Execute all operations atomically
          await _batchService.flushBatch();

          // Invalidate caches for both users
          await _cacheService.invalidateUserCaches(sender.userId);
          await _cacheService.invalidateUserCaches(recipient.userId);

          AppLogger.log(
            'Internal transfer completed: ${sender.emailAddress} -> ${recipient.emailAddress}, Amount: $amount $currency',
            tag: 'InternalTransferService',
          );

          return {
            'success': true,
            'message': 'Transfer completed successfully',
            'transactionId': senderTransactionId,
            'recipientTransactionId': recipientTransactionId,
            'amount': amount,
            'currency': currency,
            'recipientName': '${recipient.firstName} ${recipient.lastName}',
            'newBalance': sender.walletBalances[currency],
          };
        }, operationName: 'Internal money transfer');
      }, operationName: 'Internal transfer operation');
    } catch (e) {
      AppLogger.error(
        'Internal transfer failed: $e',
        tag: 'InternalTransferService',
      );
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get user's wallet balance for a specific currency
  Future<double> getWalletBalance(String currency) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Try cache first
      final cachedBalance = _cacheService.getCachedWalletBalance(
        currentUser.uid,
        currency,
      );
      if (cachedBalance != null) {
        return cachedBalance;
      }

      // Fetch from database
      final userData = await _queryOptimizer.getUserData(currentUser.uid);
      if (userData != null) {
        final walletBalances =
            userData['wallet_balances'] as Map<String, dynamic>? ?? {};
        final balance = (walletBalances[currency] ?? 0.0).toDouble();

        // Cache the result
        await _cacheService.cacheWalletBalance(
          currentUser.uid,
          currency,
          balance,
        );

        return balance;
      }

      return 0.0;
    } catch (e) {
      AppLogger.error(
        'Error getting wallet balance: $e',
        tag: 'InternalTransferService',
      );
      return 0.0;
    }
  }

  /// Validate if a user exists by email
  Future<Map<String, dynamic>> validateRecipient(String email) async {
    try {
      if (email.isEmpty) {
        return {'valid': false, 'message': 'Email cannot be empty'};
      }

      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'valid': false, 'message': 'User not authenticated'};
      }

      // Check if trying to send to self
      final currentUserData = await _queryOptimizer.getUserData(
        currentUser.uid,
      );
      if (currentUserData != null &&
          currentUserData['email_address'] == email) {
        return {'valid': false, 'message': 'Cannot transfer money to yourself'};
      }

      // Check if recipient exists
      final recipientQuery =
          await _firestore
              .collection('users')
              .where('email_address', isEqualTo: email)
              .limit(1)
              .get();

      if (recipientQuery.docs.isEmpty) {
        return {'valid': false, 'message': 'No user found with this email address'};
      }

      final recipientData = recipientQuery.docs.first.data();
      return {
        'valid': true,
        'message': 'Valid recipient',
        'recipientName':
            '${recipientData['first_name']} ${recipientData['last_name']}',
        'recipientId': recipientData['userId'],
      };
    } catch (e) {
      AppLogger.error(
        'Error validating recipient: $e',
        tag: 'InternalTransferService',
      );
      
      // Provide more specific error messages
      String errorMessage;
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('permission') || e.toString().contains('denied')) {
        errorMessage = 'Permission denied. Please try again';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again';
      } else {
        errorMessage = 'Unable to validate recipient. Please try again';
      }
      
      return {'valid': false, 'message': errorMessage};
    }
  }

  /// Get transfer history for current user via backend API
  Future<List<TransactionModel>> getTransferHistoryViaAPI({
    int limit = 20,
    String? currency,
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      AppLogger.info(
        'Getting transfer history via API for user: ${currentUser.uid}',
        tag: 'InternalTransferService',
      );

      // Get transfer history from backend API
      final response = await _apiService.getTransferHistory(
        limit: limit,
        currency: currency,
      );

      if (response.isSuccess && response.data != null) {
        final List<dynamic> transfersData = response.data!['transfers'] as List<dynamic>? ?? [];
        
        // Convert API response to TransactionModel objects
        final List<TransactionModel> transfers = transfersData.map((transferData) {
          return TransactionModel.fromMap({
            'transactionId': transferData['id'] ?? '',
            'userId': currentUser.uid,
            'type': transferData['type'] ?? 'internal_transfer',
            'amount': (transferData['amount'] as num?)?.toDouble() ?? 0.0,
            'currency': transferData['currency'] ?? 'USD',
            'recipientEmail': transferData['recipient_email'] ?? '',
            'recipientName': transferData['recipient_name'] ?? '',
            'description': transferData['description'] ?? '',
            'status': transferData['status'] ?? 'completed',
            'timestamp': transferData['created_at'] != null 
                ? Timestamp.fromDate(DateTime.parse(transferData['created_at']))
                : Timestamp.now(),
            'metadata': transferData['metadata'] ?? {},
          });
        }).toList();

        AppLogger.info(
          'Successfully retrieved ${transfers.length} transfers from API',
          tag: 'InternalTransferService',
        );

        return transfers;
      } else {
        throw Exception(response.error ?? 'Failed to get transfer history');
      }
    } catch (e) {
      AppLogger.error(
        'Error getting transfer history via API: $e',
        tag: 'InternalTransferService',
      );
      
      // Fallback to Firebase method
      AppLogger.info(
        'Falling back to Firebase for transfer history',
        tag: 'InternalTransferService',
      );
      return await getTransferHistory(limit: limit, currency: currency);
    }
  }

  /// Get transfer history for current user (Firebase fallback)
  Future<List<TransactionModel>> getTransferHistory({
    int limit = 20,
    String? currency,
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .where(
            'type',
            whereIn: ['internal_transfer_send', 'internal_transfer_receive'],
          )
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (currency != null && currency.isNotEmpty) {
        query = query.where('currency', isEqualTo: currency);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map(
            (doc) =>
                TransactionModel.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      AppLogger.error(
        'Error getting transfer history: $e',
        tag: 'InternalTransferService',
      );
      return [];
    }
  }

  /// Rate limiting check to prevent abuse
  Future<void> _checkRateLimit() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      final recentTransfers =
          await _firestore
              .collection('transactions')
              .where('userId', isEqualTo: currentUser.uid)
              .where('type', isEqualTo: 'internal_transfer_send')
              .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
              .get();

      if (recentTransfers.docs.length >= 10) {
        throw Exception(
          'Transfer limit exceeded. Maximum 10 transfers per hour.',
        );
      }
    } catch (e) {
      AppLogger.error(
        'Rate limit check failed: $e',
        tag: 'InternalTransferService',
      );
      rethrow;
    }
  }

  /// Basic fraud detection checks
  Future<void> _performFraudCheck(String recipientEmail, double amount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Check for suspicious patterns
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));

      final recentTransfers =
          await _firestore
              .collection('transactions')
              .where('userId', isEqualTo: currentUser.uid)
              .where('type', isEqualTo: 'internal_transfer_send')
              .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
              .get();

      double dailyTotal = 0;
      for (var doc in recentTransfers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        dailyTotal += (data['amount'] as num).toDouble();
      }

      if (dailyTotal + amount > 50000) {
        throw Exception('Daily transfer limit of \$50,000 exceeded.');
      }

      // Check for self-transfer
      if (recipientEmail.toLowerCase() == currentUser.email?.toLowerCase()) {
        throw Exception('Cannot transfer money to yourself.');
      }
    } catch (e) {
      AppLogger.error('Fraud check failed: $e', tag: 'InternalTransferService');
      rethrow;
    }
  }
}
