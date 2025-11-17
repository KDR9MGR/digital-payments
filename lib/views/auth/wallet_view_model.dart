import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../base_vm.dart';
import '../../data/request_money_model.dart';
import '../../data/transaction_model.dart';
import '../../data/user_model.dart';
import '../../utils/threading_utils.dart';
import '../../utils/crash_prevention.dart';
import '../../utils/app_logger.dart';
import '../../services/firebase_batch_service.dart';
import '../../services/firebase_query_optimizer.dart';
import '../../services/firebase_cache_service.dart';
import 'package:flutter/foundation.dart';

class WalletViewModel extends BaseViewModel {
  List<TransactionModel> _transactions = [];
  bool _isDisposed = false;

  List<TransactionModel> get transactions => _transactions;

  List<RequestMoneyModel> _requests = [];

  List<RequestMoneyModel> get requests => _requests;

  // Firebase optimization services
  final FirebaseBatchService _batchService = FirebaseBatchService();
  final FirebaseQueryOptimizer _queryOptimizer = FirebaseQueryOptimizer();
  final FirebaseCacheService _cacheService = FirebaseCacheService();

  // Memory safety check to prevent EXC_BAD_ACCESS
  bool get _isValid => !_isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Future init() async {
    if (!_isValid) return;

    try {
      dataloadingState = DataloadingState.dataLoadComplete;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.init error: $e',
          tag: 'WalletViewModel',
        );
      }
      dataloadingState = DataloadingState.error;
      notifyListeners();
    }
  }

  Future<void> addMoney(double amount, String currency) async {
    if (!_isValid) return;

    await CrashPrevention.safeExecute(() async {
      // Validate inputs to prevent crashes
      if (amount <= 0) {
        throw ArgumentError('Amount must be greater than zero');
      }
      if (currency.isEmpty) {
        throw ArgumentError('Currency cannot be empty');
      }

      // Use ThreadingUtils for Firebase operations to prevent main thread blocking
      await ThreadingUtils.runFirebaseOperation(() async {
        User? firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          if (kDebugMode) {
            AppLogger.warning(
              'WalletViewModel.addMoney: No authenticated user found',
              tag: 'WalletViewModel',
            );
          }
          return;
        }

        DocumentReference userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid);
        DocumentSnapshot userSnapshot = await userRef.get();

        if (userSnapshot.exists && userSnapshot.data() != null) {
          final data = userSnapshot.data() as Map<String, dynamic>?;
          if (data == null) {
            if (kDebugMode) {
              AppLogger.warning(
                'WalletViewModel.addMoney: User data is null',
                tag: 'WalletViewModel',
              );
            }
            return;
          }

          UserModel user = UserModel.fromMap(data);

          // Safe access to wallet balances with null check
          if (user.walletBalances.isEmpty) {
            user.walletBalances = <String, dynamic>{};
          }

          user.walletBalances[currency] =
              (user.walletBalances[currency] ?? 0) + amount;

          // Use batch service for optimized writes
          await _batchService.addUpdate(
            collection: 'users',
            documentId: user.userId,
            data: {'wallet_balances': user.walletBalances},
          );

          // Generate transaction ID without calling Firestore
          final transactionId =
              DateTime.now().millisecondsSinceEpoch.toString() +
              '_' +
              user.userId.substring(0, 8) +
              '_add';

          TransactionModel transaction = TransactionModel(
            transactionId: transactionId,
            userId: user.userId,
            amount: amount,
            timestamp: DateTime.now(),
            type: 'add',
            currency: currency,
          );

          await _batchService.addWrite(
            collection: 'transactions',
            documentId: transaction.transactionId,
            data: transaction.toMap(),
          );

          await _batchService.flushBatch();

          // Invalidate user cache
          await _cacheService.invalidateUserCaches(user.userId);
        }
      }, operationName: 'Add money to wallet');
    }, operationName: 'Add money operation');
  }

  Future<void> withdrawMoney(double amount, String currency) async {
    if (!_isValid) return;

    try {
      await ThreadingUtils.runFirebaseOperation(() async {
        User? firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          if (kDebugMode) {
            AppLogger.warning(
              'WalletViewModel.withdrawMoney: No authenticated user found',
              tag: 'WalletViewModel',
            );
          }
          return;
        }

        DocumentReference userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid);
        DocumentSnapshot userSnapshot = await userRef.get();

        if (userSnapshot.exists && userSnapshot.data() != null) {
          final data = userSnapshot.data() as Map<String, dynamic>?;
          if (data == null) {
            if (kDebugMode) {
              AppLogger.warning(
                'WalletViewModel.withdrawMoney: User data is null',
                tag: 'WalletViewModel',
              );
            }
            return;
          }

          UserModel user = UserModel.fromMap(data);

          // Safe access to wallet balances with null check
          if (user.walletBalances.isEmpty) {
            user.walletBalances = <String, dynamic>{};
          }

          double currentBalance = user.walletBalances[currency] ?? 0;

          if (currentBalance >= amount) {
            user.walletBalances[currency] = currentBalance - amount;

            // Use batch service for optimized writes
            await _batchService.addUpdate(
              collection: 'users',
              documentId: user.userId,
              data: {'wallet_balances': user.walletBalances},
            );

            TransactionModel transaction = TransactionModel(
              transactionId:
                  FirebaseFirestore.instance
                      .collection('transactions')
                      .doc()
                      .id,
              userId: user.userId,
              amount: amount,
              timestamp: DateTime.now(),
              type: 'withdraw',
              currency: currency,
            );

            await _batchService.addWrite(
              collection: 'transactions',
              documentId: transaction.transactionId,
              data: transaction.toMap(),
            );

            await _batchService.flushBatch();

            // Invalidate user cache
            await _cacheService.invalidateUserCaches(user.userId);
          } else {
            if (kDebugMode) {
              AppLogger.warning(
                'WalletViewModel.withdrawMoney: Insufficient balance',
                tag: 'WalletViewModel',
              );
            }
          }
        }
      }, operationName: 'Withdraw money from wallet');
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.withdrawMoney error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
  }

  Future<double> getCurrentWalletBalance(String currency) async {
    if (!_isValid) return 0.0;

    try {
      return await ThreadingUtils.runFirebaseOperation(() async {
        User? firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          if (kDebugMode) {
            AppLogger.warning(
              'WalletViewModel.getCurrentWalletBalance: No authenticated user found',
              tag: 'WalletViewModel',
            );
          }
          return 0.0;
        }

        // Try to get cached balance first
        final cachedBalance = _cacheService.getCachedWalletBalance(
          firebaseUser.uid,
          currency,
        );
        if (cachedBalance != null) {
          AppLogger.log(
            'Retrieved wallet balance from cache: $currency = $cachedBalance',
          );
          return cachedBalance;
        }

        // Use optimized query if cache miss
        final userData = await _queryOptimizer.getUserData(firebaseUser.uid);
        if (userData != null) {
          final walletBalances =
              userData['wallet_balances'] as Map<String, dynamic>? ?? {};
          final balance = (walletBalances[currency] ?? 0.0) as double;

          // Cache the balance for future use
          await _cacheService.cacheWalletBalance(
            firebaseUser.uid,
            currency,
            balance,
          );

          return balance;
        }

        return 0.0;
      }, operationName: 'Get current wallet balance');
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.getCurrentWalletBalance error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
    return 0.0;
  }

  Future<void> sendMoneyToUser(
    String recipientEmail,
    double amount,
    String currency,
  ) async {
    if (!_isValid) return;

    if (kDebugMode) {
      AppLogger.info(
        'WalletViewModel.sendMoneyToUser: recipientEmail: $recipientEmail',
        tag: 'WalletViewModel',
      );
    }

    try {
      

      await ThreadingUtils.runFirebaseOperation(() async {
        User? senderUser = FirebaseAuth.instance.currentUser;
        if (senderUser == null) {
          if (kDebugMode) {
            print(
              'WalletViewModel.sendMoneyToUser: No authenticated user found',
            );
          }
          return;
        }

        // Fetch sender's details using optimized query
        final senderData = await _queryOptimizer.getUserData(senderUser.uid);
        if (senderData == null) {
          if (kDebugMode) {
            AppLogger.warning(
              'WalletViewModel.sendMoneyToUser: Sender data not found',
              tag: 'WalletViewModel',
            );
          }
          return;
        }

        UserModel sender = UserModel.fromMap(senderData);

        // Search for recipient using optimized search
        final recipientResults = await _queryOptimizer.searchUsers(
          recipientEmail,
          searchFields: ['email'],
        );
        if (recipientResults.isEmpty) {
          throw 'Recipient with email $recipientEmail not found';
        }

        UserModel recipient = UserModel.fromMap(recipientResults.first);

        // Safe access to wallet balances with null checks
        if (sender.walletBalances.isEmpty) {
          sender.walletBalances = <String, dynamic>{};
        }
        if (recipient.walletBalances.isEmpty) {
          recipient.walletBalances = <String, dynamic>{};
        }

        // Check if sender has enough balance
        double senderBalance = sender.walletBalances[currency] ?? 0;
        if (senderBalance < amount) {
          throw 'Insufficient balance to send money';
        }

        // Update balances
        sender.walletBalances[currency] = senderBalance - amount;
        recipient.walletBalances[currency] =
            (recipient.walletBalances[currency] ?? 0) + amount;

        // Use batch service for optimized writes
        await _batchService.createTransactionPair(
          senderId: sender.userId,
          recipientId: recipient.userId,
          amount: amount,
          currency: currency,
          senderBalances: sender.walletBalances,
          recipientBalances: recipient.walletBalances,
        );

        // Invalidate caches for both users
        await _cacheService.invalidateUserCaches(sender.userId);
        await _cacheService.invalidateUserCaches(recipient.userId);
      }, operationName: 'Send money to user');

      // Notify listeners on main thread
      await ThreadingUtils.runUIOperation(() async {
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.sendMoneyToUser error: $e',
          tag: 'WalletViewModel',
        );
      }
      rethrow; // Rethrow the error to handle it in the calling function
    }
  }

  Future<void> fetchTransactionHistory({bool forceRefresh = false}) async {
    if (!_isValid) return;

    try {
      await ThreadingUtils.runFirebaseOperation(() async {
        User? firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          if (kDebugMode) {
            AppLogger.warning(
              'WalletViewModel.fetchTransactionHistory: No authenticated user found',
              tag: 'WalletViewModel',
            );
          }
          return;
        }

        // Check cache first if not forcing refresh
        if (!forceRefresh) {
          final cachedTransactions = await _cacheService.getCachedTransactions(
            firebaseUser.uid,
          );
          if (cachedTransactions != null && cachedTransactions.isNotEmpty) {
            _transactions =
                cachedTransactions
                    .map((data) {
                      try {
                        return TransactionModel.fromMap(data);
                      } catch (e) {
                        if (kDebugMode) {
                          AppLogger.warning(
                            'WalletViewModel.fetchTransactionHistory: Invalid cached transaction data: $e',
                            tag: 'WalletViewModel',
                          );
                        }
                        return null;
                      }
                    })
                    .where((transaction) => transaction != null)
                    .cast<TransactionModel>()
                    .toList();
            AppLogger.log(
              'Loaded ${_transactions.length} transactions from cache',
            );
            return;
          }
        }

        // Use optimized query with caching
        final transactionData = await _queryOptimizer.getTransactionHistory(
          firebaseUser.uid,
          limit: 50,
          useCache: !forceRefresh,
        );

        _transactions =
            transactionData
                .map((data) {
                  try {
                    return TransactionModel.fromMap(data);
                  } catch (e) {
                    if (kDebugMode) {
                      AppLogger.warning(
                        'WalletViewModel.fetchTransactionHistory: Invalid transaction data: $e',
                        tag: 'WalletViewModel',
                      );
                    }
                    return null;
                  }
                })
                .where((transaction) => transaction != null)
                .cast<TransactionModel>()
                .toList();

        // Cache the fetched transactions
        await _cacheService.cacheTransactions(
          firebaseUser.uid,
          transactionData,
        );
        AppLogger.log(
          'Fetched and cached ${_transactions.length} transactions from optimized query',
        );
      }, operationName: 'Fetch transaction history');

      // Notify listeners on main thread
      await ThreadingUtils.runUIOperation(() async {
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.fetchTransactionHistory error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
  }

  Future<void> requestMoney(
    String recipientEmail,
    double amount,
    String currency,
    String notes,
  ) async {
    if (!_isValid) return;

    try {
      // Validate amount
      if (amount <= 0) {
        throw 'Amount should be greater than zero';
      }

      await ThreadingUtils.runFirebaseOperation(() async {
        FirebaseFirestore firestore = FirebaseFirestore.instance;

        // Fetch recipient's details by email
        QuerySnapshot recipientQuery =
            await firestore
                .collection('users')
                .where('email_address', isEqualTo: recipientEmail)
                .get();
        if (recipientQuery.docs.isEmpty) {
          throw 'Recipient with email $recipientEmail not found';
        }

        // Create a new RequestMoneyModel for the request
        RequestMoneyModel requestMoney = RequestMoneyModel(
          requestId: firestore.collection('requests').doc().id,
          senderEmail: FirebaseAuth.instance.currentUser?.email,
          receiverEmail: recipientEmail,
          amount: amount,
          currency: currency,
          status: 'pending',
          requestedAt: DateTime.now(),
          notes: notes,
        );

        // Store the request using batch service for optimized writes
        await _batchService.addWrite(
          collection: 'requests',
          documentId: requestMoney.requestId!,
          data: requestMoney.toMap(),
        );
        await _batchService.flushBatch();
      }, operationName: 'Request money');

      if (kDebugMode) {
        AppLogger.info(
          'WalletViewModel.requestMoney: Money request sent successfully',
          tag: 'WalletViewModel',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.requestMoney error: $e',
          tag: 'WalletViewModel',
        );
      }
      rethrow; // Rethrow the error to handle it in the calling function
    }
  }

  Future<void> fetchRequests({bool forceRefresh = false}) async {
    if (!_isValid) return;

    try {
      await ThreadingUtils.runFirebaseOperation(() async {
        String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;
        if (currentUserEmail == null) return;

        // Use optimized query with caching
        final requestData = await _queryOptimizer.getMoneyRequests(
          currentUserEmail,
          forceRefresh: forceRefresh,
        );

        _requests =
            requestData
                .map((data) {
                  try {
                    return RequestMoneyModel.fromMap(data);
                  } catch (e) {
                    if (kDebugMode) {
                      AppLogger.warning(
                        'WalletViewModel.fetchRequests: Invalid request data: $e',
                        tag: 'WalletViewModel',
                      );
                    }
                    return null;
                  }
                })
                .where((request) => request != null)
                .cast<RequestMoneyModel>()
                .toList();

        AppLogger.log(
          'Fetched ${_requests.length} requests from optimized query',
        );
      }, operationName: 'Fetch requests');

      // Notify listeners on main thread
      await ThreadingUtils.runUIOperation(() async {
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.fetchRequests error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
  }

  Future<void> acceptRequest(RequestMoneyModel request) async {
    if (!_isValid) return;

    try {
      await ThreadingUtils.runFirebaseOperation(() async {
        request.status = 'accepted';
        await _batchService.addUpdate(
          collection: 'requests',
          documentId: request.requestId!,
          data: request.toMap(),
        );
        await _batchService.flushBatch();
      }, operationName: 'Accept request');

      // Invalidate user caches for both sender and receiver
      String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;
      if (currentUserEmail != null) {
        await _cacheService.invalidateUserCaches(currentUserEmail);
      }
      if (request.senderEmail != null) {
        await _cacheService.invalidateUserCaches(request.senderEmail!);
      }

      await fetchRequests(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.acceptRequest error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
  }

  Future<void> declineRequest(RequestMoneyModel request) async {
    if (!_isValid) return;

    try {
      await ThreadingUtils.runFirebaseOperation(() async {
        request.status = 'rejected';
        await _batchService.addUpdate(
          collection: 'requests',
          documentId: request.requestId!,
          data: request.toMap(),
        );
        await _batchService.flushBatch();
      }, operationName: 'Decline request');

      // Invalidate user caches for both sender and receiver
      String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;
      if (currentUserEmail != null) {
        await _cacheService.invalidateUserCaches(currentUserEmail);
      }
      if (request.senderEmail != null) {
        await _cacheService.invalidateUserCaches(request.senderEmail!);
      }

      await fetchRequests(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.declineRequest error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
  }

  Future<void> cancelRequest(RequestMoneyModel request) async {
    if (!_isValid) return;

    try {
      await ThreadingUtils.runFirebaseOperation(() async {
        request.status = 'canceled';
        await _batchService.addUpdate(
          collection: 'requests',
          documentId: request.requestId!,
          data: request.toMap(),
        );
        await _batchService.flushBatch();
      }, operationName: 'Cancel request');

      // Invalidate user caches for both sender and receiver
      String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;
      if (currentUserEmail != null) {
        await _cacheService.invalidateUserCaches(currentUserEmail);
      }
      if (request.receiverEmail != null) {
        await _cacheService.invalidateUserCaches(request.receiverEmail!);
      }

      await fetchRequests(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error(
          'WalletViewModel.cancelRequest error: $e',
          tag: 'WalletViewModel',
        );
      }
    }
  }

  
}
