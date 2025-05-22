// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) print("==================== FCM BACKGROUND HANDLER START ====================");
  if (kDebugMode) print("_firebaseMessagingBackgroundHandler: Top level handler invoked with message ID: ${message.messageId}");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) print("_firebaseMessagingBackgroundHandler: Firebase re-initialized if needed.");

  final notificationService = NotificationService(); // Create instance
  await notificationService.init();
  if (kDebugMode) print("_firebaseMessagingBackgroundHandler: NotificationService re-initialized for this isolate.");

  if (kDebugMode) {
    print("_firebaseMessagingBackgroundHandler: Received raw data: ${message.data}");
    if (message.notification != null) print("_firebaseMessagingBackgroundHandler: Received raw notification part: ${message.notification?.title}");
  }

  final title = message.data['title'] ?? message.notification?.title ?? 'New Background Update';
  final body = message.data['body'] ?? message.notification?.body ?? 'Tap to see details.';
  int localNotificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
  String payloadType = message.data['type'] as String? ?? 'general_fcm_bg';
  String payloadString = 'fcm_tap|type:$payloadType|id:${message.messageId ?? localNotificationId}';
  if (message.data['screen'] != null) payloadString += '|screen:${message.data['screen']}';

  String targetChannelId = NotificationService.generalChannelId;
  if (payloadType == 'feed_update') {
    targetChannelId = NotificationService.feedUpdateChannelId;
  }
  if (kDebugMode) print("_firebaseMessagingBackgroundHandler: Determined channel: $targetChannelId. Payload: $payloadString");

  try {
    await notificationService.showSimpleNotification(
      id: localNotificationId,
      title: title,
      body: body,
      payload: payloadString,
      channelId: targetChannelId,
    );
    if (kDebugMode) print("_firebaseMessagingBackgroundHandler: showSimpleNotification call completed.");
  } catch (e,s) {
    if (kDebugMode) {
      print("_firebaseMessagingBackgroundHandler: ERROR showing notification: $e");
      print("StackTrace: $s");
    }
  }
  if (kDebugMode) print("==================== FCM BACKGROUND HANDLER END ====================");
}

// Global instance for main isolate
final NotificationService mainNotificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) print("Main: WidgetsFlutterBinding ensured.");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) print("Main: Firebase initialized.");

  await mainNotificationService.init(); // Use global instance
  if (kDebugMode) print("Main: NotificationService initialized in main.");

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  if (kDebugMode) print("Main: FCM background handler set.");

  await mainNotificationService.requestPermissions(); // Use global instance
  if (kDebugMode) print("Main: Permissions requested via NotificationService.");

  await _setupFCMListeners();
  if (kDebugMode) print("Main: FCM listeners set up.");

  if (kDebugMode) {
    print("Main: Scheduling a TEST notification to appear in 15 seconds...");
    Future.delayed(const Duration(seconds: 15), () { // Increased delay to ensure app is up
      print("Main: >>> Attempting to show TEST notification (after 15s)...");
      mainNotificationService.showSimpleNotification( // Use global instance
          id: 99999,
          title: "App Startup Test Notification",
          body: "If you see this, local notifications are working. (ID: 99999)",
          payload: "test_payload_startup_99999",
          channelId: NotificationService.generalChannelId
      ).then((_) {
        if (kDebugMode) print("Main: >>> TEST Notification showSimpleNotification call completed.");
      }).catchError((e,s) {
        if (kDebugMode) {
          print("Main: >>> TEST Notification FAILED: $e");
          print("StackTrace: $s");
        }
      });
    });
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
  if (kDebugMode) print("Main: runApp called. App is starting display.");
}

