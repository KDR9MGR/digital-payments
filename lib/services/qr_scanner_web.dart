import 'package:flutter/material.dart';
import 'qr_scanner_service.dart';

class WebQRScannerService extends QRScannerService {
  @override
  Widget buildQRView({
    required GlobalKey qrKey,
    required Function(dynamic) onQRViewCreated,
    required List<BarcodeFormat> allowedBarCodeTypes,
  }) {
    // For web, we'll show a placeholder with file upload option
    return Container(
      key: qrKey,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            'QR Scanner not available on web',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // In a real implementation, you could add file upload
              // or use a web-compatible QR scanner library
              onQRViewCreated(null);
            },
            child: Text('Upload QR Image'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Nothing to dispose for web implementation
  }
}

// Factory function for conditional import
QRScannerService createQRScannerService() => WebQRScannerService();