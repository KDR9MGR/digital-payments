import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/error_debug_helper.dart';
import '../../services/subscription_error_handler.dart';

class ErrorDebugScreen extends StatefulWidget {
  @override
  _ErrorDebugScreenState createState() => _ErrorDebugScreenState();
}

class _ErrorDebugScreenState extends State<ErrorDebugScreen> {
  Map<String, dynamic> errorStats = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadErrorStats();
  }

  void _loadErrorStats() {
    setState(() {
      errorStats = ErrorDebugHelper.getErrorStats();
    });
  }

  void _clearAllErrors() async {
    setState(() {
      isLoading = true;
    });

    try {
      ErrorDebugHelper.clearAllErrors();
      
      // Show success message
      Get.snackbar(
        'Success',
        'All error counts have been reset',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
      
      // Reload stats
      _loadErrorStats();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to clear errors: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Error Debug Console'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Error State Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 20),
            
            // Clear Errors Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _clearAllErrors,
                icon: isLoading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.clear_all),
                label: Text(isLoading ? 'Clearing...' : 'Clear All Error Counts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Refresh Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadErrorStats,
                icon: Icon(Icons.refresh),
                label: Text('Refresh Statistics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // Error Statistics
            Text(
              'Current Error Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 15),
            
            Expanded(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow('Total Errors', errorStats['totalErrors']?.toString() ?? '0'),
                      _buildStatRow('Network Errors', errorStats['networkErrors']?.toString() ?? '0'),
                      _buildStatRow('Payment Errors', errorStats['paymentErrors']?.toString() ?? '0'),
                      _buildStatRow('Last Error Time', errorStats['lastErrorTime'] ?? 'None'),
                      _buildStatRow('Recent Errors Count', ((errorStats['recentErrors'] as List?) ?? []).length.toString()),
                      
                      SizedBox(height: 20),
                      
                      // Recent Errors List
                      Text(
                        'Recent Errors:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 10),
                      
                      Expanded(
                        child: _buildRecentErrorsList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label + ':',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value == '0' || value == 'None' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentErrorsList() {
    final recentErrors = (errorStats['recentErrors'] as List?) ?? [];
    
    if (recentErrors.isEmpty) {
      return Center(
        child: Text(
          'No recent errors',
          style: TextStyle(
            color: Colors.green,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: recentErrors.length,
      itemBuilder: (context, index) {
        final error = recentErrors[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 20,
            ),
            title: Text(
              error['type'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error['message'] ?? 'No message',
                  style: TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  error['timestamp'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}