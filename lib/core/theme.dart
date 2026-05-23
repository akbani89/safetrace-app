import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary — deep trust blue
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFF3949AB);
  static const Color primaryDark = Color(0xFF0D147A);

  // Accent — safe green
  static const Color accent = Color(0xFF00897B);
  static const Color accentLight = Color(0xFF4DB6AC);

  // Alert / Action
  static const Color alert = Color(0xFFC62828);
  static const Color warning = Color(0xFFF57F17);
  static const Color success = Color(0xFF2E7D32);

  // Neutrals
  static const Color surface = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B8A);
  static const Color textHint = Color(0xFFB0BEC5);

  // Chat
  static const Color userBubble = Color(0xFF3949AB);
  static const Color counselorBubble = Color(0xFFE8EAF6);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.card,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

class AppStrings {
  static const String appName = 'SafeTrace';
  static const String tagline = 'Your story. Your control.';

  // Onboarding
  static const String onboard1Title = 'Anonymous by Default';
  static const String onboard1Body =
      'No signup required. We generate a private ID for you — no name, no email, no phone needed.';
  static const String onboard2Title = 'Your Data, Your Rules';
  static const String onboard2Body =
      'Nothing is ever shared automatically. You decide what happens with your case.';
  static const String onboard3Title = 'Safe. Structured. Supported.';
  static const String onboard3Body =
      'Log incidents, store evidence, talk to counselors, and take action — all on your terms.';
}

class AppConstants {
  static const String baseUrl = 'https://safetrace-backend.fly.dev/api/v1';
  static const String wsBaseUrl = 'wss://safetrace-backend.fly.dev/api/v1';
  static const String adidKey = 'safetrace_adid';
  static const String tokenKey = 'safetrace_token';
  static const String recoveryCodeKey = 'safetrace_recovery_code_shown';
}
