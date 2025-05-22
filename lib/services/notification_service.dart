// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; // Required for defaultTargetPlatform
import 'package:flutter/foundation.dart';
import '../models/reminder_model.dart';

class NotificationService {
  static final NotificationService _notificationService =
  NotificationService._internal();
  factory NotificationService() => _notificationService;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String generalChannelId = 'health_tracker_reminders';
  static const String generalChannelName = 'HealthTracker Reminders';
  static const String generalChannelDesc =
      'General app reminders and notifications';

  static const String feedUpdateChannelId = 'feed_updates';
  static const String feedUpdateChannelName = 'Feed Updates';
  static const String feedUpdateChannelDesc =
      'Notifications for new feed content.';

  static const String fcmDefaultChannelId = 'fcm_default_channel';
  static const String fcmDefaultChannelName = 'General App Updates';
  static const String fcmDefaultChannelDesc =
      'Default channel for notifications from the app server.';

  Future<void> init() async {
    if (kDebugMode) {
      print(
          "==================== NotificationService: init() START ====================");
    }
    tz.initializeTimeZones();
    if (kDebugMode) {
      print("NotificationService: Timezone data initialized by 'timezone' package.");
    }

    final DateTime dartSystemNow = DateTime.now();
    if (kDebugMode) {
      print(
          "NotificationService: Dart's DateTime.now() (System Time): $dartSystemNow / Its UTC equivalent: ${dartSystemNow.toUtc()}");
    }

    try {
      const String istTimeZoneName = 'Asia/Kolkata';
      final tz.Location istLocation = tz.getLocation(istTimeZoneName);
      tz.setLocalLocation(istLocation); // Explicitly set tz.local to IST

      final tz.TZDateTime tzPackageNow = tz.TZDateTime.now(tz.local);
      if (kDebugMode) {
        print(
            "NotificationService: Explicitly set tz.local to '${tz.local.name}'. Current tz.TZDateTime.now(tz.local) is: $tzPackageNow");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "NotificationService: ERROR explicitly setting local timezone to Asia/Kolkata: $e. Trying device default then UTC fallback.");
      }
      // Fallback logic (as you had)
      try { String detectedTimeZoneName = tz.local.name; tz.setLocalLocation(tz.getLocation(detectedTimeZoneName));}
      catch(e2){ tz.setLocalLocation(tz.UTC); if (kDebugMode) print("NotificationService: Final fallback to UTC on error: $e2");}
      if (kDebugMode) print("NotificationService: After fallback, tz.local is '${tz.local.name}'");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotificationForOldIOS,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
    if (kDebugMode) {
      print("NotificationService: Plugin initialized. Callback set.");
    }
    await _createNotificationChannels();
    if (kDebugMode) {
      print(
          "==================== NotificationService: init() END ====================");
    }
  }

  Future<void> _createNotificationChannels() async {
    // ... (Identical to your provided version)
    if (kDebugMode) {
      print("NotificationService: _createNotificationChannels() called.");
    }
    const AndroidNotificationChannel generalChannel =
    AndroidNotificationChannel(
      generalChannelId,
      generalChannelName,
      description: generalChannelDesc,
      importance: Importance.max,
      playSound: true,
    );
    const AndroidNotificationChannel feedChannel = AndroidNotificationChannel(
      feedUpdateChannelId,
      feedUpdateChannelName,
      description: feedUpdateChannelDesc,
      importance: Importance.high,
      playSound: true,
    );
    const AndroidNotificationChannel fcmDefaultChan = AndroidNotificationChannel(
      fcmDefaultChannelId,
      fcmDefaultChannelName,
      description: fcmDefaultChannelDesc,
      importance: Importance.defaultImportance,
      playSound: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(generalChannel);
      await androidImplementation.createNotificationChannel(feedChannel);
      await androidImplementation.createNotificationChannel(fcmDefaultChan);
      if (kDebugMode) {
        print(
            "NotificationService: All custom notification channels created/updated.");
      }
    }
    if (kDebugMode) {
      print("NotificationService: _createNotificationChannels() completed.");
    }
  }

