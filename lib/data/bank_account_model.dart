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
  final String? moovAccountId;
  final String verificationStatus;
  final String? verificationError;
  final DateTime? lastVerified;

  BankAccountModel({
    required this.id,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.routingNumber,
    required this.accountType,
    this.isDefault = false,
    required this.createdAt,
    this.moovAccountId,
    this.verificationStatus = 'pending',
    this.verificationError,
    this.lastVerified,
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
      'moovAccountId': moovAccountId,
      'verificationStatus': verificationStatus,
      'verificationError': verificationError,
      'lastVerified': lastVerified?.toIso8601String(),
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
      moovAccountId: json['moovAccountId'],
      verificationStatus: json['verificationStatus'] ?? 'pending',
      verificationError: json['verificationError'],
      lastVerified: json['lastVerified'] != null 
          ? DateTime.parse(json['lastVerified']) 
          : null,
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
  bool get isLinkedToMoov => moovAccountId != null;
  
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
    String? moovAccountId,
    String? verificationStatus,
    String? verificationError,
    DateTime? lastVerified,
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
      moovAccountId: moovAccountId ?? this.moovAccountId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationError: verificationError ?? this.verificationError,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }
}