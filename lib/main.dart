import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/local_storage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Check session
  final hasSession = await LocalStorage().hasSession();
  final hasSeenOnboarding = await LocalStorage().hasSeenOnboarding();

  runApp(SafeTraceApp(
    initialRoute: (hasSession && hasSeenOnboarding) ? 'home' : 'onboarding',
  ));
}

class SafeTraceApp extends StatefulWidget {
  final String initialRoute;
  const SafeTraceApp({super.key, required this.initialRoute});

  @override
  State<SafeTraceApp> createState() => _SafeTraceAppState();
}

class _SafeTraceAppState extends State<SafeTraceApp> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token and save it
      final token = await messaging.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        print('FCM Token saved: ${token.substring(0, 20)}...');
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          // Show in-app notification banner
          _showInAppBanner(message);
        }
      });
    }
  }

  void _showInAppBanner(RemoteMessage message) {
    // We'll show a snackbar when app is in foreground
    final context = navigatorKey.currentContext;
    if (context != null && message.notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🔔 ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.notification!.title ?? 'SafeTrace',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      message.notification!.body ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: widget.initialRoute == 'home'
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}

// Global navigator key for showing notifications from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