  static void _onDidReceiveLocalNotificationForOldIOS(
      int id, String? title, String? body, String? payload) async {
    // ... (Identical to your provided version)
    if (kDebugMode) {
      print(
          "DEPRECATED iOS < 10 fg notif: ID $id, Title: $title, Payload: $payload");
    }
  }

  static void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    // ... (Identical to your provided version)
    final String? payload = notificationResponse.payload;
    final int? id = notificationResponse.id;
    if (kDebugMode) {
      print(
          "NotificationService: Notification TAPPED! Local ID: $id, Payload: $payload, ActionID: ${notificationResponse.actionId}");
    }
  }

  Future<void> requestPermissions() async {
    // ... (Identical to your provided version, ensure kDebugMode is used correctly)
    if (kDebugMode) {
      print("NotificationService: requestPermissions() called.");
    }
    final iosImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final bool? iosResult = await iosImplementation.requestPermissions(
          alert: true, badge: true, sound: true);
      if (kDebugMode) {
        print("NotificationService: iOS permission request result: $iosResult");
      }
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      if (kDebugMode) {
        print("NotificationService: Requesting Android NOTIFICATIONS permission...");
      }
      final bool? notificationPermStatus =
      await androidImplementation.requestNotificationsPermission();
      if (kDebugMode) {
        print(
            "NotificationService: Android NOTIFICATIONS Permission Status: $notificationPermStatus (true means granted or already granted)");
      }

      if (kDebugMode) {
        print("NotificationService: Requesting Android EXACT_ALARM permission...");
      }
      final bool? alarmPermStatus =
      await androidImplementation.requestExactAlarmsPermission();
      if (kDebugMode) {
        print(
            "NotificationService: Android EXACT_ALARM Permission Status: $alarmPermStatus (true means granted or already granted)");
      }
    }
    if (kDebugMode) {
      print("NotificationService: requestPermissions() completed.");
    }
  }

  Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = generalChannelId,
  }) async {
    // ... (Identical to your provided version)
    if (kDebugMode) {
      print(
          "NotificationService: >>> Attempting to showSimpleNotification. ID: $id, Title: '$title', Channel: $channelId, Payload: $payload");
    }
    final NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == feedUpdateChannelId
            ? feedUpdateChannelName
            : (channelId == generalChannelId
            ? generalChannelName
            : fcmDefaultChannelName),
        channelDescription: channelId == feedUpdateChannelId
            ? feedUpdateChannelDesc
            : (channelId == generalChannelId
            ? generalChannelDesc
            : fcmDefaultChannelDesc),
        importance: channelId == generalChannelId
            ? Importance.max
            : Importance.high,
        priority: channelId == generalChannelId
            ? Priority.high
            : Priority.defaultPriority,
        playSound: true,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );

    try {
      await flutterLocalNotificationsPlugin.show(
          id, title, body, notificationDetails,
          payload: payload);
      if (kDebugMode) {
        print(
            "NotificationService: >>> flutterLocalNotificationsPlugin.show() SUCCEEDED for ID: $id, Title: '$title'");
      }
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "NotificationService: >>> flutterLocalNotificationsPlugin.show() FAILED for ID: $id, Title: '$title'. Error: $e");
        print("StackTrace: $s");
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time,
      {ReminderFrequency frequency = ReminderFrequency.daily,
        List<int>? specificDays}) {
    // Use Dart's DateTime.now() to get current year, month, day from the system.
    final DateTime systemNow = DateTime.now();
    // Use tz.local (which we've set to IST) for the timezone context.
    final tz.TZDateTime tzNow = tz.TZDateTime.now(tz.local);

    if (kDebugMode) {
      print(
          "-------------------- _nextInstanceOfTime START --------------------");
      print(
          "NotificationService._nextInstanceOfTime: tz.local.name: '${tz.local.name}', tz.local location object: ${tz.local}");
      print(
          "NotificationService._nextInstanceOfTime: tz.TZDateTime.now(tz.local) IS (SHOULD BE IST): $tzNow");
      print(
          "NotificationService._nextInstanceOfTime: Dart's DateTime.now() IS (SYSTEM TIME): $systemNow (UTC: ${systemNow.toUtc()})");
      print(
          "NotificationService._nextInstanceOfTime: INPUT TimeOfDay: $time, Frequency: $frequency, SpecificDays: $specificDays");
    }

    // **** MODIFICATION: Construct initial TZDateTime using systemNow's date parts but with tz.local context ****
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, // Use IST context
        systemNow.year,   // Use year from system
        systemNow.month,  // Use month from system
        systemNow.day,    // Use day from system
        time.hour, time.minute);
    // **** END MODIFICATION ****

    if (kDebugMode) {
      print(
          "NotificationService._nextInstanceOfTime: Initial proposal for scheduledDate (using system's Y/M/D in tz.local context): $scheduledDate");
    }

    if (frequency == ReminderFrequency.once) {
      if (scheduledDate.isBefore(tzNow)) { // Compare with tzNow
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        if (kDebugMode) {
          print(
              "NotificationService._nextInstanceOfTime (Once): Initial was past, advanced to: $scheduledDate");
        }
      }
      if (kDebugMode) {
        print(
            "-------------------- _nextInstanceOfTime END (ONCE) --------------------");
      }
      return scheduledDate;
    }

    int safetyCounter = 0;
    while (safetyCounter < 730) {
      bool dayIsValid = true;

      if (scheduledDate.isBefore(tzNow)) { // Compare with tzNow
        if (kDebugMode) {
          print(
              "NotificationService._nextInstanceOfTime (Loop ${safetyCounter + 1}): Current proposal $scheduledDate is before NOW $tzNow. Advancing day.");
        }
        // Advance from its current date, maintaining time, in tz.local context
        scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year,
            scheduledDate.month, scheduledDate.day, time.hour, time.minute)
            .add(const Duration(days: 1));
        safetyCounter++;
        if (kDebugMode) {
          print(
              "NotificationService._nextInstanceOfTime (Loop $safetyCounter): Advanced to $scheduledDate. Continuing evaluation.");
        }
        continue;
      }

      if (frequency == ReminderFrequency.specificDays) {
        // ... (rest of dayIsValid logic identical to your version)
        if (specificDays != null && specificDays.isNotEmpty) {
          if (!specificDays.contains(scheduledDate.weekday)) {
            dayIsValid = false;
          }
        } else {
          dayIsValid = false;
        }
      } else if (frequency == ReminderFrequency.weekdays &&
          (scheduledDate.weekday == DateTime.saturday ||
              scheduledDate.weekday == DateTime.sunday)) {
        dayIsValid = false;
      } else if (frequency == ReminderFrequency.weekends &&
          !(scheduledDate.weekday == DateTime.saturday ||
              scheduledDate.weekday == DateTime.sunday)) {
        dayIsValid = false;
      }


      if (dayIsValid) {
        if (kDebugMode) {
          print(
              "NotificationService._nextInstanceOfTime (Loop ${safetyCounter + 1}): Day ${scheduledDate.weekday} is VALID for frequency. Returning: $scheduledDate");
          print(
              "-------------------- _nextInstanceOfTime END (LOOP SUCCESS) --------------------");
        }
        return scheduledDate;
      }

      if (kDebugMode) {
        print(
            "NotificationService._nextInstanceOfTime (Loop ${safetyCounter + 1}): Day ${scheduledDate.weekday} was invalid. Advancing from $scheduledDate.");
      }
      scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year,
          scheduledDate.month, scheduledDate.day, time.hour, time.minute)
          .add(const Duration(days: 1));
      safetyCounter++;
    }

    if (kDebugMode) {
      print(
          "NotificationService._nextInstanceOfTime: Fallback triggered after $safetyCounter iterations.");
    }
    // Fallback uses systemNow's date parts
    tz.TZDateTime fallbackScheduledDate = tz.TZDateTime(
        tz.local, systemNow.year, systemNow.month, systemNow.day, time.hour, time.minute);
    if (fallbackScheduledDate.isBefore(tzNow)) { // Compare with tzNow
      fallbackScheduledDate = fallbackScheduledDate.add(const Duration(days: 1));
    }
    if (kDebugMode) {
      print(
          "NotificationService._nextInstanceOfTime: Using fallback scheduled date: $fallbackScheduledDate");
      print(
          "-------------------- _nextInstanceOfTime END (FALLBACK) --------------------");
    }
    return fallbackScheduledDate;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    // ... (Identical to your provided version, but ensure it calls the modified _nextInstanceOfTime)
    if (kDebugMode) {
      print(
          "==================== SCHEDULE REMINDER START for ${reminder.id} ====================");
      print(
          "NotificationService.scheduleReminder INPUT: ID=${reminder.id}, Title='${reminder.title}', Time=${reminder.time}, Freq=${reminder.frequency}, Enabled=${reminder.isEnabled}, Days=${reminder.specificDays}");
      print( // Add this to see what tz.local is AT THE POINT OF SCHEDULING
          "NotificationService.scheduleReminder: Current tz.local.name: '${tz.local.name}', tz.TZDateTime.now(tz.local): ${tz.TZDateTime.now(tz.local)}");
    }

    if (!reminder.isEnabled) {
      if (kDebugMode) {
        print(
            "NotificationService.scheduleReminder: Reminder ${reminder.id} is disabled. Cancelling if exists and returning.");
      }
      await cancelNotificationByStringId(reminder.id);
      if (kDebugMode) {
        print(
            "==================== SCHEDULE REMINDER END for ${reminder.id} (DISABLED) ====================");
      }
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        bool canSchedule = true;
        try {
          canSchedule = await androidImplementation.canScheduleExactAlarms() ?? true;
        } catch (e) {
          if (kDebugMode) print("NotificationService.scheduleReminder: Error checking canScheduleExactAlarms (possibly older Android, defaulting to true): $e");
        }

        if (kDebugMode) print("NotificationService.scheduleReminder: CHECK - Can schedule exact alarms? $canSchedule");
        if (canSchedule == false) {
          if (kDebugMode) print("NotificationService.scheduleReminder: WARNING - App CANNOT schedule exact alarms. Reminder '${reminder.id}' might be inexact, heavily delayed by OS, or not fire as expected. User might need to grant 'Alarms & Reminders' permission manually in app settings -> special app access.");
        }
      }
    }

    DateTimeComponents? matchDateTimeComponents;
    tz.TZDateTime scheduledTime;

    if (kDebugMode) {
      print("NotificationService.scheduleReminder: Calling _nextInstanceOfTime...");
    }
    scheduledTime = _nextInstanceOfTime(reminder.time,
        frequency: reminder.frequency, specificDays: reminder.specificDays);
    if (kDebugMode) {
      print(
          "NotificationService.scheduleReminder: _nextInstanceOfTime for ${reminder.id} returned: $scheduledTime");
    }

    switch (reminder.frequency) {
      case ReminderFrequency.once:
        matchDateTimeComponents = null;
        break;
      case ReminderFrequency.daily:
        matchDateTimeComponents = DateTimeComponents.time;
        break;
      default:
        matchDateTimeComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
    }
    if (kDebugMode) {
      print(
          "NotificationService.scheduleReminder: matchDateTimeComponents set to: $matchDateTimeComponents");
    }

    final tz.TZDateTime nowForComparison = tz.TZDateTime.now(tz.local); // Use tz.local here
    if (scheduledTime.isBefore(nowForComparison.subtract(const Duration(seconds: 5)))) {
      if (kDebugMode) {
        print(
            "NotificationService.scheduleReminder: CRITICAL - SKIPPING schedule for ${reminder.id}. Final scheduledTime $scheduledTime is significantly before current time $nowForComparison.");
        print(
            "==================== SCHEDULE REMINDER END for ${reminder.id} (SKIPPED - PAST) ====================");
      }
      return;
    }

    final int notificationId = reminder.id.hashCode;
    if (kDebugMode) {
      print(
          "NotificationService.scheduleReminder: Final local notification ID for ${reminder.id} will be: $notificationId. Payload: ${reminder.payload ?? 'reminder_${reminder.id}'}");
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        reminder.title,
        'Reminder: ${reminder.title}',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            generalChannelId,
            generalChannelName,
            channelDescription: generalChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            ticker: 'reminder_ticker',
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: reminder.payload ?? 'reminder_${reminder.id}',
      );
      if (kDebugMode) {
        print(
            "NotificationService.scheduleReminder: >>> SUCCESSFULLY called zonedSchedule for ${reminder.id}. Local ID: $notificationId, Scheduled For: $scheduledTime, Title: ${reminder.title}");
      }
    } catch (e, s) {
      if (kDebugMode) {
        print(
            "NotificationService.scheduleReminder: >>> ERROR calling zonedSchedule for ${reminder.id}. Local ID: $notificationId: $e");
        print("StackTrace: $s");
      }
    }
    if (kDebugMode) {
      print(
          "==================== SCHEDULE REMINDER END for ${reminder.id} ====================");
    }
  }

  Future<void> scheduleWaterReminderSeries(TimeOfDay wakeTime,
      TimeOfDay sleepTime, int intervalHours, int baseNotificationIdSeed) async {
    // ... (Identical to your provided version as it calls the modified scheduleReminder)
    if (kDebugMode) {
      print(
          "==================== SCHEDULE WATER REMINDER SERIES START ====================");
      print(
          "NotificationService: scheduleWaterReminderSeries called. Wake: $wakeTime, Sleep: $sleepTime, Interval: $intervalHours hrs, BaseSeed: $baseNotificationIdSeed");
    }
    if (intervalHours <= 0) {
      if (kDebugMode) {
        print("NotificationService: Water reminder interval is <= 0, not scheduling series.");
        print(
            "==================== SCHEDULE WATER REMINDER SERIES END (INTERVAL <=0) ====================");
      }
      return;
    }
    tz.TZDateTime now = tz.TZDateTime.now(tz.local); // Use tz.local
    tz.TZDateTime currentTimeToSchedule = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, wakeTime.hour, wakeTime.minute);
    tz.TZDateTime endOfDaySleepTime = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, sleepTime.hour, sleepTime.minute);

    if (endOfDaySleepTime.isBefore(currentTimeToSchedule) ||
        endOfDaySleepTime.isAtSameMomentAs(currentTimeToSchedule)) {
      endOfDaySleepTime = endOfDaySleepTime.add(const Duration(days: 1));
    }
    if (kDebugMode) {
      print(
          "NotificationService: Water series - Effective sleep end time for today: $endOfDaySleepTime. Current 'now' (in tz.local): $now");
    }

    int count = 0;
    int scheduledCount = 0;
    while (currentTimeToSchedule.isBefore(endOfDaySleepTime)) {
      if (kDebugMode) {
        print(
            "NotificationService: Water series (Iter $count) - Checking time slot: $currentTimeToSchedule");
      }
      String reminderIdString = "default_water_${baseNotificationIdSeed + count}";
      Reminder waterInstance = Reminder(
        id: reminderIdString,
        title: '💧 Time for Water!',
        time: TimeOfDay.fromDateTime(currentTimeToSchedule),
        isEnabled: true,
        isDefault: true,
        frequency: ReminderFrequency.daily,
        payload: 'water_reminder_tap_${baseNotificationIdSeed + count}',
      );
      if (kDebugMode) {
        print(
            "NotificationService: Water series - Creating instance: ${waterInstance.id} for intended time ${waterInstance.time}");
      }
      await scheduleReminder(waterInstance);
      scheduledCount++;

      currentTimeToSchedule =
          currentTimeToSchedule.add(Duration(hours: intervalHours));
      count++;
      if (count > (24 ~/ (intervalHours > 0 ? intervalHours : 1)) + 2) {
        if (kDebugMode) {
          print(
              "NotificationService: Water reminder series safety break triggered after $count iterations.");
        }
        break;
      }
    }
    if (kDebugMode) {
      print(
          "NotificationService: scheduleWaterReminderSeries completed. $scheduledCount water reminders were processed for scheduling.");
      print(
          "==================== SCHEDULE WATER REMINDER SERIES END ====================");
    }
  }

  Future<void> cancelNotificationByStringId(String reminderIdString) async {
    // ... (Identical to your provided version)
    final int notificationId = reminderIdString.hashCode;
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    if (kDebugMode) {
      print(
          "NotificationService: Attempted to cancel notification for string ID '$reminderIdString' (Local Int ID: $notificationId)");
    }
  }

  Future<void> cancelAllNotifications() async {
    // ... (Identical to your provided version)
    await flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) {
      print("NotificationService: Cancelled ALL notifications.");
    }
  }
}