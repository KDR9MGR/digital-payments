import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeApiService {
  final String baseUrl;
  StripeApiService(this.baseUrl);

  Future<String> _idToken() async {
    final u = FirebaseAuth.instance.currentUser;
    final t = await u?.getIdToken();
    return t ?? '';
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> ensureOnboarding() async {
    final token = await _idToken();
    final res = await http.post(Uri.parse('$baseUrl/stripe/ensure-onboarding'), headers: _headers(token));
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<String> createAccountLink(String accountId) async {
    final token = await _idToken();
    final res = await http.post(Uri.parse('$baseUrl/stripe/connect/account-link'), headers: _headers(token), body: json.encode({'account_id': accountId}));
    final body = json.decode(res.body) as Map<String, dynamic>;
    return (body['url'] ?? '') as String;
  }

  Future<Map<String, dynamic>> getAccountStatus(String accountId, String userId) async {
    final token = await _idToken();
    final res = await http.get(Uri.parse('$baseUrl/stripe/connect/account/$accountId/status?user_id=$userId'), headers: _headers(token));
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<String> createSetupIntent(String customerId) async {
    final token = await _idToken();
    final res = await http.post(Uri.parse('$baseUrl/stripe/setup-intent'), headers: _headers(token), body: json.encode({'customer_id': customerId}));
    final body = json.decode(res.body) as Map<String, dynamic>;
    final si = body['setup_intent'] as Map<String, dynamic>;
    return (si['client_secret'] ?? '') as String;
  }

  Future<PaymentMethod> createCardPaymentMethod() async {
    final pm = await Stripe.instance.createPaymentMethod(
      params: const PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: null,
        ),
      ),
    );
    return pm;
  }

  Future<Map<String, dynamic>> initiateP2P({required String recipientUserId, required int amountCents, String currency = 'usd', required String paymentMethodId, String? idempotencyKey}) async {
    final token = await _idToken();
    final headers = _headers(token);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await http.post(
      Uri.parse('$baseUrl/payments/p2p/initiate'),
      headers: headers,
      body: json.encode({
        'recipient_user_id': recipientUserId,
        'amount': amountCents,
        'currency': currency,
        'payment_method_id': paymentMethodId,
      }),
    );
    return json.decode(res.body) as Map<String, dynamic>;
  }

  static Future<void> initStripe(String publishableKey) async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  Future<Map<String, dynamic>> loadUserStripeIds(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return {
      'stripe_account_id': data['stripe_account_id'] ?? '',
      'stripe_customer_id': data['stripe_customer_id'] ?? '',
    };
  }
}