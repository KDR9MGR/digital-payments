import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/moov_config.dart';

class MoovService {
  static final MoovService _instance = MoovService._internal();
  factory MoovService() => _instance;
  MoovService._internal();

  final String _baseUrl = MoovConfig.baseUrl;
  final String _apiKey = MoovConfig.apiKey;

  // HTTP headers for API requests
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Initialize Moov service
  static Future<void> init() async {
    try {
      // Initialize any platform-specific configurations
      print('Moov Service initialized successfully');
    } catch (e) {
      print('Error initializing Moov Service: $e');
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
      print('Test mode: Creating mock Moov account for: $email');
      await Future.delayed(Duration(milliseconds: 500)); // Simulate network delay
      return {
        'success': true,
        'accountId': 'test_account_${userId.substring(0, 8)}',
        'data': {
          'accountID': 'test_account_${userId.substring(0, 8)}',
          'status': 'active',
        },
      };
    }
    
    try {
      print('Creating Moov account for: $email');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/accounts'),
        headers: _headers,
        body: jsonEncode({
          'accountType': 'individual',
          'profile': {
            'individual': {
              'name': {
                'firstName': firstName,
                'lastName': lastName,
              },
              'email': email,
              'phone': {
                'number': phone ?? '',
                'countryCode': '1',
              },
            },
          },
          'termsOfService': {
            'token': 'kgT1uxoMAk7QKuyJcmQE8nqW_HjpyuXBabiXPi6T83fUQoxGpWKvqPNDfhruYEp6_JW7HjooGhBs5mAvXNPMoA',
          },
          'capabilities': ['transfers', 'send-funds', 'collect-funds'],
          'foreignId': userId,
        }),
      ).timeout(Duration(seconds: 10)); // Add timeout

      print('Moov API response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Moov account created successfully: ${data['accountID']}');
        return {
          'success': true,
          'accountId': data['accountID'],
          'data': data,
        };
      } else {
        print('Moov API error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'API Error: ${response.statusCode} - ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      print('Error creating Moov account: $e');
      String errorMessage = 'Network error';
      
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timeout - please check your internet connection';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network connection failed';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response format';
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  // Create a payment method
  Future<Map<String, dynamic>?> createPaymentMethod({
    required String accountId,
    required Map<String, dynamic> cardData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/accounts/$accountId/payment-methods'),
        headers: _headers,
        body: jsonEncode({
          'card': {
            'cardNumber': cardData['number'],
            'cardCvv': cardData['cvc'],
            'expiration': {
              'month': cardData['exp_month'].toString(),
              'year': cardData['exp_year'].toString(),
            },
            'holderName': cardData['name'],
            'billingAddress': {
              'addressLine1': cardData['address_line1'] ?? '',
              'city': cardData['address_city'] ?? '',
              'stateOrProvince': cardData['address_state'] ?? '',
              'postalCode': cardData['address_zip'] ?? '',
              'country': cardData['address_country'] ?? 'US',
            },
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'paymentMethodId': data['paymentMethodID'],
          'data': data,
        };
      } else {
        print('Error creating payment method: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Failed to create payment method: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      print('Error creating payment method: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Process subscription payment
  Future<Map<String, dynamic>?> processSubscriptionPayment({
    required String accountId,
    required String paymentMethodId,
    required double amount,
    required String currency,
    required String subscriptionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transfers'),
        headers: _headers,
        body: jsonEncode({
          'source': {
            'paymentMethodID': paymentMethodId,
          },
          'destination': {
            'account': {
              'accountID': 'your_merchant_account_id', // Your business account ID
            },
          },
          'amount': {
            'currency': currency,
            'value': (amount * 100).toInt(), // Convert to cents
          },
          'description': 'Super Payments Monthly Subscription',
          'metadata': {
            'subscriptionId': subscriptionId,
            'userId': accountId,
            'planType': 'super_payments_monthly',
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'transferId': data['transferID'],
          'status': data['status'],
          'data': data,
        };
      } else {
        print('Error processing payment: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Payment failed: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      print('Error processing subscription payment: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get account details
  Future<Map<String, dynamic>?> getAccount(String accountId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/accounts/$accountId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get account: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      print('Error getting account: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get payment methods for an account
  Future<List<Map<String, dynamic>>> getPaymentMethods(String accountId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/accounts/$accountId/payment-methods'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data ?? []);
      } else {
        print('Error getting payment methods: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting payment methods: $e');
      return [];
    }
  }

  // Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory(String accountId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/accounts/$accountId/transfers'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data ?? []);
      } else {
        print('Error getting transaction history: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(String accountId, String paymentMethodId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/accounts/$accountId/payment-methods/$paymentMethodId'),
        headers: _headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting payment method: $e');
      return false;
    }
  }

  // Webhook verification (for backend use)
  bool verifyWebhookSignature(String payload, String signature, String secret) {
    // Implement webhook signature verification
    // This would typically be done in your backend
    return true;
  }
} 