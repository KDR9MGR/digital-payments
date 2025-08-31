import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:digital_payments_fixed/controller/cards_controller.dart';
import 'package:digital_payments_fixed/data/card_model.dart';
import 'package:digital_payments_fixed/routes/routes.dart';
import 'package:digital_payments_fixed/utils/custom_color.dart';
import 'package:digital_payments_fixed/utils/custom_style.dart';
import 'package:digital_payments_fixed/utils/dimensions.dart';
import 'package:digital_payments_fixed/utils/strings.dart';
import 'package:digital_payments_fixed/widgets/primary_appbar.dart';

class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cardsController = Get.put(CardsController());

    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          Strings.myCards,
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
      body: Obx(() => _bodyWidget(context, cardsController)),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.toNamed(Routes.addNewCardScreen);
        },
        backgroundColor: CustomColor.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _bodyWidget(BuildContext context, CardsController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 20),
            Text(
              'No Cards Saved',
              style: CustomStyle.commonTextTitleWhite.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add your first card to get started',
              style: CustomStyle.commonTextTitleWhite.copyWith(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Get.toNamed(Routes.addNewCardScreen);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Card'),
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
        await controller.loadCards();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(Dimensions.defaultPaddingSize),
        itemCount: controller.cards.length,
        separatorBuilder: (context, index) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          final card = controller.cards[index];
          return _buildCardItem(context, card, controller);
        },
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, CardModel card, CardsController controller) {
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
          color: card.isDefault 
            ? CustomColor.primaryColor 
            : Colors.white.withValues(alpha: 0.1),
          width: card.isDefault ? 2 : 1,
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
                  color: _getCardColor(card.cardType),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCardIcon(card.cardType),
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
                      card.cardType,
                      style: CustomStyle.commonTextTitleWhite.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      card.maskedCardNumber,
                      style: CustomStyle.commonTextTitleWhite.copyWith(
                        fontSize: 14,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              if (card.isDefault)
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
            card.cardHolderName,
            style: CustomStyle.commonTextTitleWhite.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expires: ${card.expiryDate}',
            style: CustomStyle.commonTextTitleWhite.copyWith(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!card.isDefault)
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      controller.setDefaultCard(card.id);
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
              if (!card.isDefault) const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _showDeleteConfirmation(context, card, controller);
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

  void _showDeleteConfirmation(BuildContext context, CardModel card, CardsController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: CustomColor.surfaceColor,
        title: Text(
          'Remove Card',
          style: CustomStyle.commonTextTitleWhite,
        ),
        content: Text(
          'Are you sure you want to remove this card?\n\n${card.maskedCardNumber}',
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
              controller.removeCard(card.id);
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

  Color _getCardColor(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return Colors.blue[700]!;
      case 'mastercard':
        return Colors.red[700]!;
      case 'american express':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
      case 'mastercard':
      case 'american express':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
} 