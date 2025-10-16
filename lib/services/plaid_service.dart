import '../utils/app_logger.dart';
import '../config/plaid_config.dart';
import 'api_service.dart';

class PlaidService {
  static final PlaidService _instance = PlaidService._internal();
  factory PlaidService() => _instance;
  PlaidService._internal();

  // API service instance
  final ApiService _apiService = ApiService();

  // Rate limiting
  final Map<String, DateTime> _lastRequestTime = {};
  static const Duration _rateLimitDelay = Duration(milliseconds: 500);

  // Rate limiting tracking
  final Map<String, int> _dailyTransferCounts = {};
  final Map<String, DateTime> _lastTransferDates = {};

  // Cache for account data
  final Map<String, Map<String, dynamic>> _accountCache = {};
  final Map<String, DateTime> _accountCacheTime = {};

  // Initialize Plaid service
  static Future<void> init() async {
    try {
      AppLogger.log('Initializing Plaid service...');
      AppLogger.log('Environment: ${PlaidConfig.environmentStatus}');

      if (!PlaidConfig.isConfigured) {
        throw Exception('Plaid service is not properly configured');
      }
      
      if (PlaidConfig.isProduction && !PlaidConfig.isProductionReady) {
        throw Exception('Plaid service is not ready for production');
      }
      
      AppLogger.log('Plaid Service initialized successfully');
    } catch (e) {
      AppLogger.log('Error initializing Plaid Service: $e');
      rethrow;
    }
  }

  // Create Link Token for Plaid Link flow
  Future<Map<String, dynamic>?> createLinkToken({
    required String userId,
    String? redirectUri,
    List<String>? products,
    List<String>? countryCodes,
  }) async {
    try {
      if (PlaidConfig.testMode) {
        AppLogger.log('Test mode: Creating mock link token for user: $userId');
        return {
          'success': true,
          'linkToken': 'link-sandbox-test-token-${DateTime.now().millisecondsSinceEpoch}',
          'expiration': DateTime.now().add(Duration(hours: 4)).toIso8601String(),
        };
      }

      AppLogger.log('Creating Plaid link token via backend API for user: $userId');
      
      final response = await _apiService.post(PlaidConfig.createLinkTokenEndpoint, {
        'userId': userId,
        'redirectUri': redirectUri,
        'products': products ?? PlaidConfig.products,
        'countryCodes': countryCodes ?? PlaidConfig.countryCodes,
      });

      if (response.isSuccess) {
        AppLogger.log('Plaid link token created successfully');
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        AppLogger.log('Failed to create Plaid link token: ${response.error}');
        return {
          'success': false,
          'error': response.error ?? 'Failed to create link token',
        };
      }
    } catch (e) {
      AppLogger.log('Error creating Plaid link token: $e');
      return {
        'success': false,
        'error': 'Failed to create link token',
      };
    }
  }

  // Exchange public token for access token
  Future<Map<String, dynamic>?> exchangePublicToken({
    required String publicToken,
    required String userId,
  }) async {
    try {
      if (PlaidConfig.testMode) {
        AppLogger.log('Test mode: Exchanging public token for user: $userId');
        return {
          'success': true,
          'accessToken': 'access-sandbox-test-token-${DateTime.now().millisecondsSinceEpoch}',
          'itemId': 'item-sandbox-test-${DateTime.now().millisecondsSinceEpoch}',
        };
      }

      AppLogger.log('Exchanging Plaid public token via backend API for user: $userId');
      
      final response = await _apiService.post(PlaidConfig.exchangeTokenEndpoint, {
        'publicToken': publicToken,
        'userId': userId,
      });

      if (response.isSuccess) {
        AppLogger.log('Plaid public token exchanged successfully');
        
        // Store access token securely (placeholder for secure storage)
         if (response.data != null) {
           await _storeUserAccessToken(userId, response.data!);
         }
        
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        AppLogger.log('Failed to exchange Plaid public token: ${response.error}');
        return {
          'success': false,
          'error': response.error ?? 'Failed to exchange public token',
        };
      }
    } catch (e) {
      AppLogger.log('Error exchanging Plaid public token: $e');
      return {
        'success': false,
        'error': 'Failed to exchange public token',
      };
    }
  }

