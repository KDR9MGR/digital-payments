import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:xpay/services/auth_service.dart';

import '../../utils/custom_color.dart';
import '../../utils/custom_style.dart';
import '../../utils/dimensions.dart';
import '../../widgets/primary_appbar.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Sent', 'Received', 'Pending', 'Failed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColor.screenBGColor,
      appBar: PrimaryAppBar(
        appbarSize: Dimensions.defaultAppBarHeight,
        toolbarHeight: Dimensions.defaultAppBarHeight,
        title: Text(
          'Transaction History',
          style: CustomStyle.commonTextTitleWhite.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        appBar: AppBar(),
        backgroundColor: CustomColor.appBarColor,
        autoLeading: false,
        elevation: 0,
        appbarColor: CustomColor.appBarColor,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(),
                _buildTransactionStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: Icon(Ionicons.search, color: Colors.white.withValues(alpha: 0.7)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    selectedColor: CustomColor.primaryColor.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: isSelected 
                          ? CustomColor.primaryColor 
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: CustomColor.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Transactions'),
          Tab(text: 'Statistics'),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final user = _authService.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'Please log in to view transactions',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getTransactionsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: CustomColor.primaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Ionicons.alert_circle, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading transactions',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data?.docs ?? [];
        final filteredTransactions = _filterTransactions(transactions);

        if (filteredTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Ionicons.receipt_outline, color: Colors.white.withValues(alpha: 0.5), size: 64),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your transaction history will appear here',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction = filteredTransactions[index];
            return _buildTransactionCard(transaction);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(QueryDocumentSnapshot transaction) {
    final data = transaction.data() as Map<String, dynamic>;
    final amount = (data['amount'] ?? 0.0).toDouble();
    final currency = data['currency'] ?? 'USD';
    final recipientEmail = data['recipientEmail'] ?? 'Unknown';
    final senderEmail = data['senderEmail'] ?? 'Unknown';
    final status = data['status'] ?? 'pending';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final transactionId = data['transactionId'] ?? transaction.id;
    final type = data['type'] ?? 'sent';

    final isReceived = type == 'received';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isReceived ? Colors.green : CustomColor.primaryColor).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReceived ? Ionicons.arrow_down : Ionicons.arrow_up,
                  color: isReceived ? Colors.green : CustomColor.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived ? 'Received from' : 'Sent to',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isReceived ? senderEmail : recipientEmail,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isReceived ? '+' : '-'}$currency ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isReceived ? Colors.green : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${transactionId.length > 8 ? '${transactionId.substring(0, 8)}...' : transactionId}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDate(timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionStats() {
    final user = _authService.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'Please log in to view statistics',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getTransactionsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: CustomColor.primaryColor),
          );
        }

        final transactions = snapshot.data?.docs ?? [];
        final stats = _calculateStats(transactions);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStatCard('Total Transactions', stats['total'].toString(), Ionicons.receipt),
              const SizedBox(height: 16),
              _buildStatCard('Total Sent', '\$${stats['totalSent'].toStringAsFixed(2)}', Ionicons.arrow_up),
              const SizedBox(height: 16),
              _buildStatCard('Total Received', '\$${stats['totalReceived'].toStringAsFixed(2)}', Ionicons.arrow_down),
              const SizedBox(height: 16),
              _buildStatCard('Successful Transactions', stats['successful'].toString(), Ionicons.checkmark_circle),
              const SizedBox(height: 16),
              _buildStatCard('Pending Transactions', stats['pending'].toString(), Ionicons.time),
              const SizedBox(height: 16),
              _buildStatCard('Failed Transactions', stats['failed'].toString(), Ionicons.close_circle),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CustomColor.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: CustomColor.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getTransactionsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterTransactions(List<QueryDocumentSnapshot> transactions) {
    var filtered = transactions;

    // Filter by search term
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((transaction) {
        final data = transaction.data() as Map<String, dynamic>;
        final recipientEmail = (data['recipientEmail'] ?? '').toString().toLowerCase();
        final senderEmail = (data['senderEmail'] ?? '').toString().toLowerCase();
        final transactionId = (data['transactionId'] ?? '').toString().toLowerCase();
        
        return recipientEmail.contains(searchTerm) ||
               senderEmail.contains(searchTerm) ||
               transactionId.contains(searchTerm);
      }).toList();
    }

    // Filter by status/type
    if (_selectedFilter != 'All') {
      filtered = filtered.where((transaction) {
        final data = transaction.data() as Map<String, dynamic>;
        final status = data['status'] ?? '';
        final type = data['type'] ?? '';
        
        switch (_selectedFilter) {
          case 'Sent':
            return type == 'sent';
          case 'Received':
            return type == 'received';
          case 'Pending':
            return status == 'pending';
          case 'Failed':
            return status == 'failed';
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  Map<String, dynamic> _calculateStats(List<QueryDocumentSnapshot> transactions) {
    int total = transactions.length;
    int successful = 0;
    int pending = 0;
    int failed = 0;
    double totalSent = 0.0;
    double totalReceived = 0.0;

    for (final transaction in transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final type = data['type'] ?? '';
      final amount = (data['amount'] ?? 0.0).toDouble();

      switch (status) {
        case 'completed':
        case 'success':
          successful++;
          break;
        case 'pending':
          pending++;
          break;
        case 'failed':
        case 'error':
          failed++;
          break;
      }

      if (status == 'completed' || status == 'success') {
        if (type == 'sent') {
          totalSent += amount;
        } else if (type == 'received') {
          totalReceived += amount;
        }
      }
    }

    return {
      'total': total,
      'successful': successful,
      'pending': pending,
      'failed': failed,
      'totalSent': totalSent,
      'totalReceived': totalReceived,
    };
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return Ionicons.checkmark_circle;
      case 'pending':
        return Ionicons.time;
      case 'failed':
      case 'error':
        return Ionicons.close_circle;
      default:
        return Ionicons.help_circle;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}