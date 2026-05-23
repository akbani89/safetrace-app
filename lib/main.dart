import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'core/local_storage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Check if user already has a session
  final hasSession = await LocalStorage().hasSession();
  final hasSeenOnboarding = await LocalStorage().hasSeenOnboarding();

  runApp(SafeTraceApp(
    initialRoute: (hasSession && hasSeenOnboarding) ? 'home' : 'onboarding',
  ));
}

class SafeTraceApp extends StatelessWidget {
  final String initialRoute;

  const SafeTraceApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: initialRoute == 'home'
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
