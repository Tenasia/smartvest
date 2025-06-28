import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:smartvest/core/services/notification_service.dart'; // Import your NotificationService

// The old constants are no longer needed here, they are in notification_service.dart
// const String notificationChannelId = 'smartvest_foreground_service';
const int notificationId = 888;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // The channel creation is now handled by NotificationService().init()
  // so we can remove it from here.

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      // Use the constant from the notification service for the channel ID
      notificationChannelId: lowImportanceChannelId,
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
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();

  final NotificationService notificationService = NotificationService();
  final HealthService healthService = HealthService(); // Re-enable the real health service

  bool hasSentHighHRNotification = false;
  bool hasSentLowSpo2Notification = false;

  // Set back to 1 minute for normal operation
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 10));

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    // --- Live Heart Rate Monitoring ---
    try {
      final hrPoints = await healthService.getHealthData(startTime, now, HealthDataType.HEART_RATE);
      if (hrPoints.isNotEmpty) {
        hrPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latestValue = (hrPoints.first.value as NumericHealthValue).numericValue.toDouble();

        // Set threshold back to a normal alert level
        const double highThreshold = 100.0;

        if (latestValue > highThreshold && !hasSentHighHRNotification) {
          final notificationData = {
            'title': 'High Heart Rate Detected',
            'details': 'A heart rate of ${latestValue.toStringAsFixed(0)} BPM was detected.',
            'timestamp': FieldValue.serverTimestamp(),
          };
          _saveNotificationToFirestore(currentUser.uid, notificationData);
          notificationService.showHighPriorityAlert(
            id: 3,
            title: notificationData['title'] as String,
            body: notificationData['details'] as String,
          );
          hasSentHighHRNotification = true;
        } else if (latestValue <= highThreshold) {
          hasSentHighHRNotification = false;
        }
      }
    } catch (e) {
      print("Background Service Error (HR): $e");
    }

    // --- Live SpO2 Monitoring ---
    try {
      final spo2Points = await healthService.getHealthData(startTime, now, HealthDataType.BLOOD_OXYGEN);
      if (spo2Points.isNotEmpty) {
        spo2Points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latestValue = (spo2Points.first.value as NumericHealthValue).numericValue.toDouble();

        // Set threshold back to a normal alert level
        const double lowThreshold = 95.0;

        if (latestValue < lowThreshold && !hasSentLowSpo2Notification) {
          final notificationData = {
            'title': 'Low Blood Oxygen Detected',
            'details': 'An SpO2 level of ${latestValue.toStringAsFixed(1)}% was detected.',
            'timestamp': FieldValue.serverTimestamp(),
          };
          _saveNotificationToFirestore(currentUser.uid, notificationData);
          notificationService.showHighPriorityAlert(
            id: 4,
            title: notificationData['title'] as String,
            body: notificationData['details'] as String,
          );
          hasSentLowSpo2Notification = true;
        } else if (latestValue >= lowThreshold) {
          hasSentLowSpo2Notification = false;
        }
      }
    } catch (e) {
      print("Background Service Error (SpO2): $e");
    }

    // Update the persistent notification for normal operation
    notificationService.showForegroundServiceNotification(
      id: notificationId,
      title: 'SmartVest is Active',
      body: 'Monitoring your health data. Last check: ${DateFormat.jm().format(now)}',
    );
  });
}

void _saveNotificationToFirestore(String userId, Map<String, dynamic> notificationData) {
  FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add(notificationData);
}

// The local _showAnomalyNotification function is no longer needed.
// Its logic has been moved into NotificationService().showHighPriorityAlert()