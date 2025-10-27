import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import '../utils/custom_color.dart';
import '../services/firebase_query_optimizer.dart';
import '../data/user_model.dart';
import '../utils/app_logger.dart';

class UserSearchWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(Map<String, dynamic>?) onUserSelected;
  final String hintText;
  final bool showRecentContacts;
  final VoidCallback? onScanQR;

  const UserSearchWidget({
    super.key,
    required this.controller,
    required this.onUserSelected,
    this.hintText = 'Enter email or phone number',
    this.showRecentContacts = true,
    this.onScanQR,
  });

  @override
  State<UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends State<UserSearchWidget> {
  final FirebaseQueryOptimizer _queryOptimizer = FirebaseQueryOptimizer();
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> recentContacts = <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;
  final RxBool showDropdown = false.obs;
  final Rx<Map<String, dynamic>?> selectedUser = Rx<Map<String, dynamic>?>(null);
  
  @override
  void initState() {
    super.initState();
    _loadRecentContacts();
    widget.controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    final query = widget.controller.text.trim();
    if (query.isEmpty) {
      searchResults.clear();
      showDropdown.value = false;
      selectedUser.value = null;
      widget.onUserSelected(null);
      return;
    }

    if (query.length >= 3) {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      isSearching.value = true;
      showDropdown.value = true;
      
      AppLogger.log('Searching for users with query: $query');
      
      final results = await _queryOptimizer.searchUsers(
        query,
        limit: 10,
        searchFields: ['email', 'phone'],
      );
      
      searchResults.value = results;
      AppLogger.log('Found ${results.length} users');
      
    } catch (e) {
      AppLogger.log('Error searching users: $e');
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> _loadRecentContacts() async {
    if (!widget.showRecentContacts) return;
    
    try {
      // Load recent contacts from local storage or Firebase
      // For now, we'll use a simple implementation
      // In a real app, you'd load from SharedPreferences or Firebase
      recentContacts.value = [];
    } catch (e) {
      AppLogger.log('Error loading recent contacts: $e');
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    selectedUser.value = user;
    widget.controller.text = user['email'] ?? user['phone'] ?? '';
    showDropdown.value = false;
    widget.onUserSelected(user);
    
    // Add to recent contacts
    _addToRecentContacts(user);
  }

  void _addToRecentContacts(Map<String, dynamic> user) {
    // Remove if already exists
    recentContacts.removeWhere((contact) => contact['id'] == user['id']);
    // Add to beginning
    recentContacts.insert(0, user);
    // Keep only last 5 contacts
    if (recentContacts.length > 5) {
      recentContacts.removeRange(5, recentContacts.length);
    }
  }

  Widget _buildUserTile(Map<String, dynamic> user, {bool isRecent = false}) {
    final name = _getUserDisplayName(user);
    final email = user['email'] ?? user['email_address'] ?? '';
    final phone = user['phone'] ?? user['mobile'] ?? '';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: CustomColor.primaryColor.withValues(alpha: 0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: CustomColor.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty)
              Text(
                email,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            if (phone.isNotEmpty)
              Text(
                phone,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: isRecent
            ? Icon(
                Ionicons.time_outline,
                color: Colors.white.withValues(alpha: 0.5),
                size: 16,
              )
            : Icon(
                Ionicons.person_add_outline,
                color: CustomColor.primaryColor,
                size: 20,
              ),
        onTap: () => _selectUser(user),
      ),
    );
  }

  String _getUserDisplayName(Map<String, dynamic> user) {
    final firstName = user['firstName'] ?? user['first_name'] ?? '';
    final lastName = user['lastName'] ?? user['last_name'] ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    } else {
      final email = user['email'] ?? user['email_address'] ?? '';
      if (email.isNotEmpty) {
        return email.split('@').first;
      }
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextFormField(
            controller: widget.controller,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
              prefixIcon: Obx(() => isSearching.value
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            CustomColor.primaryColor,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      Ionicons.search,
                      color: Colors.white.withValues(alpha: 0.6),
                    )),
              suffixIcon: widget.onScanQR != null
                  ? IconButton(
                      onPressed: widget.onScanQR,
                      icon: Icon(
                        Ionicons.qr_code_outline,
                        color: CustomColor.primaryColor,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            onTap: () {
              if (widget.controller.text.isEmpty && recentContacts.isNotEmpty) {
                showDropdown.value = true;
              }
            },
          ),
        ),

        // Search Results Dropdown
        Obx(() {
          if (!showDropdown.value) return const SizedBox.shrink();

          final hasSearchResults = searchResults.isNotEmpty;
          final hasRecentContacts = recentContacts.isNotEmpty && widget.controller.text.isEmpty;

          if (!hasSearchResults && !hasRecentContacts) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                widget.controller.text.isEmpty
                    ? 'Start typing to search for users'
                    : 'No users found',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recent Contacts Section
                  if (hasRecentContacts) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Recent Contacts',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...recentContacts.map((contact) => _buildUserTile(contact, isRecent: true)),
                    if (hasSearchResults) const Divider(color: Colors.white24),
                  ],

                  // Search Results Section
                  if (hasSearchResults) ...[
                    if (hasRecentContacts)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'Search Results',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ...searchResults.map((user) => _buildUserTile(user)),
                  ],
                ],
              ),
            ),
          );
        }),

        // Selected User Confirmation
        Obx(() {
          if (selectedUser.value == null) return const SizedBox.shrink();

          final user = selectedUser.value!;
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CustomColor.successColor.withValues(alpha: 0.2),
                  CustomColor.successColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CustomColor.successColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Ionicons.checkmark_circle,
                  color: CustomColor.successColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recipient Selected',
                        style: TextStyle(
                          color: CustomColor.successColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getUserDisplayName(user),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    selectedUser.value = null;
                    widget.controller.clear();
                    widget.onUserSelected(null);
                    showDropdown.value = false;
                  },
                  icon: Icon(
                    Ionicons.close,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}