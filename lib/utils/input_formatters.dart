import 'package:flutter/services.dart';

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Remove any non-digit characters
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 4 digits (MMYY)
    final limitedDigits = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;
    
    String formattedText = '';
    
    if (limitedDigits.length >= 2) {
      // Add first two digits (month)
      formattedText = limitedDigits.substring(0, 2);
      
      // Add slash after month
      formattedText += '/';
      
      // Add remaining digits (year)
      if (limitedDigits.length > 2) {
        formattedText += limitedDigits.substring(2);
      }
    } else {
      formattedText = limitedDigits;
    }
    
    // Calculate cursor position
    int selectionIndex = formattedText.length;
    
    // If user is deleting and cursor is after the slash, move it before
    if (oldValue.text.length > newValue.text.length && 
        newValue.selection.baseOffset == 3 && 
        formattedText.length >= 3) {
      selectionIndex = 2;
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // Remove any non-digit characters
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 16 digits
    final limitedDigits = digitsOnly.length > 16 ? digitsOnly.substring(0, 16) : digitsOnly;
    
    String formattedText = '';
    
    // Add spaces every 4 digits
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formattedText += ' ';
      }
      formattedText += limitedDigits[i];
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}