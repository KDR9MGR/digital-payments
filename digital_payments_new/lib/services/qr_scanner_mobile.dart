import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart' as qr_plus;
import 'qr_scanner_service.dart';

class MobileQRScannerService extends QRScannerService {
  qr_plus.QRViewController? _controller;

  @override
  Widget buildQRView({
    required GlobalKey qrKey,
    required Function(dynamic) onQRViewCreated,
    required List<BarcodeFormat> allowedBarCodeTypes,
  }) {
    return qr_plus.QRView(
      key: qrKey,
      onQRViewCreated: (qr_plus.QRViewController controller) {
        _controller = controller;
        onQRViewCreated(controller);
      },
      overlay: qr_plus.QrScannerOverlayShape(
        borderColor: Colors.red,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: 300,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
  }
}

// Factory function for conditional import
QRScannerService createQRScannerService() => MobileQRScannerService();