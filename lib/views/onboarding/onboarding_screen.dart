import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stripe_api_service.dart';
import 'package:get/get.dart';
import '../../routes/routes.dart';

class OnboardingScreen extends StatefulWidget {
  final String baseUrl;
  const OnboardingScreen({super.key, required this.baseUrl});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  String statusText = '';
  String accountId = '';
  String uid = '';
  late final StripeApiService api;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    api = StripeApiService(widget.baseUrl);
    final u = FirebaseAuth.instance.currentUser;
    uid = u?.uid ?? '';
    _loadUser();
  }

  Future<void> _loadUser() async {
    final data = await api.loadUserStripeIds(uid);
    setState(() {
      accountId = data['stripe_account_id'] ?? '';
    });
  }

  Future<void> _ensure() async {
    final res = await api.ensureOnboarding();
    setState(() {
      accountId = (res['stripe_account_id'] ?? '') as String;
      statusText = 'ready';
    });
    if (accountId.isNotEmpty) {
      await _link();
    }
  }

  Future<void> _link() async {
    final url = await api.createAccountLink(accountId);
    if (url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _poll() async {
    final res = await api.getAccountStatus(accountId, uid);
    final s = (res['status'] ?? {}) as Map<String, dynamic>;
    final ce = s['charges_enabled'] == true;
    final pe = s['payouts_enabled'] == true;
    setState(() {
      statusText = ce && pe ? 'enabled' : 'pending';
    });
    if (statusText == 'enabled') {
      Get.offAllNamed(Routes.sendMoneySimpleScreen);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && accountId.isNotEmpty) {
      _poll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Payments Onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Account: $accountId'),
            Text('Status: $statusText'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _ensure, child: const Text('Start Onboarding')),
            ElevatedButton(onPressed: accountId.isEmpty ? null : _link, child: const Text('Continue KYC')),
            ElevatedButton(onPressed: accountId.isEmpty ? null : _poll, child: const Text('Refresh Status')),
          ],
        ),
      ),
    );
  }
}