Future<void> _setupFCMListeners() async {
  if (kDebugMode) print("FCM Listeners: _setupFCMListeners() called.");
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true, announcement: false, badge: true, carPlay: false,
    criticalAlert: false, provisional: false, sound: true,
  );

  if (kDebugMode) print('FCM Listeners: User granted FCM permission on iOS/Web: ${settings.authorizationStatus}');

  try {
    String? token = await messaging.getToken();
    if (kDebugMode) print("FCM Listeners: Token: $token");
    // TODO: Send this token to your server.
    if (token == null && kDebugMode) {
      print("FCM Listeners: WARNING - FCM Token is null. This could be due to GMS issues or network problems.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("FCM Listeners: ERROR getting FCM token: $e");
      print("FCM Listeners: This error often indicates issues with Google Play Services setup on the emulator/device OR network connectivity during token fetch.");
    }
  }

  messaging.onTokenRefresh.listen((newToken) {
    if (kDebugMode) print("FCM Listeners: Token REFERSHED: $newToken");
    // TODO: Send this newToken to your server.
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (kDebugMode) {
      print("==================== FCM FOREGROUND MESSAGE START ====================");
      print('FCM Listeners: Foreground onMessage received: ${message.messageId}');
      print("Data: ${message.data}");
      if (message.notification != null) print("Notification part: ${message.notification?.title}");
    }

    final title = message.data['title'] ?? message.notification?.title ?? 'New Update';
    final body = message.data['body'] ?? message.notification?.body ?? 'Check the app for details.';
    int localNotificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    String payloadType = message.data['type'] as String? ?? 'general_fcm_fg';
    String payloadString = 'fcm_tap|type:$payloadType|id:${message.messageId ?? localNotificationId}';
    if (message.data['screen'] != null) payloadString += '|screen:${message.data['screen']}';

    String targetChannelId = NotificationService.generalChannelId;
    if (payloadType == 'feed_update') {
      targetChannelId = NotificationService.feedUpdateChannelId;
    }
    if (kDebugMode) print("FCM onMessage: Determined channel: $targetChannelId. Payload: $payloadString");

    mainNotificationService.showSimpleNotification(
      id: localNotificationId,
      title: title,
      body: body,
      payload: payloadString,
      channelId: targetChannelId,
    );
    if (kDebugMode) print("==================== FCM FOREGROUND MESSAGE END ====================");
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (kDebugMode) print('FCM Listeners: onMessageOpenedApp (app opened from background via tap): ${message.messageId}. Data: ${message.data}');

    int localNotificationIdShown = message.messageId?.hashCode ?? 0;
    String payloadType = message.data['type'] as String? ?? 'general_fcm_opened';
    String payloadString = message.data['payload_string_for_tap']
        ?? 'fcm_tap|type:$payloadType|id:${message.messageId ?? localNotificationIdShown}';
    if (message.data['screen'] != null && !(payloadString.contains('screen:')) ) {
      payloadString += '|screen:${message.data['screen']}';
    }
    if (kDebugMode) print('FCM onMessageOpenedApp: Constructed payload: $payloadString, Local Notif ID associated by FCM message: $localNotificationIdShown');

    NotificationService.onDidReceiveNotificationResponse(
        NotificationResponse(
          payload: payloadString,
          id: localNotificationIdShown,
          notificationResponseType: NotificationResponseType.selectedNotification,
        )
    );
  });

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    if (kDebugMode) print('FCM Listeners: getInitialMessage (app opened from terminated via tap): ${initialMessage.messageId}. Data: ${initialMessage.data}');

    int localNotificationIdShown = initialMessage.messageId?.hashCode ?? 0;
    String payloadType = initialMessage.data['type'] as String? ?? 'general_fcm_initial';
    String payloadString = initialMessage.data['payload_string_for_tap']
        ?? 'fcm_tap|type:$payloadType|id:${initialMessage.messageId ?? localNotificationIdShown}';
    if (initialMessage.data['screen'] != null && !(payloadString.contains('screen:'))) {
      payloadString += '|screen:${initialMessage.data['screen']}';
    }
    if (kDebugMode) print('FCM getInitialMessage: Constructed payload: $payloadString, Local Notif ID associated by FCM message: $localNotificationIdShown');

    NotificationService.onDidReceiveNotificationResponse(
        NotificationResponse(
          payload: payloadString,
          id: localNotificationIdShown,
          notificationResponseType: NotificationResponseType.selectedNotification,
        )
    );
  }
  if (kDebugMode) print("FCM Listeners: _setupFCMListeners() completed.");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'TrackerBuddy',
          theme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.light,
            useMaterial3: true,
            colorSchemeSeed: Colors.teal,
          ),
          darkTheme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.dark,
            useMaterial3: true,
            colorSchemeSeed: Colors.teal,
          ),
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}