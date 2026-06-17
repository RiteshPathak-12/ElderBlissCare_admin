import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channel ID — must match the channel created in AndroidManifest.xml
const String kPanicAlertChannelId = 'panic_alert_channel';
const String kPanicAlertChannelName = 'Emergency Panic Alerts';
const String kPanicAlertChannelDesc =
    'High-priority channel for emergency panic alert notifications';

/// Global navigator key so we can navigate from background/terminated state
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Local notifications plugin instance (used for foreground display)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ─────────────────────────────────────────────────────────────────────────────
/// TOP-LEVEL background message handler
/// Must be a top-level function (not inside a class) for FCM to call it.
/// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this is called.
  debugPrint('[FCM Background] Message received: ${message.messageId}');
  debugPrint('[FCM Background] Title: ${message.notification?.title}');
  debugPrint('[FCM Background] Body:  ${message.notification?.body}');
  // Android shows the notification automatically from the FCM payload when the
  // app is in background/terminated, so no extra work is needed here.
  // If you need custom handling (e.g. local DB write), do it here.
}

/// ─────────────────────────────────────────────────────────────────────────────
/// NotificationService
/// Handles:
///   • Requesting permissions
///   • Generating & storing FCM tokens in Firestore
///   • Refreshing tokens on rotation
///   • Showing foreground notifications via flutter_local_notifications
///   • Handling notification taps (foreground, background, terminated)
/// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Android notification channel (high importance + custom sound) ──────────
  static const AndroidNotificationChannel _panicChannel =
      AndroidNotificationChannel(
    kPanicAlertChannelId,
    kPanicAlertChannelName,
    description: kPanicAlertChannelDesc,
    importance: Importance.max,
    playSound: true,
    // The sound file must be placed at:
    //   android/app/src/main/res/raw/panic_alert.mp3
    // If you don't have a custom sound yet, remove the line below and
    // Android will use the default notification sound.
    sound: RawResourceAndroidNotificationSound('panic_alert'),
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFFF0000),
  );

  // ── Initialise everything ──────────────────────────────────────────────────
  Future<void> initialize() async {
    // 1. Request permission (Android 13+ / iOS)
    await _requestPermission();

    // 2. Create the Android notification channel
    await _createNotificationChannel();

    // 3. Initialise flutter_local_notifications
    await _initLocalNotifications();

    // 4. Register FCM token for the current admin
    await _registerToken();

    // 5. Listen for token refreshes
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // 6. Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 7. Notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 8. Notification tap when app was terminated
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    debugPrint('[NotificationService] Initialised successfully.');
  }

  // ── Permission ─────────────────────────────────────────────────────────────
  Future<void> _requestPermission() async {
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // iOS critical alerts bypass silent mode
      provisional: false,
      sound: true,
    );
    debugPrint(
        '[NotificationService] Permission status: ${settings.authorizationStatus}');
  }

  // ── Android channel ────────────────────────────────────────────────────────
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_panicChannel);
    debugPrint('[NotificationService] Android channel created.');
  }

  // ── Local notifications init ───────────────────────────────────────────────
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  // ── FCM token registration ─────────────────────────────────────────────────
  Future<void> _registerToken() async {
    try {
      final String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('[NotificationService] Token registration error: $e');
    }
  }

  /// Saves (or updates) the FCM token in Firestore under:
  ///   admin_fcm_tokens/{uid}
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[NotificationService] No authenticated user — skipping token save.');
        return;
      }

      await _db.collection('admin_fcm_tokens').doc(user.uid).set({
        'token': token,
        'uid': user.uid,
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      }, SetOptions(merge: true));

      debugPrint('[NotificationService] Token saved for uid: ${user.uid}');
    } catch (e) {
      debugPrint('[NotificationService] Error saving token: $e');
    }
  }

  /// Call this on logout to remove the token so the device stops receiving
  /// notifications after sign-out.
  Future<void> removeToken() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _db.collection('admin_fcm_tokens').doc(user.uid).delete();
      await _fcm.deleteToken();
      debugPrint('[NotificationService] Token removed for uid: ${user.uid}');
    } catch (e) {
      debugPrint('[NotificationService] Error removing token: $e');
    }
  }

  // ── Foreground message handler ─────────────────────────────────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Message: ${message.notification?.title}');

    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    // Show a local notification so the admin sees it even while the app is open
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _panicChannel.id,
          _panicChannel.name,
          channelDescription: _panicChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('panic_alert'),
          enableVibration: true,
          color: const Color(0xFFFF0000),
          icon: '@mipmap/ic_launcher',
          // Full-screen intent for locked screen
          fullScreenIntent: true,
        ),
      ),
      // Pass data so the tap handler can navigate correctly
      payload: 'panic_alert',
    );
  }

  // ── Notification tap handlers ──────────────────────────────────────────────

  /// Called when user taps a local notification (foreground)
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == 'panic_alert') {
      _navigateToAlertsScreen();
    }
  }

  /// Called when user taps an FCM notification (background / terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM Tap] Navigating to Alerts screen.');
    _navigateToAlertsScreen();
  }

  /// Navigate to the Alerts tab (index 1) in AdminHomeScreen
  void _navigateToAlertsScreen() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/alerts',
      (route) => route.isFirst,
    );
  }
}
