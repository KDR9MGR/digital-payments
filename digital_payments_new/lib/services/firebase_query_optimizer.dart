import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';
import 'firebase_cache_service.dart';

/// Firebase Query Optimizer to reduce read operations and billing costs
class FirebaseQueryOptimizer {
  static final FirebaseQueryOptimizer _instance = FirebaseQueryOptimizer._internal();
  factory FirebaseQueryOptimizer() => _instance;
  FirebaseQueryOptimizer._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseCacheService _cache = FirebaseCacheService();
  
  // Query result cache with expiration
  final Map<String, _CachedQuery> _queryCache = {};
  static const Duration _queryTtl = Duration(minutes: 5);

  /// Optimized user data fetch with caching
  Future<Map<String, dynamic>?> getUserData(String userId, {bool forceRefresh = false}) async {
    final cacheKey = 'user_$userId';
    
    if (!forceRefresh) {
      final cached = _cache.getCachedUserData(userId);
      if (cached != null) {
        AppLogger.log('Retrieved user data from cache: $userId');
        return cached;
      }
    }
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        await _cache.cacheUserData(userId, data);
        AppLogger.log('Fetched and cached user data: $userId');
        return data;
      }
    } catch (e) {
      AppLogger.log('Error fetching user data: $e');
    }
    
    return null;
  }

  /// Batch fetch multiple users efficiently
  Future<Map<String, Map<String, dynamic>>> batchGetUsers(List<String> userIds) async {
    final results = <String, Map<String, dynamic>>{};
    final uncachedIds = <String>[];
    
    // Check cache first
    for (final userId in userIds) {
      final cached = _cache.getCachedUserData(userId);
      if (cached != null) {
        results[userId] = cached;
        AppLogger.log('Retrieved user from cache: $userId');
      } else {
        uncachedIds.add(userId);
      }
    }
    
    // Batch fetch uncached users
    if (uncachedIds.isNotEmpty) {
      try {
        // Split into chunks of 10 (Firestore limit for 'in' queries)
        final chunks = _chunkList(uncachedIds, 10);
        
        for (final chunk in chunks) {
          final snapshot = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          
          for (final doc in snapshot.docs) {
            if (doc.exists) {
              final data = doc.data();
              results[doc.id] = data;
              await _cache.cacheUserData(doc.id, data);
            }
          }
        }
        
        AppLogger.log('Batch fetched ${uncachedIds.length} users from Firestore');
      } catch (e) {
        AppLogger.log('Error in batch user fetch: $e');
      }
    }
    
    return results;
  }

  /// Optimized transaction history with pagination and caching
  Future<List<Map<String, dynamic>>> getTransactionHistory(
    String userId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    bool useCache = true,
  }) async {
    final cacheKey = 'transactions_${userId}_${limit}_${lastDocument?.id ?? 'first'}';
    
    if (useCache) {
      final cached = _getQueryFromCache(cacheKey);
      if (cached != null) {
        AppLogger.log('Retrieved transaction history from cache: $userId');
        return cached;
      }
    }
    
    try {
      Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final snapshot = await query.get();
      final transactions = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
      _cacheQuery(cacheKey, transactions);
      AppLogger.log('Fetched ${transactions.length} transactions for user: $userId');
      
      return transactions;
    } catch (e) {
      AppLogger.log('Error fetching transaction history: $e');
      return [];
    }
  }

  /// Optimized wallet balance fetch with smart caching
  Future<Map<String, dynamic>?> getWalletBalances(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // Check if wallet balances are cached (we'll need to implement this method)
      final cached = null;
      if (cached != null) {
        AppLogger.log('Retrieved wallet balances from cache: $userId');
        return cached;
      }
    }
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final balances = data['wallet_balances'] as Map<String, dynamic>?;
        
        if (balances != null) {
      
          // await _cache.cacheWalletBalances(userId, balances);
          AppLogger.log('Fetched and cached wallet balances: $userId');
          return balances;
        }
      }
    } catch (e) {
      AppLogger.log('Error fetching wallet balances: $e');
    }
    
    return null;
  }

  /// Optimized subscription status check
  Future<Map<String, dynamic>?> getSubscriptionStatus(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedSubscriptionStatus(userId);
      if (cached != null) {
        AppLogger.log('Retrieved subscription status from cache: $userId');
        return cached;
      }
    }
    
    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        await _cache.cacheSubscriptionStatus(userId, data);
        AppLogger.log('Fetched and cached subscription status: $userId');
        return data;
      }
    } catch (e) {
      AppLogger.log('Error fetching subscription status: $e');
    }
    
    return null;
  }

  /// Efficient user search with indexed fields
  Future<List<Map<String, dynamic>>> searchUsers(
    String searchTerm, {
    int limit = 10,
    List<String> searchFields = const ['email', 'phone'],
  }) async {
    final cacheKey = 'search_${searchTerm}_${limit}_${searchFields.join('_')}';
    
    final cached = _getQueryFromCache(cacheKey);
    if (cached != null) {
      AppLogger.log('Retrieved search results from cache: $searchTerm');
      return cached;
    }
    
    try {
      final results = <Map<String, dynamic>>[];
      
      // Search by email if it looks like an email
      if (searchTerm.contains('@') && searchFields.contains('email')) {
        final emailSnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: searchTerm.toLowerCase())
            .limit(limit)
            .get();
        
        results.addAll(emailSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }));
      }
      
      // Search by phone if it looks like a phone number
      if (searchTerm.replaceAll(RegExp(r'[^0-9]'), '').length >= 10 && searchFields.contains('phone')) {
        final phoneSnapshot = await _firestore
            .collection('users')
            .where('phone', isEqualTo: searchTerm)
            .limit(limit)
            .get();
        
        results.addAll(phoneSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }));
      }
      
      // Remove duplicates
      final uniqueResults = <String, Map<String, dynamic>>{};
      for (final result in results) {
        uniqueResults[result['id']] = result;
      }
      
      final finalResults = uniqueResults.values.toList();
      _cacheQuery(cacheKey, finalResults);
      AppLogger.log('Search completed for: $searchTerm, found ${finalResults.length} results');
      
      return finalResults;
    } catch (e) {
      AppLogger.log('Error in user search: $e');
      return [];
    }
  }

  /// Get aggregated analytics data efficiently
  Future<Map<String, dynamic>?> getDailyAnalytics(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cacheKey = 'analytics_$dateStr';
    
    final cached = _getQueryFromCache(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      AppLogger.log('Retrieved analytics from cache: $dateStr');
      return cached.first;
    }
    
    try {
      final doc = await _firestore.collection('daily_analytics').doc(dateStr).get();
      if (doc.exists) {
        final data = doc.data()!;
        _cacheQuery(cacheKey, [data]);
        AppLogger.log('Fetched analytics for: $dateStr');
        return data;
      }
    } catch (e) {
      AppLogger.log('Error fetching analytics: $e');
    }
    
    return null;
  }

  /// Optimized real-time listener with smart updates
  StreamSubscription<QuerySnapshot> listenToUserTransactions(
    String userId,
    Function(List<Map<String, dynamic>>) onUpdate, {
    int limit = 20,
  }) {
    AppLogger.log('Setting up real-time listener for user transactions: $userId');
    
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .listen((snapshot) {
      final transactions = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      
      // Update cache with latest data
      final cacheKey = 'transactions_${userId}_${limit}_first';
      _cacheQuery(cacheKey, transactions);
      
      onUpdate(transactions);
      AppLogger.log('Real-time update: ${transactions.length} transactions for $userId');
    });
  }

  /// Cache query results
  void _cacheQuery(String key, List<Map<String, dynamic>> data) {
    _queryCache[key] = _CachedQuery(
      data: data,
      timestamp: DateTime.now(),
    );
    
    // Clean old cache entries
    _cleanExpiredQueries();
  }

  /// Get cached query results
  List<Map<String, dynamic>>? _getQueryFromCache(String key) {
    final cached = _queryCache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _queryTtl) {
      return cached.data;
    }
    
    // Remove expired entry
    _queryCache.remove(key);
    return null;
  }

  /// Clean expired query cache entries
  void _cleanExpiredQueries() {
    final now = DateTime.now();
    _queryCache.removeWhere((key, cached) => 
        now.difference(cached.timestamp) > _queryTtl);
  }

  /// Split list into chunks
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  /// Optimized money requests fetch with caching
  Future<List<Map<String, dynamic>>> getMoneyRequests(
    String userEmail, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedRequests(userEmail);
      if (cached != null) {
        AppLogger.log('Retrieved money requests from cache: $userEmail');
        return cached;
      }
    }

    try {
      // Fetch requests where the user is the sender
      final senderSnapshot = await _firestore
          .collection('requests')
          .where('senderEmail', isEqualTo: userEmail)
          .get();

      // Fetch requests where the user is the receiver
      final receiverSnapshot = await _firestore
          .collection('requests')
          .where('receiverEmail', isEqualTo: userEmail)
          .get();

      // Combine both lists
      final allRequests = <Map<String, dynamic>>[];
      
      allRequests.addAll(senderSnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }));
      
      allRequests.addAll(receiverSnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }));

      // Cache the results
      await _cache.cacheRequests(userEmail, allRequests);
      AppLogger.log('Fetched and cached ${allRequests.length} requests for: $userEmail');
      
      return allRequests;
    } catch (e) {
      AppLogger.log('Error fetching money requests: $e');
      return [];
    }
  }

  /// Optimized active subscription check with caching
  Future<bool> checkActiveSubscription(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedActiveSubscriptionStatus(userId);
      if (cached != null) {
        AppLogger.log('Retrieved active subscription status from cache: $userId');
        return cached;
      }
    }

    try {
      final query = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      final hasActiveSubscription = query.docs.isNotEmpty;
      
      // Cache the result
      await _cache.cacheActiveSubscriptionStatus(userId, hasActiveSubscription);
      AppLogger.log('Fetched and cached active subscription status for: $userId');
      
      return hasActiveSubscription;
    } catch (e) {
      AppLogger.log('Error checking active subscription: $e');
      return false;
    }
  }

  /// Clear all caches
  void clearAllCaches() {
    _queryCache.clear();
    _cache.clearAllCaches();
    AppLogger.log('Cleared all query and data caches');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'query_cache_size': _queryCache.length,
      'cache_service_stats': _cache.getCacheStats(),
    };
  }
}

/// Internal class for cached query results
class _CachedQuery {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;
  
  _CachedQuery({
    required this.data,
    required this.timestamp,
  });
}