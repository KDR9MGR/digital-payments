class BankAccountModel {
  final String id;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String routingNumber;
  final String accountType;
  final bool isDefault;
  final DateTime createdAt;

  BankAccountModel({
    required this.id,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.routingNumber,
    required this.accountType,
    this.isDefault = false,
    required this.createdAt,
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
    );
  }

  // Get masked account number for display
  String get maskedAccountNumber {
    if (accountNumber.length >= 4) {
      return '**** **** ${accountNumber.substring(accountNumber.length - 4)}';
    }
    return accountNumber;
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
    );
  }
} 