  // Get user's linked bank accounts
  Future<List<Map<String, dynamic>>> getBankAccounts(String userId) async {
    try {
      // Check cache first
      if (_isAccountCacheValid(userId)) {
        AppLogger.log('Returning cached account data for user: $userId');
        return List<Map<String, dynamic>>.from(_accountCache[userId]?['accounts'] ?? []);
      }

      if (PlaidConfig.testMode) {
        final testAccounts = [
          {
            'accountId': 'test_account_1',
            'accountName': 'Test Checking Account',
            'accountType': 'depository',
            'accountSubtype': 'checking',
            'mask': '1234',
            'institutionName': 'Test Bank',
            'status': 'verified',
            'balance': {
              'available': 1000.0,
              'current': 1200.0,
              'currency': 'USD',
            }
          },
          {
            'accountId': 'test_account_2',
            'accountName': 'Test Savings Account',
            'accountType': 'depository',
            'accountSubtype': 'savings',
            'mask': '5678',
            'institutionName': 'Test Bank',
            'status': 'verified',
            'balance': {
              'available': 5000.0,
              'current': 5000.0,
              'currency': 'USD',
            }
          }
        ];
        
        // Cache test data
        _cacheAccountData(userId, {'accounts': testAccounts});
        return testAccounts;
      }
      
      AppLogger.log('Getting bank accounts via backend API for user: $userId');
      
      final response = await _apiService.get('${PlaidConfig.getAccountsEndpoint}/$userId');

      if (response.isSuccess) {
        AppLogger.log('Bank accounts retrieved successfully');
        final data = response.data;
        if (data is Map<String, dynamic> && data['accounts'] is List) {
          final accounts = List<Map<String, dynamic>>.from(data['accounts']);
          
          // Cache the data
          _cacheAccountData(userId, data);
          
          return accounts;
        }
        return [];
      } else {
        AppLogger.log('Failed to get bank accounts: ${response.error}');
        return [];
      }
    } catch (e) {
      AppLogger.log('Error getting bank accounts via backend API: $e');
      return [];
    }
  }

  // Get account authentication data (routing/account numbers)
  Future<Map<String, dynamic>?> getAuthData(String userId, String accountId) async {
    try {
      if (PlaidConfig.testMode) {
        return {
          'success': true,
          'accountId': accountId,
          'routingNumber': '123456789',
          'accountNumber': '1234567890',
          'wireRoutingNumber': '123456789',
        };
      }

      AppLogger.log('Getting auth data via backend API for user: $userId, account: $accountId');
      
      final response = await _apiService.get('${PlaidConfig.getAuthEndpoint}/$userId/$accountId');

      if (response.isSuccess) {
        AppLogger.log('Auth data retrieved successfully');
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        AppLogger.log('Failed to get auth data: ${response.error}');
        return {
          'success': false,
          'error': response.error ?? 'Failed to get auth data',
        };
      }
    } catch (e) {
      AppLogger.log('Error getting auth data via backend API: $e');
      return {
        'success': false,
        'error': 'Failed to get auth data',
      };
    }
  }

  // Get account balance
  Future<Map<String, dynamic>?> getAccountBalance(String userId, String accountId) async {
    try {
      if (PlaidConfig.testMode) {
        return {
          'success': true,
          'balance': {
            'available': 1000.0,
            'current': 1200.0,
            'currency': 'USD',
          },
        };
      }

      AppLogger.log('Getting account balance via backend API for user: $userId, account: $accountId');
      
      final response = await _apiService.get('${PlaidConfig.getBalanceEndpoint}/$userId/$accountId');

      if (response.isSuccess) {
        AppLogger.log('Account balance retrieved successfully');
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        AppLogger.log('Failed to get account balance: ${response.error}');
        return {
          'success': false,
          'error': response.error ?? 'Failed to get account balance',
        };
      }
    } catch (e) {
      AppLogger.log('Error getting account balance via backend API: $e');
      return {
        'success': false,
        'error': 'Failed to get account balance',
      };
    }
  }

  // Create P2P transfer
  Future<Map<String, dynamic>?> createTransfer({
    required String senderUserId,
    required String recipientUserId,
    required String senderAccountId,
    required String recipientAccountId,
    required double amount,
    String? description,
  }) async {
    try {
      // Validate transfer amount
      if (amount < PlaidConfig.minTransferAmount) {
        return {
          'success': false,
          'error': 'Transfer amount must be at least \$${PlaidConfig.minTransferAmount}',
        };
      }
      
      if (amount > PlaidConfig.maxTransferAmount) {
        return {
          'success': false,
          'error': 'Transfer amount cannot exceed \$${PlaidConfig.maxTransferAmount}',
        };
      }
      
      // Check rate limiting
      if (!_checkRateLimit(senderUserId)) {
        return {
          'success': false,
          'error': 'Daily transfer limit exceeded. Maximum ${PlaidConfig.maxTransfersPerDay} transfers per day.',
        };
      }
      
      if (PlaidConfig.testMode) {
        AppLogger.log('Test mode: Creating transfer of ${amount.toStringAsFixed(2)} from $senderUserId to $recipientUserId');
        await Future.delayed(Duration(milliseconds: 300));
        _incrementTransferCount(senderUserId);
        return {
          'success': true,
          'transferId': 'test_transfer_${DateTime.now().millisecondsSinceEpoch}',
          'status': 'pending',
          'data': {
            'transferId': 'test_transfer_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'pending',
            'amount': amount,
            'description': description,
          }
        };
      }

      AppLogger.log('Creating P2P transfer via backend API');
      
      final response = await _apiService.post(PlaidConfig.createTransferEndpoint, {
        'senderUserId': senderUserId,
        'recipientUserId': recipientUserId,
        'senderAccountId': senderAccountId,
        'recipientAccountId': recipientAccountId,
        'amount': amount,
        'description': description,
      });

      if (response.isSuccess) {
        AppLogger.log('P2P transfer created successfully');
        _incrementTransferCount(senderUserId);
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        AppLogger.log('Failed to create P2P transfer: ${response.error}');
        return {
          'success': false,
          'error': response.error ?? 'Failed to create transfer',
        };
      }
    } catch (e) {
      AppLogger.log('Error creating P2P transfer via backend API: $e');
      return {
        'success': false,
        'error': 'Failed to create transfer',
      };
    }
  }

