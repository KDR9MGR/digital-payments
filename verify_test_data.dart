// Simple verification script without Flutter dependencies
import 'dart:io';
import 'dart:convert';

void main() {
  print('=== Verifying Test Purchase Data ===');

  // Check if GetStorage directory exists
  final homeDir = Platform.environment['HOME'];
  final storageDir = Directory('$homeDir/.local/share/get_storage');

  print('Storage directory exists: ${storageDir.existsSync()}');

  if (storageDir.existsSync()) {
    final files = storageDir.listSync();
    print(
      'Storage files: ${files.map((f) => f.path.split('/').last).toList()}',
    );

    // Look for storage files
    for (final file in files) {
      if (file is File && file.path.endsWith('.gs')) {
        print('\nReading storage file: ${file.path.split('/').last}');
        try {
          final content = file.readAsStringSync();
          final data = jsonDecode(content);

          print('Storage contents:');
          data.forEach((key, value) {
            print('  $key: $value');
          });
        } catch (e) {
          print('Error reading file: $e');
        }
      }
    }
  } else {
    print('GetStorage directory not found. Storage may not be initialized.');
  }
}
