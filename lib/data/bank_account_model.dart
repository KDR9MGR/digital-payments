import 'package:flutter/material.dart';

class BankAccountModel {
  final String id;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String routingNumber;
  final String accountType;
  final bool isDefault;
  final DateTime createdAt;
  final String? accountId;
  final String verificationStatus;
  final String? verificationError;
  final DateTime? lastVerified;
  final String? plaidAccessToken;
  final String? plaidAccountId;
  final String? plaidItemId;

  BankAccountModel({
    required this.id,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.routingNumber,
    required this.accountType,
    this.isDefault = false,
    required this.createdAt,
    this.accountId,
    this.verificationStatus = 'pending',
    this.verificationError,
    this.lastVerified,
    this.plaidAccessToken,
    this.plaidAccountId,
    this.plaidItemId,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankName': bankName,
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'routingNumber': routingNumber,
      'accountType': accountType,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'accountId': accountId,
      'verificationStatus': verificationStatus,
      'verificationError': verificationError,
      'lastVerified': lastVerified?.toIso8601String(),
      'plaidAccessToken': plaidAccessToken,
      'plaidAccountId': plaidAccountId,
      'plaidItemId': plaidItemId,
    };
  }

  // Create from JSON
  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'],
      bankName: json['bankName'],
      accountHolderName: json['accountHolderName'],
      accountNumber: json['accountNumber'],
      routingNumber: json['routingNumber'],
      accountType: json['accountType'],
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      accountId: json['accountId'],
      verificationStatus: json['verificationStatus'] ?? 'pending',
      verificationError: json['verificationError'],
      lastVerified: json['lastVerified'] != null 
          ? DateTime.parse(json['lastVerified']) 
          : null,
      plaidAccessToken: json['plaidAccessToken'],
      plaidAccountId: json['plaidAccountId'],
      plaidItemId: json['plaidItemId'],
    );
  }

  // Get masked account number for display
  String get maskedAccountNumber {
    if (accountNumber.length >= 4) {
      return '**** **** ${accountNumber.substring(accountNumber.length - 4)}';
    }
    return accountNumber;
  }

  // Verification status helpers
  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';
  bool get isFailed => verificationStatus == 'failed';
  bool get isLinked => accountId != null;
  
  // Get verification status display text
  String get verificationStatusText {
    switch (verificationStatus) {
      case 'verified':
        return 'Verified';
      case 'pending':
        return 'Pending Verification';
      case 'failed':
        return 'Verification Failed';
      default:
        return 'Unknown';
    }
  }
  
  // Get verification status color
  Color get verificationStatusColor {
    switch (verificationStatus) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Copy with method for updates
  BankAccountModel copyWith({
    String? id,
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? routingNumber,
    String? accountType,
    bool? isDefault,
    DateTime? createdAt,
    String? accountId,
    String? verificationStatus,
    String? verificationError,
    DateTime? lastVerified,
    String? plaidAccessToken,
    String? plaidAccountId,
    String? plaidItemId,
  }) {
    return BankAccountModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      routingNumber: routingNumber ?? this.routingNumber,
      accountType: accountType ?? this.accountType,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      accountId: accountId ?? this.accountId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationError: verificationError ?? this.verificationError,
      lastVerified: lastVerified ?? this.lastVerified,
      plaidAccessToken: plaidAccessToken ?? this.plaidAccessToken,
      plaidAccountId: plaidAccountId ?? this.plaidAccountId,
      plaidItemId: plaidItemId ?? this.plaidItemId,
    );
  }
}