import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:smartvest/core/services/health_service.dart';

const String notificationChannelId = 'smartvest_foreground_service';
const int notificationId = 888;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'SmartVest Background Service',
    description: 'This channel is used for monitoring health data.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'SmartVest Service',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Ensure Firebase is initialized in this isolate
  await Firebase.initializeApp();

  final HealthService healthService = HealthService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool hasSentHighHRNotification = false;
  bool hasSentLowSpo2Notification = false;

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 10));

    // --- Anomaly Checks ---
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Don't check for anomalies if no user is logged in
      return;
    }

    try {
      final hrPoints = await healthService.getHealthData(startTime, now, HealthDataType.HEART_RATE);
      if (hrPoints.isNotEmpty) {
        hrPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latestValue = (hrPoints.first.value as NumericHealthValue).numericValue.toDouble();
        const highThreshold = 50.0;

        if (latestValue > highThreshold && !hasSentHighHRNotification) {
          final notificationData = {
            'title': 'High Heart Rate',
            'details': 'Latest reading: ${latestValue.toStringAsFixed(0)} BPM.',
            'timestamp': FieldValue.serverTimestamp(),
          };
          _saveNotificationToFirestore(currentUser.uid, notificationData);
          _showAnomalyNotification(
            id: 3,
            title: notificationData['title'].toString(),
            body: 'Your heart rate is ${latestValue.toStringAsFixed(0)} BPM.',
          );
          hasSentHighHRNotification = true;
        } else if (latestValue <= highThreshold) {
          hasSentHighHRNotification = false;
        }
      }
    } catch (e) { print("Background Service Error (HR): $e"); }

    try {
      final spo2Points = await healthService.getHealthData(startTime, now, HealthDataType.BLOOD_OXYGEN);
      if (spo2Points.isNotEmpty) {
        spo2Points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latestValue = (spo2Points.first.value as NumericHealthValue).numericValue.toDouble();
        const lowThreshold = 99.0;

        if (latestValue < lowThreshold && !hasSentLowSpo2Notification) {
          final notificationData = {
            'title': 'Low SpO2',
            'details': 'Latest reading: ${latestValue.toStringAsFixed(1)}%.',
            'timestamp': FieldValue.serverTimestamp(),
          };
          _saveNotificationToFirestore(currentUser.uid, notificationData);
          _showAnomalyNotification(
            id: 4,
            title: notificationData['title'].toString(),
            body: 'Your SpO2 is ${latestValue.toStringAsFixed(1)}%.',
          );
          hasSentLowSpo2Notification = true;
        } else if (latestValue >= lowThreshold) {
          hasSentLowSpo2Notification = false;
        }
      }
    } catch (e) { print("Background Service Error (SpO2): $e"); }

    flutterLocalNotificationsPlugin.show(
      notificationId,
      'SmartVest is Active',
      'Monitoring health data. Last check: ${DateFormat.jm().format(now)}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'SmartVest Background Service',
          icon: '@drawable/ic_bg_service_small',
          ongoing: true,
        ),
      ),
    );
  });
}

// NEW: Saves notification data to Firestore
void _saveNotificationToFirestore(String userId, Map<String, dynamic> notificationData) {
  FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add(notificationData);
}

void _showAnomalyNotification({required int id, required String title, required String body}) {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'smartvest_alerts',
        'SmartVest Alerts',
        channelDescription: 'Notifications for health anomalies.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/notification_icon',
      ),
    ),
  );
}