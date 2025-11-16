import 'package:flutter/material.dart';

class CustomColor {
  // Primary gradient colors matching the screenshots
  static const Color primaryColor = Color(0xFF1E3A8A); // Deep blue (primary)
  static const Color primaryVariant = Color(0xFF3B82F6); // Lighter blue
  static const Color secondaryColor = Color(0xFF6366F1); // Purple-blue
  static const Color secondaryVariant = Color(0xFF8B5CF6); // Light purple
  
  // Specific colors for app bar and sidebar
  static const Color appBarColor = Color(0xFF0854F8); // App bar color
  static const Color sidebarColor = Color(0xFF465ACA); // Sidebar navigation color
  
  // Gradient colors for backgrounds (matching screenshots)
  static const Color gradientStart = Color(0xFF1E3A8A); // Deep blue start
  static const Color gradientMiddle = Color(0xFF3730A3); // Blue-purple middle
  static const Color gradientEnd = Color(0xFF5B21B6); // Purple end
  
  // Background colors for gradient theme
  static const Color backgroundColor = Color(0xFF0F172A); // Very dark blue
  static const Color surfaceColor = Color(0xFF001A2E); // Dark blue surface
  static const Color screenBGColor = Color(0xFF000E19); // New scaffold background color
  
  // Text colors optimized for gradient backgrounds
  static const Color primaryTextColor = Color(0xFFFFFFFF); // White text
  static const Color secondaryTextColor = Color(0xFFE2E8F0); // Light gray text
  static const Color onPrimaryTextColor = Color(0xFFFFFFFF); // White text on primary
  
  // Additional colors for the gradient theme
  static const Color errorColor = Color(0xFFEF4444); // Red for errors
  static const Color successColor = Color(0xFF10B981); // Green for success
  static const Color warningColor = Color(0xFFF59E0B); // Amber for warnings
  
  // Legacy colors (updated for gradient theme)
  static const Color splashScreenColor = Color(0xFF000E19); // Updated to match scaffold
  static const Color sliderColor = Color(0xFF3B82F6); // Blue for sliders
  
  // Material 3 specific colors for gradient theme
  static const Color outlineColor = Color(0xFF475569); // Borders
  static const Color onSurfaceVariant = Color(0xFF94A3B8); // Text on surface variant
  
  // Gradient definitions for easy use
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientMiddle, gradientEnd],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
  );
}
