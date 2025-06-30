import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

// Define channel IDs as constants to avoid typos
const String highImportanceChannelId = 'smartvest_alerts_high';
const String highImportanceChannelName = 'ErgoTrack Health Alerts';
const String highImportanceChannelDesc = 'Notifications for critical health alerts from the Smart Vest.';

const String lowImportanceChannelId = 'smartvest_service';
const String lowImportanceChannelName = 'ErgoTrack Service';
const String lowImportanceChannelDesc = 'Notification to keep the background service active.';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Create the high-importance channel
    const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
      highImportanceChannelId,
      highImportanceChannelName,
      description: highImportanceChannelDesc,
      importance: Importance.max, // Use max importance for pop-ups
      enableVibration: true,
      playSound: true,
    );

    // Create the low-importance channel for the foreground service
    const AndroidNotificationChannel lowImportanceChannel =
    AndroidNotificationChannel(
      lowImportanceChannelId,
      lowImportanceChannelName,
      description: lowImportanceChannelDesc,
      importance: Importance.low, // Low importance to be non-intrusive
    );

    // Get the plugin instance and create the channels
    final plugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await plugin?.createNotificationChannel(highImportanceChannel);
    await plugin?.createNotificationChannel(lowImportanceChannel);

    // Initialization settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@drawable/notification_icon');

    // Initialization settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(initializationSettings);
  }

  // Method to request notification permissions on Android 13+
  Future<void> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        // This will ask for permission on Android 13+
        await plugin.requestNotificationsPermission();
      }
    }
  }

  // Method to show a high-priority alert (the pop-up)
  Future<void> showHighPriorityAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Define a custom vibration pattern:
    // [delay, vibrate, pause, vibrate, pause, vibrate...]
    // This pattern is: wait 0ms, vibrate 500ms, pause 500ms, vibrate 500ms
    final Int64List vibrationPattern = Int64List(4);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 500;
    vibrationPattern[2] = 500;
    vibrationPattern[3] = 500;

    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      highImportanceChannelId, // Use the high-importance channel ID
      highImportanceChannelName,
      channelDescription: highImportanceChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Health Alert',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Show as full screen on lock screen
      category: AndroidNotificationCategory.alarm, // Treat as alarm
    );

    const DarwinNotificationDetails iosNotificationDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical, // Critical level for iOS
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Method specifically for the persistent foreground service notification
  Future<void> showForegroundServiceNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      lowImportanceChannelId, // Use the low-importance channel ID
      lowImportanceChannelName,
      channelDescription: lowImportanceChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Make it persistent
      autoCancel: false,
      showWhen: false,
      enableVibration: false,
      playSound: false,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }

  // Method to show a regular notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      highImportanceChannelId,
      highImportanceChannelName,
      channelDescription: highImportanceChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosNotificationDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
