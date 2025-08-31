import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:digital_payments_fixed/controller/bank_accounts_controller.dart';
import 'package:digital_payments_fixed/data/bank_account_model.dart';
import 'package:digital_payments_fixed/utils/custom_color.dart';
import 'package:digital_payments_fixed/utils/custom_style.dart';
import 'package:digital_payments_fixed/utils/dimensions.dart';
import 'package:digital_payments_fixed/utils/strings.dart';
import 'package:digital_payments_fixed/widgets/primary_appbar.dart';

class BankInfoScreen extends StatelessWidget {
  const BankInfoScreen({super.key});

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
          _showAddBankAccountDialog(context, bankAccountsController);
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
                _showAddBankAccountDialog(context, controller);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Bank Account'),
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
          const SizedBox(height: 16),
          Row(
            children: [
              if (!account.isDefault)
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
              if (!account.isDefault) const SizedBox(width: 8),
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

  void _showAddBankAccountDialog(BuildContext context, BankAccountsController controller) {
    final formKey = GlobalKey<FormState>();
    final bankNameController = TextEditingController();
    final accountHolderController = TextEditingController();
    final accountNumberController = TextEditingController();
    final routingNumberController = TextEditingController();
    String selectedAccountType = 'Checking';

    Get.dialog(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Text(
          'Add Bank Account',
          style: CustomStyle.commonTextTitleWhite,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: bankNameController,
                    style: CustomStyle.commonTextTitleWhite,
                    decoration: InputDecoration(
                      labelText: 'Bank Name',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter bank name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: accountHolderController,
                    style: CustomStyle.commonTextTitleWhite,
                    decoration: InputDecoration(
                      labelText: 'Account Holder Name',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter account holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: accountNumberController,
                    style: CustomStyle.commonTextTitleWhite,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Account Number',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter account number';
                      }
                      if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                        return 'Account number should contain only digits';
                      }
                      if (value.trim().length < 8 || value.trim().length > 17) {
                        return 'Account number should be 8-17 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: routingNumberController,
                    style: CustomStyle.commonTextTitleWhite,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Routing Number',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter routing number';
                      }
                      if (!RegExp(r'^\d{9}$').hasMatch(value.trim())) {
                        return 'Routing number should be exactly 9 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAccountType,
                    style: CustomStyle.commonTextTitleWhite,
                    dropdownColor: CustomColor.surfaceColor,
                    decoration: InputDecoration(
                      labelText: 'Account Type',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: CustomColor.primaryColor),
                      ),
                    ),
                    items: ['Checking', 'Savings'].map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedAccountType = value!;
                    },
                  ),
                ],
              ),
            ),
          ),
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
          Obx(() => TextButton(
            onPressed: controller.isLoading ? null : () async {
              if (formKey.currentState!.validate()) {
                final success = await controller.addBankAccount(
                  bankName: bankNameController.text,
                  accountHolderName: accountHolderController.text,
                  accountNumber: accountNumberController.text,
                  routingNumber: routingNumberController.text,
                  accountType: selectedAccountType,
                );
                if (success) {
                  Get.back();
                }
              }
            },
            child: Text(
              controller.isLoading ? 'Adding...' : 'Add Account',
              style: TextStyle(color: CustomColor.primaryColor),
            ),
          )),
        ],
      ),
    );
  }
} 