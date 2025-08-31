import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

/// Firebase Batch Service to optimize write operations and reduce billing
class FirebaseBatchService {
  static final FirebaseBatchService _instance = FirebaseBatchService._internal();
  factory FirebaseBatchService() => _instance;
  FirebaseBatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<_BatchOperation> _pendingOperations = [];
  final Map<String, dynamic> _pendingUpdates = {};
  
  // Batch configuration
  static const int _maxBatchSize = 500; // Firestore limit
  static const Duration _batchTimeout = Duration(seconds: 5);
  
  Timer? _batchTimer;

  /// Add a write operation to the batch queue
  Future<void> addWrite({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    final operation = _BatchOperation(
      type: _OperationType.set,
      collection: collection,
      documentId: documentId,
      data: data,
      merge: merge,
    );
    
    _pendingOperations.add(operation);
    AppLogger.log('Added write operation to batch: $collection/$documentId');
    
    _scheduleBatchExecution();
  }

  /// Add an update operation to the batch queue
  Future<void> addUpdate({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final operation = _BatchOperation(
      type: _OperationType.update,
      collection: collection,
      documentId: documentId,
      data: data,
    );
    
    _pendingOperations.add(operation);
    AppLogger.log('Added update operation to batch: $collection/$documentId');
    
    _scheduleBatchExecution();
  }

  /// Add a delete operation to the batch queue
  Future<void> addDelete({
    required String collection,
    required String documentId,
  }) async {
    final operation = _BatchOperation(
      type: _OperationType.delete,
      collection: collection,
      documentId: documentId,
    );
    
    _pendingOperations.add(operation);
    AppLogger.log('Added delete operation to batch: $collection/$documentId');
    
    _scheduleBatchExecution();
  }

  /// Batch multiple wallet balance updates
  Future<void> batchWalletUpdates(List<Map<String, dynamic>> updates) async {
    for (final update in updates) {
      await addUpdate(
        collection: 'users',
        documentId: update['userId'],
        data: {'wallet_balances': update['balances']},
      );
    }
  }

  /// Batch multiple transaction records
  Future<void> batchTransactionRecords(List<Map<String, dynamic>> transactions) async {
    for (final transaction in transactions) {
      await addWrite(
        collection: 'transactions',
        documentId: transaction['transactionId'],
        data: transaction,
      );
    }
  }

  /// Schedule batch execution
  void _scheduleBatchExecution() {
    // Cancel existing timer
    _batchTimer?.cancel();
    
    // Execute immediately if batch is full
    if (_pendingOperations.length >= _maxBatchSize) {
      _executeBatch();
      return;
    }
    
    // Schedule execution after timeout
    _batchTimer = Timer(_batchTimeout, () {
      _executeBatch();
    });
  }

  /// Execute pending batch operations
  Future<void> _executeBatch() async {
    if (_pendingOperations.isEmpty) return;
    
    try {
      _batchTimer?.cancel();
      
      // Split operations into chunks if needed
      final chunks = _chunkOperations(_pendingOperations, _maxBatchSize);
      
      for (final chunk in chunks) {
        await _executeBatchChunk(chunk);
      }
      
      AppLogger.log('Successfully executed ${_pendingOperations.length} batch operations');
      _pendingOperations.clear();
      
    } catch (e) {
      AppLogger.log('Error executing batch operations: $e');
      // Retry logic could be added here
      _pendingOperations.clear(); // Clear to prevent infinite retries
    }
  }

  /// Execute a chunk of batch operations
  Future<void> _executeBatchChunk(List<_BatchOperation> operations) async {
    final batch = _firestore.batch();
    
    for (final operation in operations) {
      final docRef = _firestore.collection(operation.collection).doc(operation.documentId);
      
      switch (operation.type) {
        case _OperationType.set:
          if (operation.merge) {
            batch.set(docRef, operation.data!, SetOptions(merge: true));
          } else {
            batch.set(docRef, operation.data!);
          }
          break;
        case _OperationType.update:
          batch.update(docRef, operation.data!);
          break;
        case _OperationType.delete:
          batch.delete(docRef);
          break;
      }
    }
    
    await batch.commit();
    AppLogger.log('Executed batch chunk with ${operations.length} operations');
  }

  /// Split operations into chunks
  List<List<_BatchOperation>> _chunkOperations(List<_BatchOperation> operations, int chunkSize) {
    final chunks = <List<_BatchOperation>>[];
    for (int i = 0; i < operations.length; i += chunkSize) {
      chunks.add(operations.sublist(i, i + chunkSize > operations.length ? operations.length : i + chunkSize));
    }
    return chunks;
  }

  /// Force execute all pending operations immediately
  Future<void> flushBatch() async {
    _batchTimer?.cancel();
    await _executeBatch();
  }

  /// Optimized transaction creation with automatic batching
  Future<void> createTransactionPair({
    required String senderId,
    required String recipientId,
    required double amount,
    required String currency,
    required Map<String, dynamic> senderBalances,
    required Map<String, dynamic> recipientBalances,
  }) async {
    final timestamp = DateTime.now();
    final senderTransactionId = _firestore.collection('transactions').doc().id;
    final recipientTransactionId = _firestore.collection('transactions').doc().id;
    
    // Batch wallet balance updates
    await addUpdate(
      collection: 'users',
      documentId: senderId,
      data: {'wallet_balances': senderBalances},
    );
    
    await addUpdate(
      collection: 'users',
      documentId: recipientId,
      data: {'wallet_balances': recipientBalances},
    );
    
    // Batch transaction records
    await addWrite(
      collection: 'transactions',
      documentId: senderTransactionId,
      data: {
        'transactionId': senderTransactionId,
        'userId': senderId,
        'amount': amount,
        'timestamp': timestamp,
        'type': 'send',
        'currency': currency,
        'recipientId': recipientId,
      },
    );
    
    await addWrite(
      collection: 'transactions',
      documentId: recipientTransactionId,
      data: {
        'transactionId': recipientTransactionId,
        'userId': recipientId,
        'amount': amount,
        'timestamp': timestamp,
        'type': 'receive',
        'currency': currency,
        'senderId': senderId,
      },
    );
    
    AppLogger.log('Queued transaction pair for batching: $senderId -> $recipientId');
  }

  /// Get pending operations count
  int getPendingOperationsCount() {
    return _pendingOperations.length;
  }

  /// Clear all pending operations
  void clearPendingOperations() {
    _batchTimer?.cancel();
    _pendingOperations.clear();
    AppLogger.log('Cleared all pending batch operations');
  }
}

/// Internal class for batch operations
class _BatchOperation {
  final _OperationType type;
  final String collection;
  final String documentId;
  final Map<String, dynamic>? data;
  final bool merge;
  
  _BatchOperation({
    required this.type,
    required this.collection,
    required this.documentId,
    this.data,
    this.merge = false,
  });
}

/// Operation types for batching
enum _OperationType {
  set,
  update,
  delete,
}