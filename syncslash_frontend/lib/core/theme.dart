import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF151515);
  static const Color surface = Color(0xFF222222);
  
  static const Color mintGreen = Color(0xFFC4F2D6);
  static const Color lavender = Color(0xFFE2D4F6);
  static const Color pastelYellow = Color(0xFFFAF196);
  static const Color pastelBlue = Color(0xFFD4E5F6);
  static const Color alertRed = Color(0xFFFFB3B3);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);

  static Color getBrandColor(String serviceName) {
    switch (serviceName.toLowerCase()) {
      case 'spotify': return mintGreen;
      case 'netflix': return lavender;
      case 'apple tv': return pastelYellow;
      case 'amazon prime': return pastelBlue;
      default: return lavender;
    }
  }
}