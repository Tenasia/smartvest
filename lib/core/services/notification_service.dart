// lib/core/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data'; // <-- IMPORT THIS for the vibration pattern

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
    final AndroidNotificationChannel highImportanceChannel =
    const AndroidNotificationChannel(
      highImportanceChannelId,
      highImportanceChannelName,
      description: highImportanceChannelDesc,
      importance: Importance.max, // Use max importance for pop-ups
      enableVibration: true,
      playSound: true,
    );

    // Create the low-importance channel for the foreground service
    final AndroidNotificationChannel lowImportanceChannel =
    const AndroidNotificationChannel(
      lowImportanceChannelId,
      lowImportanceChannelName,
      description: lowImportanceChannelDesc,
      importance: Importance.low, // Low importance to be non-intrusive
    );

    // Get the plugin instance and create the channels
    final plugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
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

  // NEW: Method to request notification permissions on Android 13+
  Future<void> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        // This will ask for permission on Android 13+
        await plugin.requestNotificationsPermission();
      }
    }
  }

  // UPDATED: Method to show a high-priority alert (the pop-up)
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

    final AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      highImportanceChannelId, // Use the high-importance channel ID
      highImportanceChannelName,
      channelDescription: highImportanceChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true, // <-- Explicitly enable vibration
      vibrationPattern: vibrationPattern, // <-- Apply the custom pattern
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      // iOS details can be added here if needed
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
  }


  // NEW: Method specifically for the persistent foreground service notification
  Future<void> showForegroundServiceNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final AndroidNotificationDetails androidNotificationDetails =
    const AndroidNotificationDetails(
      lowImportanceChannelId, // Use the low-importance channel ID
      lowImportanceChannelName,
      channelDescription: lowImportanceChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Make it persistent
      autoCancel: false,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails);
  }
}