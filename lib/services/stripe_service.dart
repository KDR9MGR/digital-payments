import '../utils/app_logger.dart';
import 'api_service.dart';

/// Service for handling Stripe Connect account operations
class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  final ApiService _apiService = ApiService();

  /// Create a Stripe Connect account for a user during registration
  /// This calls the backend API which handles the actual Stripe Connect account creation
  Future<StripeConnectResult> createConnectAccount({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String accountType, // 'individual' or 'company'
  }) async {
    try {
      AppLogger.log('Creating Stripe Connect account for user: $userId');
      
      // The backend registration endpoint already handles Stripe Connect account creation
      // This method is for future use when we need to create accounts separately
      // For now, we'll use the existing API endpoints
      
      final response = await _apiService.getStripeConnectAccount(userId);
      
      if (response.isSuccess && response.data != null) {
        final accountData = response.data!;
        AppLogger.log('Stripe Connect account retrieved successfully: ${accountData['id']}');
        
        return StripeConnectResult.success(
          accountId: accountData['id'] ?? '',
          customerId: accountData['customer_id'] ?? '',
          accountStatus: accountData['account_status'] ?? 'pending_verification',
        );
      } else {
        AppLogger.log('Failed to retrieve Stripe Connect account: ${response.error}');
        return StripeConnectResult.error(response.error ?? 'Failed to create Stripe Connect account');
      }
    } catch (e) {
      AppLogger.log('Error creating Stripe Connect account: $e');
      return StripeConnectResult.error('Failed to create Stripe Connect account: $e');
    }
  }

  /// Get Stripe Connect account information for a user
  Future<StripeConnectResult> getConnectAccount(String userId) async {
    try {
      AppLogger.log('Getting Stripe Connect account for user: $userId');
      
      final response = await _apiService.getStripeConnectAccount(userId);
      
      if (response.isSuccess && response.data != null) {
        final accountData = response.data!;
        AppLogger.log('Stripe Connect account retrieved: ${accountData['id']}');
        
        return StripeConnectResult.success(
          accountId: accountData['id'] ?? '',
          customerId: accountData['customer_id'] ?? '',
          accountStatus: accountData['account_status'] ?? 'pending_verification',
          chargesEnabled: accountData['charges_enabled'] ?? false,
          payoutsEnabled: accountData['payouts_enabled'] ?? false,
          detailsSubmitted: accountData['details_submitted'] ?? false,
        );
      } else {
        AppLogger.log('Failed to get Stripe Connect account: ${response.error}');
        return StripeConnectResult.error(response.error ?? 'Failed to get Stripe Connect account');
      }
    } catch (e) {
      AppLogger.log('Error getting Stripe Connect account: $e');
      return StripeConnectResult.error('Failed to get Stripe Connect account: $e');
    }
  }

  /// Update Stripe Connect account information
  Future<StripeConnectResult> updateConnectAccount({
    required String userId,
    required Map<String, dynamic> accountData,
  }) async {
    try {
      AppLogger.log('Updating Stripe Connect account for user: $userId');
      
      final response = await _apiService.updateStripeConnectAccount(userId, accountData);
      
      if (response.isSuccess && response.data != null) {
        final updatedData = response.data!;
        AppLogger.log('Stripe Connect account updated: ${updatedData['id']}');
        
        return StripeConnectResult.success(
          accountId: updatedData['id'] ?? '',
          customerId: updatedData['customer_id'] ?? '',
          accountStatus: updatedData['account_status'] ?? 'pending_verification',
          chargesEnabled: updatedData['charges_enabled'] ?? false,
          payoutsEnabled: updatedData['payouts_enabled'] ?? false,
          detailsSubmitted: updatedData['details_submitted'] ?? false,
        );
      } else {
        AppLogger.log('Failed to update Stripe Connect account: ${response.error}');
        return StripeConnectResult.error(response.error ?? 'Failed to update Stripe Connect account');
      }
    } catch (e) {
      AppLogger.log('Error updating Stripe Connect account: $e');
      return StripeConnectResult.error('Failed to update Stripe Connect account: $e');
    }
  }

  /// Create an account link for Stripe Connect onboarding
  Future<StripeAccountLinkResult> createAccountLink({
    required String userId,
    required String refreshUrl,
    required String returnUrl,
  }) async {
    try {
      AppLogger.log('Creating Stripe account link for user: $userId');
      
      final response = await _apiService.createStripeAccountLink(userId);
      
      if (response.isSuccess && response.data != null) {
        final linkData = response.data!;
        final accountLinkUrl = linkData['account_link_url'] ?? '';
        
        AppLogger.log('Stripe account link created successfully');
        
        return StripeAccountLinkResult.success(accountLinkUrl);
      } else {
        AppLogger.log('Failed to create Stripe account link: ${response.error}');
        return StripeAccountLinkResult.error(response.error ?? 'Failed to create Stripe account link');
      }
    } catch (e) {
      AppLogger.log('Error creating Stripe account link: $e');
      return StripeAccountLinkResult.error('Failed to create account link: $e');
    }
  }

  /// Delete Stripe Connect account
  Future<StripeConnectResult> deleteConnectAccount(String userId) async {
    try {
      AppLogger.log('Deleting Stripe Connect account for user: $userId');
      
      final response = await _apiService.deleteStripeConnectAccount(userId);
      
      if (response.isSuccess) {
        AppLogger.log('Stripe Connect account deleted successfully');
        return StripeConnectResult.success(
          accountId: '',
          customerId: '',
          accountStatus: 'deleted',
        );
      } else {
        AppLogger.log('Failed to delete Stripe Connect account: ${response.error}');
        return StripeConnectResult.error(response.error ?? 'Failed to delete Stripe Connect account');
      }
    } catch (e) {
      AppLogger.log('Error deleting Stripe Connect account: $e');
      return StripeConnectResult.error('Failed to delete Stripe Connect account: $e');
    }
  }
}

/// Result class for Stripe Connect operations
class StripeConnectResult {
  final bool isSuccess;
  final String? error;
  final String accountId;
  final String customerId;
  final String accountStatus;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;

  StripeConnectResult._({
    required this.isSuccess,
    this.error,
    required this.accountId,
    required this.customerId,
    required this.accountStatus,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
  });

  factory StripeConnectResult.success({
    required String accountId,
    required String customerId,
    required String accountStatus,
    bool chargesEnabled = false,
    bool payoutsEnabled = false,
    bool detailsSubmitted = false,
  }) {
    return StripeConnectResult._(
      isSuccess: true,
      accountId: accountId,
      customerId: customerId,
      accountStatus: accountStatus,
      chargesEnabled: chargesEnabled,
      payoutsEnabled: payoutsEnabled,
      detailsSubmitted: detailsSubmitted,
    );
  }

  factory StripeConnectResult.error(String error) {
    return StripeConnectResult._(
      isSuccess: false,
      error: error,
      accountId: '',
      customerId: '',
      accountStatus: 'error',
    );
  }
}

/// Result class for Stripe account link operations
class StripeAccountLinkResult {
  final bool isSuccess;
  final String? error;
  final String accountLinkUrl;

  StripeAccountLinkResult._({
    required this.isSuccess,
    this.error,
    required this.accountLinkUrl,
  });

  factory StripeAccountLinkResult.success(String accountLinkUrl) {
    return StripeAccountLinkResult._(
      isSuccess: true,
      accountLinkUrl: accountLinkUrl,
    );
  }

  factory StripeAccountLinkResult.error(String error) {
    return StripeAccountLinkResult._(
      isSuccess: false,
      error: error,
      accountLinkUrl: '',
    );
  }
}