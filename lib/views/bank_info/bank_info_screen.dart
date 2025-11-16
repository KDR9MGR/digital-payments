import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:xpay/controller/bank_accounts_controller.dart';
import 'package:xpay/data/bank_account_model.dart';
import 'package:xpay/utils/custom_color.dart';
import 'package:xpay/utils/custom_style.dart';
import 'package:xpay/utils/dimensions.dart';
import 'package:xpay/utils/strings.dart';
import 'package:xpay/widgets/primary_appbar.dart';

class BankInfoScreen extends StatefulWidget {
  const BankInfoScreen({super.key});

  @override
  State<BankInfoScreen> createState() => _BankInfoScreenState();
}

class _BankInfoScreenState extends State<BankInfoScreen> {
  StreamSubscription<LinkSuccess>? _streamSuccess;
  StreamSubscription<LinkEvent>? _streamEvent;
  StreamSubscription<LinkExit>? _streamExit;

  @override
  void initState() {
    super.initState();
    _setupPlaidStreams();
  }

  @override
  void dispose() {
    _streamSuccess?.cancel();
    _streamEvent?.cancel();
    _streamExit?.cancel();
    super.dispose();
  }

  void _setupPlaidStreams() {
    final bankAccountsController = Get.put(BankAccountsController());
    
    _streamSuccess = PlaidLink.onSuccess.listen((LinkSuccess success) {
      _handlePlaidSuccess(success.publicToken, success.metadata, bankAccountsController);
    });

    _streamEvent = PlaidLink.onEvent.listen((LinkEvent event) {
      print('Plaid Link Event: ${event.name}');
    });

    _streamExit = PlaidLink.onExit.listen((LinkExit exit) {
      if (exit.error != null) {
        Get.snackbar(
          'Connection Cancelled',
          exit.error?.description() ?? 'Bank connection was cancelled',
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bankAccountsController = Get.put(BankAccountsController());

    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.bankInfo,
          style: CustomStyle.commonTextTitleWhite,
        ),
        appBar: AppBar(),
        backgroundColor: CustomColor.primaryColor,
        autoLeading: false,
        elevation: 0,
        appbarColor: CustomColor.primaryColor,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: Dimensions.iconSizeDefault * 1.4,
          ),
        ),
      ),
      body: Obx(() => _bodyWidget(context, bankAccountsController)),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _initiatePlaidLink(context, bankAccountsController);
        },
        backgroundColor: CustomColor.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _bodyWidget(BuildContext context, BankAccountsController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.bankAccounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 20),
            Text(
              'No Bank Accounts Saved',
              style: CustomStyle.commonTextTitleWhite.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add your first bank account to get started',
              style: CustomStyle.commonTextTitleWhite.copyWith(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                _initiatePlaidLink(context, controller);
              },
              icon: const Icon(Icons.add),
              label: const Text('Connect Bank Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColor.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await controller.loadBankAccounts();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
        itemCount: controller.bankAccounts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          final account = controller.bankAccounts[index];
          return _buildBankAccountItem(context, account, controller);
        },
      ),
    );
  }

  Widget _buildBankAccountItem(BuildContext context, BankAccountModel account, BankAccountsController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CustomColor.surfaceColor.withValues(alpha: 0.9),
            CustomColor.surfaceColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: account.isDefault 
            ? CustomColor.primaryColor 
            : Colors.white.withValues(alpha: 0.1),
          width: account.isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CustomColor.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.bankName,
                      style: CustomStyle.commonTextTitleWhite.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      account.maskedAccountNumber,
                      style: CustomStyle.commonTextTitleWhite.copyWith(
                        fontSize: 14,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              if (account.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CustomColor.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Default',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Account Holder: ${account.accountHolderName}',
            style: CustomStyle.commonTextTitleWhite.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Account Type: ${account.accountType}',
            style: CustomStyle.commonTextTitleWhite.copyWith(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                account.isVerified ? Icons.verified : 
                account.isPending ? Icons.pending : Icons.error,
                color: account.verificationStatusColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                account.verificationStatusText,
                style: CustomStyle.commonTextTitleWhite.copyWith(
                  fontSize: 12,
                  color: account.verificationStatusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!account.isDefault && account.isVerified)
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      controller.setDefaultBankAccount(account.id);
                    },
                    child: Text(
                      'Set as Default',
                      style: TextStyle(
                        color: CustomColor.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (account.isFailed)
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      controller.retryBankAccountVerification(account.id);
                    },
                    child: Text(
                      'Retry Verification',
                      style: TextStyle(
                        color: Colors.orange[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if ((!account.isDefault && account.isVerified) || account.isFailed) 
                const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _showDeleteConfirmation(context, account, controller);
                  },
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, BankAccountModel account, BankAccountsController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Text(
          'Remove Bank Account',
          style: CustomStyle.commonTextTitleWhite,
        ),
        content: Text(
          'Are you sure you want to remove this bank account?\n\n${account.bankName}\n${account.maskedAccountNumber}',
          style: CustomStyle.commonTextTitleWhite.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeBankAccount(account.id);
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  void _initiatePlaidLink(BuildContext context, BankAccountsController controller) async {
    try {
      // Show loading indicator
      Get.dialog(
        AlertDialog(
          backgroundColor: CustomColor.surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CustomColor.primaryColor),
              SizedBox(height: 16),
              Text(
                'Initializing secure bank connection...',
                style: CustomStyle.commonTextTitleWhite,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Create link token through PlaidService
      final linkToken = await controller.createLinkToken();
      
      // Close loading dialog
      Get.back();
      
      if (linkToken == null) {
        Get.snackbar(
          'Error',
          'Failed to initialize bank connection. Please try again.',
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
        return;
      }

      // Configure Plaid Link using LinkTokenConfiguration
      final configuration = LinkTokenConfiguration(
        token: linkToken,
      );

      // Create PlaidLink handler
      await PlaidLink.create(configuration: configuration);

      // Open Plaid Link (streams are already set up in initState)
      PlaidLink.open();
      
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Error',
        'Failed to start bank connection: ${e.toString()}',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  void _handlePlaidSuccess(String publicToken, dynamic metadata, BankAccountsController controller) async {
    try {
      // Show processing dialog
      Get.dialog(
        AlertDialog(
          backgroundColor: CustomColor.surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CustomColor.primaryColor),
              SizedBox(height: 16),
              Text(
                'Connecting your bank account...',
                style: CustomStyle.commonTextTitleWhite,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );

      // Convert metadata to Map for easier access
      Map<String, dynamic> metadataMap = {};
      if (metadata != null) {
        // Handle different metadata formats
        if (metadata is Map<String, dynamic>) {
          metadataMap = metadata;
        } else {
          // Try to extract properties from the metadata object
          try {
            metadataMap = {
              'institution': {
                'name': metadata.institution?.name ?? 'Unknown Bank',
                'id': metadata.institution?.id ?? '',
              },
              'account': {
                'id': metadata.accounts?.isNotEmpty == true ? metadata.accounts.first.id : '',
                'name': metadata.accounts?.isNotEmpty == true ? metadata.accounts.first.name : 'Account',
                'mask': metadata.accounts?.isNotEmpty == true ? metadata.accounts.first.mask : '****',
                'subtype': metadata.accounts?.isNotEmpty == true ? metadata.accounts.first.subtype?.name ?? 'checking' : 'checking',
              },
            };
          } catch (e) {
            print('Error parsing metadata: $e');
            metadataMap = {
              'institution': {'name': 'Unknown Bank', 'id': ''},
              'account': {'id': '', 'name': 'Account', 'mask': '****', 'subtype': 'checking'},
            };
          }
        }
      }

      // Get the first account ID
      final accountId = metadataMap['account']?['id'] ?? '';
      if (accountId.isEmpty) {
        throw Exception('No account ID found in metadata');
      }

      // Exchange public token for access token and add bank account
      final success = await controller.addBankAccountFromPlaid(
        publicToken: publicToken,
        accountId: accountId,
        metadata: metadataMap,
      );

      // Close processing dialog
      Get.back();

      if (success) {
        Get.snackbar(
          'Success',
          'Bank account connected successfully!',
          backgroundColor: Colors.green.withValues(alpha: 0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to connect bank account. Please try again.',
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      // Close processing dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Error',
        'Failed to process bank connection: ${e.toString()}',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }
}