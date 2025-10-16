import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Backend configuration
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      // For Android emulator, use 10.0.2.2 to reach host machine
      return 'http://10.0.2.2:8080';
    } else {
      // For iOS simulator and other platforms
      return 'http://localhost:8080';
    }
  }
  static const Duration _timeout = Duration(seconds: 30);
  
  // JWT token for authentication
  String? _authToken;
  
  // Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
    AppLogger.log('API Service: Auth token set');
  }
  
  // Clear authentication token
  void clearAuthToken() {
    _authToken = null;
    AppLogger.log('API Service: Auth token cleared');
  }
  
  // Get common headers
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // Generic HTTP request method
  Future<ApiResponse<T>> _makeRequest<T>(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      // Build URL with query parameters
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      AppLogger.log('API Request: $method ${uri.toString()}');
      if (body != null) {
        AppLogger.log('Request Body: ${jsonEncode(body)}');
      }

      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: _headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: _headers).timeout(_timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      AppLogger.log('API Response: ${response.statusCode}');
      AppLogger.log('Response Body: ${response.body}');

      return _handleResponse<T>(response);
    } on SocketException {
      AppLogger.log('API Error: No internet connection');
      return ApiResponse<T>.error('No internet connection. Please check your network.');
    } on HttpException {
      AppLogger.log('API Error: HTTP exception occurred');
      return ApiResponse<T>.error('Network error occurred. Please try again.');
    } on FormatException {
      AppLogger.log('API Error: Invalid response format');
      return ApiResponse<T>.error('Invalid response format from server.');
    } catch (e) {
      AppLogger.log('API Error: $e');
      return ApiResponse<T>.error('An unexpected error occurred: $e');
    }
  }

  // Handle HTTP response
  ApiResponse<T> _handleResponse<T>(http.Response response) {
    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<T>.success(data as T);
      } else {
        final errorMessage = data['error']?.toString() ?? data['message']?.toString() ?? 'Unknown error occurred';
        return ApiResponse<T>.error(errorMessage, statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse<T>.error('Failed to parse server response', statusCode: response.statusCode);
    }
  }

  // Health check
  Future<ApiResponse<Map<String, dynamic>>> healthCheck() async {
    return _makeRequest<Map<String, dynamic>>('GET', '/health');
  }

  // Authentication endpoints
  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    return _makeRequest<Map<String, dynamic>>('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String country,
    required String mobile,
    String accountType = 'personal',
    String? companyName,
    String? representativeFirstName,
    String? representativeLastName,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'country': country,
      'mobile': mobile,
      'accountType': accountType,
    };

    if (companyName != null) body['companyName'] = companyName;
    if (representativeFirstName != null) body['representativeFirstName'] = representativeFirstName;
    if (representativeLastName != null) body['representativeLastName'] = representativeLastName;

    return _makeRequest<Map<String, dynamic>>('POST', '/auth/register', body: body);
  }

  // Account endpoints
  Future<ApiResponse<Map<String, dynamic>>> createAccount({
    required String accountType,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
    Map<String, dynamic>? address,
    Map<String, dynamic>? business,
  }) async {
    final Map<String, dynamic> body = {
      'accountType': accountType,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
    };

    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    if (business != null) body['business'] = business;

    return _makeRequest<Map<String, dynamic>>('POST', '/accounts/', body: body);
  }

  Future<ApiResponse<Map<String, dynamic>>> getAccount(String accountId) async {
    return _makeRequest<Map<String, dynamic>>('GET', '/accounts/$accountId');
  }

  Future<ApiResponse<Map<String, dynamic>>> updateAccount(
    String accountId,
    Map<String, dynamic> updates,
  ) async {
    return _makeRequest<Map<String, dynamic>>('PATCH', '/accounts/$accountId', body: updates);
  }

  // Transfer endpoints
  Future<ApiResponse<Map<String, dynamic>>> createTransfer({
    required String sourceAccountId,
    required String destinationAccountId,
    required double amount,
    required String currency,
    String? description,
  }) async {
    return _makeRequest<Map<String, dynamic>>('POST', '/transfers/', body: {
      'sourceAccountId': sourceAccountId,
      'destinationAccountId': destinationAccountId,
      'amount': amount,
      'currency': currency,
      'description': description,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> getTransfer(String transferId) async {
    return _makeRequest<Map<String, dynamic>>('GET', '/transfers/$transferId');
  }

  Future<ApiResponse<List<dynamic>>> getTransfers() async {
    final response = await _makeRequest<Map<String, dynamic>>('GET', '/transfers/');
    if (response.isSuccess) {
      final transfers = response.data?['transfers'] as List<dynamic>? ?? [];
      return ApiResponse<List<dynamic>>.success(transfers);
    } else {
      return ApiResponse<List<dynamic>>.error(response.error!, statusCode: response.statusCode);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getTransferHistory({
    int limit = 20,
    String? currency,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };

    if (currency != null && currency.isNotEmpty) {
      queryParams['currency'] = currency;
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final endpoint = '/transfers/history${queryString.isNotEmpty ? '?$queryString' : ''}';
    
    return _makeRequest<Map<String, dynamic>>('GET', endpoint);
  }

  // KYC endpoints
  Future<ApiResponse<Map<String, dynamic>>> submitKYC(Map<String, dynamic> kycData) async {
    return _makeRequest<Map<String, dynamic>>('POST', '/kyc/', body: kycData);
  }

  Future<ApiResponse<Map<String, dynamic>>> getKYCStatus(String accountId) async {
    return _makeRequest<Map<String, dynamic>>('GET', '/kyc/$accountId');
  }

  // Payment method endpoints
  Future<ApiResponse<Map<String, dynamic>>> addPaymentMethod(Map<String, dynamic> paymentMethodData) async {
    return _makeRequest<Map<String, dynamic>>('POST', '/payment-methods/', body: paymentMethodData);
  }

  Future<ApiResponse<List<dynamic>>> getPaymentMethods() async {
    final response = await _makeRequest<Map<String, dynamic>>('GET', '/payment-methods/');
    if (response.isSuccess) {
      final paymentMethods = response.data?['paymentMethods'] as List<dynamic>? ?? [];
      return ApiResponse<List<dynamic>>.success(paymentMethods);
    } else {
      return ApiResponse<List<dynamic>>.error(response.error!, statusCode: response.statusCode);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> removePaymentMethod(String paymentMethodId) async {
    return _makeRequest<Map<String, dynamic>>('DELETE', '/payment-methods/$paymentMethodId');
  }

  // Generic request methods for custom endpoints
  Future<ApiResponse<Map<String, dynamic>>> get(String endpoint, {Map<String, String>? queryParams}) async {
    return _makeRequest<Map<String, dynamic>>('GET', endpoint, queryParams: queryParams);
  }

  Future<ApiResponse<Map<String, dynamic>>> post(String endpoint, Map<String, dynamic> body) async {
    return _makeRequest<Map<String, dynamic>>('POST', endpoint, body: body);
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(String endpoint, Map<String, dynamic> body) async {
    return _makeRequest<Map<String, dynamic>>('PATCH', endpoint, body: body);
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(String endpoint) async {
    return _makeRequest<Map<String, dynamic>>('DELETE', endpoint);
  }
}

// API Response wrapper class
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
    );
  }

  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success(data: $data)';
    } else {
      return 'ApiResponse.error(error: $error, statusCode: $statusCode)';
    }
  }
}