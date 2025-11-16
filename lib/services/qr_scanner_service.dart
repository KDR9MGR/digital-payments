import 'package:flutter/material.dart';

// Platform-specific imports
import 'qr_scanner_mobile.dart' if (dart.library.html) 'qr_scanner_web.dart';

abstract class QRScannerService {
  static QRScannerService create() {
    return createQRScannerService();
  }

  Widget buildQRView({
    required GlobalKey qrKey,
    required Function(dynamic) onQRViewCreated,
    required List<BarcodeFormat> allowedBarCodeTypes,
  });

  void dispose();
}

// Common barcode format enum for cross-platform compatibility
enum BarcodeFormat {
  qrcode,
  code128,
  code39,
  ean13,
  ean8,
  dataMatrix,
  pdf417,
}