  // Get transaction history
  Future<List<Map<String, dynamic>>> getTransactions(String userId, {int? count, DateTime? startDate, DateTime? endDate}) async {
    try {
      if (PlaidConfig.testMode) {
        return [
          {
            'transactionId': 'test_tx_1',
            'accountId': 'test_account_1',
            'type': 'transfer',
            'amount': -50.0,
            'description': 'P2P Transfer to John',
            'status': 'posted',
            'date': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
            'category': ['Transfer', 'P2P'],
          },
          {
            'transactionId': 'test_tx_2',
            'accountId': 'test_account_1',
            'type': 'deposit',
            'amount': 100.0,
            'description': 'P2P Transfer from Jane',
            'status': 'posted',
            'date': DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
            'category': ['Transfer', 'P2P'],
          },
        ];
      }

      AppLogger.log('Getting transactions via backend API for user: $userId');
      
      final queryParams = <String, dynamic>{
        'count': count ?? 100,
      };
      
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      
      final response = await _apiService.get('${PlaidConfig.getTransactionsEndpoint}/$userId');

      if (response.isSuccess) {
        AppLogger.log('Transactions retrieved successfully');
        final data = response.data;
        if (data is Map<String, dynamic> && data['transactions'] is List) {
          return List<Map<String, dynamic>>.from(data['transactions']);
        }
        return [];
      } else {
        AppLogger.log('Failed to get transactions: ${response.error}');
        return [];
      }
    } catch (e) {
      AppLogger.log('Error getting transactions via backend API: $e');
      return [];
    }
  }

  // Get or create user Plaid connection
  Future<String?> getOrCreateUserConnection({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      if (PlaidConfig.testMode) {
        return 'test_user_${userId.substring(0, 8)}';
      }

      // Try to get existing user connection from secure storage
       try {
         // Placeholder for secure storage check
         // In production, this would check encrypted local storage or secure backend
         AppLogger.log('Checking for existing Plaid connection for user: $userId');
       } catch (_) {
         // fall through to create new connection
       }

      // User needs to go through Plaid Link flow
      AppLogger.log('User needs to complete Plaid Link flow: $userId');
      return null;
    } catch (e) {
      AppLogger.log('Error getting or creating user connection: $e');
      return null;
    }
  }

  // Validate user consent for data access
   Future<bool> validateUserConsent(String userId) async {
     try {
       // Placeholder for secure storage check
       // In production, this would check encrypted local storage or secure backend
       AppLogger.log('Validating user consent for: $userId');
       return true; // Placeholder - implement proper consent validation
     } catch (e) {
       AppLogger.log('Error validating user consent: $e');
       return false;
     }
   }

   // Store user consent
   Future<void> storeUserConsent(String userId) async {
     try {
       // Placeholder for secure storage
       // In production, this would store consent in encrypted local storage or secure backend
       AppLogger.log('Storing user consent for: $userId');
     } catch (e) {
       AppLogger.log('Error storing user consent: $e');
     }
   }

   // Private helper methods
   Future<void> _storeUserAccessToken(String userId, Map<String, dynamic> tokenData) async {
     try {
       // Placeholder for secure token storage
       // In production, this would store tokens in encrypted local storage or secure backend
       AppLogger.log('Storing access token for user: $userId');
     } catch (e) {
       AppLogger.log('Error storing user access token: $e');
     }
   }

  bool _checkRateLimit(String userId) {
    final today = DateTime.now();
    final lastDate = _lastTransferDates[userId];
    
    if (lastDate == null || !_isSameDay(lastDate, today)) {
      _dailyTransferCounts[userId] = 0;
      _lastTransferDates[userId] = today;
    }
    
    return (_dailyTransferCounts[userId] ?? 0) < PlaidConfig.maxTransfersPerDay;
  }

  void _incrementTransferCount(String userId) {
    _dailyTransferCounts[userId] = (_dailyTransferCounts[userId] ?? 0) + 1;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _cacheAccountData(String userId, Map<String, dynamic> data) {
    _accountCache[userId] = data;
    _accountCacheTime[userId] = DateTime.now();
  }

  bool _isAccountCacheValid(String userId) {
    final cacheTime = _accountCacheTime[userId];
    if (cacheTime == null) return false;
    
    return DateTime.now().difference(cacheTime) < PlaidConfig.accountCacheDuration;
  }

  // Clear cache for user
  void clearUserCache(String userId) {
    _accountCache.remove(userId);
    _accountCacheTime.remove(userId);
  }

  // Clear all caches
  void clearAllCaches() {
    _accountCache.clear();
    _accountCacheTime.clear();
  }
}