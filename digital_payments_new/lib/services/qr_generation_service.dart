import 'dart:convert';
import '../data/bank_account_model.dart';

class QrGenerationService {
  static QrGenerationService? _instance;
  static QrGenerationService get instance => _instance ??= QrGenerationService._internal();
  
  QrGenerationService._internal();

  /// Generate QR code data from bank account information
  /// Returns a JSON string containing bank details for payment
  String generateQrData(BankAccountModel bankAccount) {
    final qrData = {
      'type': 'bank_payment',
      'version': '1.0',
      'bank_name': bankAccount.bankName,
      'account_holder': bankAccount.accountHolderName,
      'account_number': bankAccount.maskedAccountNumber,
      'routing_number': bankAccount.routingNumber,
      'account_type': bankAccount.accountType,
      'timestamp': DateTime.now().toIso8601String(),
      'app': 'XPay',
    };
    
    return json.encode(qrData);
  }

  /// Generate QR data for multiple bank accounts
  String generateMultiAccountQrData(List<BankAccountModel> bankAccounts) {
    if (bankAccounts.isEmpty) {
      throw Exception('No bank accounts available for QR generation');
    }
    
    final qrData = {
      'type': 'multi_bank_payment',
      'version': '1.0',
      'accounts': bankAccounts.map((account) => {
        'id': account.id,
        'bank_name': account.bankName,
        'account_holder': account.accountHolderName,
        'account_number': account.maskedAccountNumber,
        'routing_number': account.routingNumber,
        'account_type': account.accountType,
        'is_default': account.isDefault,
      }).toList(),
      'timestamp': DateTime.now().toIso8601String(),
      'app': 'XPay',
    };
    
    return json.encode(qrData);
  }

  /// Validate if bank account has sufficient data for QR generation
  bool canGenerateQr(BankAccountModel bankAccount) {
    return bankAccount.bankName.isNotEmpty &&
           bankAccount.accountHolderName.isNotEmpty &&
           bankAccount.accountNumber.isNotEmpty &&
           bankAccount.routingNumber.isNotEmpty;
  }

  /// Get a formatted display string for QR content preview
  String getQrDisplayText(BankAccountModel bankAccount) {
    return 'Bank: ${bankAccount.bankName}\n'
           'Account Holder: ${bankAccount.accountHolderName}\n'
           'Account: ${bankAccount.maskedAccountNumber}\n'
           'Routing: ${bankAccount.routingNumber}\n'
           'Type: ${bankAccount.accountType}';
  }
}