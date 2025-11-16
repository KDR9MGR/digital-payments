import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../services/stripe_api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendMoneyScreen extends StatefulWidget {
  final String baseUrl;
  final String publishableKey;
  const SendMoneyScreen({super.key, required this.baseUrl, required this.publishableKey});
  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final recipientController = TextEditingController();
  final amountController = TextEditingController();
  String paymentMethodId = '';
  Map<String, dynamic>? receipt;
  late final StripeApiService api;
  bool canSend = false;
  String gateStatus = '';

  @override
  void initState() {
    super.initState();
    api = StripeApiService(widget.baseUrl);
    StripeApiService.initStripe(widget.publishableKey);
  }

  Future<void> _createPaymentMethod() async {
    final pm = await api.createCardPaymentMethod();
    setState(() {
      paymentMethodId = pm.id;
    });
  }

  Future<void> _checkReady() async {
    final senderUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final recipient = recipientController.text.trim();
    if (senderUid.isEmpty || recipient.isEmpty) {
      setState(() { canSend = false; gateStatus = 'Enter recipient'; });
      return;
    }
    final fs = FirebaseFirestore.instance;
    final senderDoc = await fs.collection('users').doc(senderUid).get();
    final recipientDoc = await fs.collection('users').doc(recipient).get();
    final s = senderDoc.data() ?? {};
    final r = recipientDoc.data() ?? {};
    final senderReady = (s['charges_enabled'] == true) && (s['payouts_enabled'] == true);
    final recipientReady = (r['charges_enabled'] == true) && (r['payouts_enabled'] == true);
    setState(() {
      canSend = senderReady && recipientReady;
      gateStatus = canSend ? 'Ready' : 'Not ready';
    });
  }

  Future<void> _send() async {
    final recipient = recipientController.text.trim();
    final amt = int.tryParse(amountController.text.trim()) ?? 0;
    final res = await api.initiateP2P(recipientUserId: recipient, amountCents: amt, currency: 'usd', paymentMethodId: paymentMethodId);
    setState(() {
      receipt = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Money')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Recipient UID'),
            TextField(controller: recipientController, onChanged: (_) { _checkReady(); }),
            const SizedBox(height: 8),
            const Text('Amount (cents)'),
            TextField(controller: amountController, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Text('Gate: $gateStatus'),
            const Text('Card'),
            const CardField(),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _createPaymentMethod, child: Text(paymentMethodId.isEmpty ? 'Create Payment Method' : paymentMethodId)),
            ElevatedButton(onPressed: (paymentMethodId.isEmpty || !canSend) ? null : _send, child: const Text('Send')),
            const SizedBox(height: 12),
            if (receipt != null) Expanded(child: _ReceiptView(data: receipt!)),
          ],
        ),
      ),
    );
  }
}

class _ReceiptView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReceiptView({required this.data});
  @override
  Widget build(BuildContext context) {
    final pi = data['payment_intent'] as Map<String, dynamic>?;
    final tr = data['transfer'] as Map<String, dynamic>?;
    return ListView(
      children: [
        Text('PaymentIntent: ${pi?['id'] ?? ''}'),
        Text('PI Status: ${pi?['status'] ?? ''}'),
        Text('Transfer: ${tr?['id'] ?? ''}'),
      ],
    );
  }
}