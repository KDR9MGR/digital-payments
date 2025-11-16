import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import '../utils/app_logger.dart';

/// Firebase Cache Service to minimize read operations and reduce billing
class FirebaseCacheService {
  static final FirebaseCacheService _instance =
      FirebaseCacheService._internal();
  factory FirebaseCacheService() => _instance;
  FirebaseCacheService._internal();

  final GetStorage _cache = GetStorage();
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, dynamic> _memoryCache = {};

  // Cache duration settings
  static const Duration _userDataCacheDuration = Duration(minutes: 15);
  static const Duration _transactionCacheDuration = Duration(minutes: 5);
  static const Duration _subscriptionCacheDuration = Duration(minutes: 30);
  static const Duration _balanceCacheDuration = Duration(minutes: 2);

  /// Cache user data with timestamp
  Future<void> cacheUserData(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final cacheKey = 'user_$userId';
      final timestampKey = '${cacheKey}_timestamp';

      await _cache.write(cacheKey, jsonEncode(userData));
      await _cache.write(timestampKey, DateTime.now().millisecondsSinceEpoch);

      // Also cache in memory for faster access
      _memoryCache[cacheKey] = userData;
      _cacheTimestamps[cacheKey] = DateTime.now();

      AppLogger.log('Cached user data for: $userId');
    } catch (e) {
      AppLogger.log('Error caching user data: $e');
    }
  }

  /// Get cached user data if valid
  Map<String, dynamic>? getCachedUserData(String userId) {
    try {
      final cacheKey = 'user_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _userDataCacheDuration) {
          AppLogger.log('Retrieved user data from memory cache: $userId');
          return _memoryCache[cacheKey] as Map<String, dynamic>;
        }
      }

      // Check persistent cache
      final timestampKey = '${cacheKey}_timestamp';
      final cachedData = _cache.read(cacheKey);
      final timestamp = _cache.read(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < _userDataCacheDuration) {
          final userData = jsonDecode(cachedData) as Map<String, dynamic>;

          // Update memory cache
          _memoryCache[cacheKey] = userData;
          _cacheTimestamps[cacheKey] = cacheTime;

          AppLogger.log('Retrieved user data from persistent cache: $userId');
          return userData;
        }
      }
    } catch (e) {
      AppLogger.log('Error retrieving cached user data: $e');
    }
    return null;
  }

  /// Cache wallet balance
  Future<void> cacheWalletBalance(
    String userId,
    String currency,
    double balance,
  ) async {
    try {
      final cacheKey = 'balance_${userId}_$currency';
      final timestampKey = '${cacheKey}_timestamp';

      await _cache.write(cacheKey, balance);
      await _cache.write(timestampKey, DateTime.now().millisecondsSinceEpoch);

      _memoryCache[cacheKey] = balance;
      _cacheTimestamps[cacheKey] = DateTime.now();

      AppLogger.log('Cached wallet balance for: $userId, $currency');
    } catch (e) {
      AppLogger.log('Error caching wallet balance: $e');
    }
  }

  /// Get cached wallet balance
  double? getCachedWalletBalance(String userId, String currency) {
    try {
      final cacheKey = 'balance_${userId}_$currency';

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _balanceCacheDuration) {
          AppLogger.log(
            'Retrieved balance from memory cache: $userId, $currency',
          );
          return _memoryCache[cacheKey] as double;
        }
      }

      // Check persistent cache
      final timestampKey = '${cacheKey}_timestamp';
      final cachedBalance = _cache.read(cacheKey);
      final timestamp = _cache.read(timestampKey);

      if (cachedBalance != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < _balanceCacheDuration) {
          final balance = cachedBalance as double;

          // Update memory cache
          _memoryCache[cacheKey] = balance;
          _cacheTimestamps[cacheKey] = cacheTime;

          AppLogger.log(
            'Retrieved balance from persistent cache: $userId, $currency',
          );
          return balance;
        }
      }
    } catch (e) {
      AppLogger.log('Error retrieving cached balance: $e');
    }
    return null;
  }

  /// Cache transactions with pagination support
  Future<void> cacheTransactions(
    String userId,
    List<Map<String, dynamic>> transactions, {
    int page = 0,
  }) async {
    try {
      final cacheKey = 'transactions_${userId}_page_$page';
      final timestampKey = '${cacheKey}_timestamp';

      await _cache.write(cacheKey, jsonEncode(transactions));
      await _cache.write(timestampKey, DateTime.now().millisecondsSinceEpoch);

      _memoryCache[cacheKey] = transactions;
      _cacheTimestamps[cacheKey] = DateTime.now();

      AppLogger.log('Cached transactions for: $userId, page: $page');
    } catch (e) {
      AppLogger.log('Error caching transactions: $e');
    }
  }

  /// Get cached transactions
  List<Map<String, dynamic>>? getCachedTransactions(
    String userId, {
    int page = 0,
  }) {
    try {
      final cacheKey = 'transactions_${userId}_page_$page';

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _transactionCacheDuration) {
          AppLogger.log(
            'Retrieved transactions from memory cache: $userId, page: $page',
          );
          return List<Map<String, dynamic>>.from(_memoryCache[cacheKey]);
        }
      }

      // Check persistent cache
      final timestampKey = '${cacheKey}_timestamp';
      final cachedData = _cache.read(cacheKey);
      final timestamp = _cache.read(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < _transactionCacheDuration) {
          final transactions = List<Map<String, dynamic>>.from(
            jsonDecode(cachedData),
          );

          // Update memory cache
          _memoryCache[cacheKey] = transactions;
          _cacheTimestamps[cacheKey] = cacheTime;

          AppLogger.log(
            'Retrieved transactions from persistent cache: $userId, page: $page',
          );
          return transactions;
        }
      }
    } catch (e) {
      AppLogger.log('Error retrieving cached transactions: $e');
    }
    return null;
  }

  /// Cache subscription status
  Future<void> cacheSubscriptionStatus(
    String userId,
    Map<String, dynamic> subscriptionData,
  ) async {
    try {
      final cacheKey = 'subscription_$userId';
      final timestampKey = '${cacheKey}_timestamp';

      // Convert Firestore Timestamp objects to serializable format
      final serializableData = _convertTimestampsToSerializable(
        subscriptionData,
      );

      await _cache.write(cacheKey, jsonEncode(serializableData));
      await _cache.write(timestampKey, DateTime.now().millisecondsSinceEpoch);

      _memoryCache[cacheKey] = serializableData;
      _cacheTimestamps[cacheKey] = DateTime.now();

      AppLogger.log('Cached subscription status for: $userId');
    } catch (e) {
      AppLogger.log('Error caching subscription status: $e');
    }
  }

  /// Convert Firestore Timestamp objects to serializable format
  Map<String, dynamic> _convertTimestampsToSerializable(
    Map<String, dynamic> data,
  ) {
    final result = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        result[key] = null;
      } else if (value.runtimeType.toString().contains('Timestamp')) {
        // Convert Firestore Timestamp to ISO string
        try {
          final timestamp = value as dynamic;
          final dateTime = timestamp.toDate() as DateTime;
          result[key] = dateTime.toIso8601String();
        } catch (e) {
          AppLogger.log('Error converting timestamp for key $key: $e');
          result[key] = value.toString();
        }
      } else if (value is Map<String, dynamic>) {
        // Recursively convert nested maps
        result[key] = _convertTimestampsToSerializable(value);
      } else if (value is List) {
        // Convert lists that might contain timestamps
        result[key] =
            value.map((item) {
              if (item is Map<String, dynamic>) {
                return _convertTimestampsToSerializable(item);
              } else if (item?.runtimeType.toString().contains('Timestamp') ==
                  true) {
                try {
                  final timestamp = item as dynamic;
                  final dateTime = timestamp.toDate() as DateTime;
                  return dateTime.toIso8601String();
                } catch (e) {
                  AppLogger.log('Error converting timestamp in list: $e');
                  return item.toString();
                }
              }
              return item;
            }).toList();
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  /// Get cached subscription status
  Map<String, dynamic>? getCachedSubscriptionStatus(String userId) {
    try {
      final cacheKey = 'subscription_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _subscriptionCacheDuration) {
          AppLogger.log('Retrieved subscription from memory cache: $userId');
          return _memoryCache[cacheKey] as Map<String, dynamic>;
        }
      }

      // Check persistent cache
      final timestampKey = '${cacheKey}_timestamp';
      final cachedData = _cache.read(cacheKey);
      final timestamp = _cache.read(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < _subscriptionCacheDuration) {
          final subscriptionData =
              jsonDecode(cachedData) as Map<String, dynamic>;

          // Update memory cache
          _memoryCache[cacheKey] = subscriptionData;
          _cacheTimestamps[cacheKey] = cacheTime;

          AppLogger.log(
            'Retrieved subscription from persistent cache: $userId',
          );
          return subscriptionData;
        }
      }
    } catch (e) {
      AppLogger.log('Error retrieving cached subscription: $e');
    }
    return null;
  }

  /// Invalidate specific cache
  Future<void> invalidateCache(String cacheKey) async {
    try {
      await _cache.remove(cacheKey);
      await _cache.remove('${cacheKey}_timestamp');
      _memoryCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      AppLogger.log('Invalidated cache: $cacheKey');
    } catch (e) {
      AppLogger.log('Error invalidating cache: $e');
    }
  }

  /// Invalidate user-related caches
  Future<void> invalidateUserCaches(String userId) async {
    final keysToRemove = <String>[];

    // Find all cache keys related to this user
    for (final key in _memoryCache.keys) {
      if (key.contains(userId)) {
        keysToRemove.add(key);
      }
    }

    // Remove from memory cache
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    // Remove from persistent cache
    await _cache.remove('user_$userId');
    await _cache.remove('user_${userId}_timestamp');
    await _cache.remove('subscription_$userId');
    await _cache.remove('subscription_${userId}_timestamp');

    // Remove balance caches
    final allKeys = _cache.getKeys();
    for (final key in allKeys) {
      if (key.toString().startsWith('balance_$userId') ||
          key.toString().startsWith('transactions_$userId')) {
        await _cache.remove(key);
      }
    }

    AppLogger.log('Invalidated all caches for user: $userId');
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      await _cache.erase();
      _memoryCache.clear();
      _cacheTimestamps.clear();
      AppLogger.log('Cleared all caches');
    } catch (e) {
      AppLogger.log('Error clearing all caches: $e');
    }
  }

  /// Cache money requests
  Future<void> cacheRequests(
    String userEmail,
    List<Map<String, dynamic>> requests,
  ) async {
    try {
      final cacheKey = 'requests_$userEmail';
      final timestampKey = '${cacheKey}_timestamp';

      await _cache.write(cacheKey, jsonEncode(requests));
      await _cache.write(timestampKey, DateTime.now().millisecondsSinceEpoch);

      _memoryCache[cacheKey] = requests;
      _cacheTimestamps[cacheKey] = DateTime.now();

      AppLogger.log('Cached requests for: $userEmail');
    } catch (e) {
      AppLogger.log('Error caching requests: $e');
    }
  }

  /// Get cached money requests
  List<Map<String, dynamic>>? getCachedRequests(String userEmail) {
    try {
      final cacheKey = 'requests_$userEmail';

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _transactionCacheDuration) {
          AppLogger.log('Retrieved requests from memory cache: $userEmail');
          return List<Map<String, dynamic>>.from(_memoryCache[cacheKey]);
        }
      }

      // Check persistent cache
      final timestampKey = '${cacheKey}_timestamp';
      final cachedData = _cache.read(cacheKey);
      final timestamp = _cache.read(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < _transactionCacheDuration) {
          final requests = List<Map<String, dynamic>>.from(
            jsonDecode(cachedData),
          );

          // Update memory cache
          _memoryCache[cacheKey] = requests;
          _cacheTimestamps[cacheKey] = cacheTime;

          AppLogger.log('Retrieved requests from persistent cache: $userEmail');
          return requests;
        }
      }
    } catch (e) {
      AppLogger.log('Error retrieving cached requests: $e');
    }
    return null;
  }

  /// Cache active subscription status
  Future<void> cacheActiveSubscriptionStatus(
    String userId,
    bool hasActiveSubscription,
  ) async {
    try {
      final cacheKey = 'active_subscription_$userId';
      final timestampKey = '${cacheKey}_timestamp';

      await _cache.write(cacheKey, hasActiveSubscription);
      await _cache.write(timestampKey, DateTime.now().millisecondsSinceEpoch);

      _memoryCache[cacheKey] = hasActiveSubscription;
      _cacheTimestamps[cacheKey] = DateTime.now();

      AppLogger.log('Cached active subscription status for: $userId');
    } catch (e) {
      AppLogger.log('Error caching active subscription status: $e');
    }
  }

  /// Get cached active subscription status
  bool? getCachedActiveSubscriptionStatus(String userId) {
    try {
      final cacheKey = 'active_subscription_$userId';

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey) &&
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _subscriptionCacheDuration) {
          AppLogger.log(
            'Retrieved active subscription status from memory cache: $userId',
          );
          return _memoryCache[cacheKey] as bool;
        }
      }

      // Check persistent cache
      final timestampKey = '${cacheKey}_timestamp';
      final cachedData = _cache.read(cacheKey);
      final timestamp = _cache.read(timestampKey);

      if (cachedData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) < _subscriptionCacheDuration) {
          final hasActiveSubscription = cachedData as bool;

          // Update memory cache
          _memoryCache[cacheKey] = hasActiveSubscription;
          _cacheTimestamps[cacheKey] = cacheTime;

          AppLogger.log(
            'Retrieved active subscription status from persistent cache: $userId',
          );
          return hasActiveSubscription;
        }
      }
    } catch (e) {
      AppLogger.log('Error retrieving cached active subscription status: $e');
    }
    return null;
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCache_size': _memoryCache.length,
      'persistentCache_keys': _cache.getKeys().length,
      'cache_timestamps': _cacheTimestamps.length,
    };
  }
}
