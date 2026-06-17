import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'providers/settings_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/alerts/alerts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase initialisation
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("Firebase Connected ID: ${Firebase.app().options.projectId}");
  debugPrint("Connecting to Firestore Collection: panic_alerts");

  // ✅ Register the top-level background message handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const ElderBlissAdminApp(),
    ),
  );
}

class ElderBlissAdminApp extends StatelessWidget {
  const ElderBlissAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ElderBliss Admin',

          // ✅ Global navigator key for notification tap navigation
          navigatorKey: navigatorKey,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),

          // ✅ Named route for Alerts screen (used by notification tap handler)
          routes: {
            '/alerts': (context) => const AlertsScreen(),
          },

          home: const SplashScreen(),
        );
      },
    );
  }
}
