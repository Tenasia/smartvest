import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:smartvest/core/services/notification_service.dart';

const int notificationId = 888;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: lowImportanceChannelId,
      initialNotificationTitle: 'ErgoTrack Service',
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
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  // Track notification states to prevent spam - these need to be mutable
  Map<String, bool> notificationFlags = {
    'highHR': false,
    'lowHR': false,
    'lowSpo2': false,
    'poorPosture': false,
    'highStress': false,
  };

  // Track last processed data to prevent duplicate notifications
  String? lastProcessedDataKey;
  DateTime? lastNotificationTime;
  final Duration notificationCooldown = const Duration(minutes: 5);

  // Monitor Firebase Realtime Database for new health data
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final now = DateTime.now();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      print('Background Service: No authenticated user');
      return;
    }

    try {
      // Get the latest health data from Firebase
      final snapshot = await dbRef
          .child('users/${currentUser.uid}/healthData')
          .orderByChild('epoch_time')
          .limitToLast(5)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Find the most recent entry
        String? mostRecentKey;
        int mostRecentTime = 0;
        Map<dynamic, dynamic>? mostRecentEntry;

        data.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          final epochTime = entry['epoch_time'] as int? ?? 0;
          if (epochTime > mostRecentTime) {
            mostRecentTime = epochTime;
            mostRecentKey = key.toString();
            mostRecentEntry = entry;
          }
        });

        // Only process if this is new data and not in cooldown
        if (mostRecentKey != null &&
            mostRecentKey != lastProcessedDataKey &&
            mostRecentEntry != null) {

          // Check cooldown
          if (lastNotificationTime != null &&
              now.difference(lastNotificationTime!) < notificationCooldown) {
            print('Background Service: Notification cooldown active');
            return;
          }

          print('Background Service: Processing new data: $mostRecentKey');
          lastProcessedDataKey = mostRecentKey;

          final alertsCreated = await _checkForHealthAlerts(
            mostRecentEntry!,
            currentUser.uid,
            notificationService,
            notificationFlags,
          );

          if (alertsCreated > 0) {
            lastNotificationTime = now;
          }
        }
      }
    } catch (e) {
      print("Background Service Error: $e");
    }

    // Update the persistent notification
    notificationService.showForegroundServiceNotification(
      id: notificationId,
      title: 'Smart Vest is Active',
      body: 'Monitoring your health data. Last check: ${DateFormat.jm().format(now)}',
    );
  });
}

Future<int> _checkForHealthAlerts(
    Map<dynamic, dynamic> healthData,
    String userId,
    NotificationService notificationService,
    Map<String, bool> flags,
    ) async {
  List<Map<String, String>> alerts = [];

  print('Background Service: Checking health data for alerts...');

  // Check heart rate
  final heartRate = healthData['vitals']?['heart_rate']?.toDouble();
  print('Background Service: Heart Rate = $heartRate');

  if (heartRate != null && heartRate > 0) {
    if (heartRate > 100 && !flags['highHR']!) {
      alerts.add({
        'title': 'High Heart Rate Alert',
        'details': 'Your heart rate is ${heartRate.toInt()} BPM, which is above normal resting range (60-100 BPM).',
        'type': 'heart_rate_high'
      });
      flags['highHR'] = true;
      flags['lowHR'] = false; // Reset opposite flag
    } else if (heartRate < 60 && !flags['lowHR']!) {
      alerts.add({
        'title': 'Low Heart Rate Alert',
        'details': 'Your heart rate is ${heartRate.toInt()} BPM, which is below normal resting range (60-100 BPM).',
        'type': 'heart_rate_low'
      });
      flags['lowHR'] = true;
      flags['highHR'] = false; // Reset opposite flag
    } else if (heartRate >= 60 && heartRate <= 100) {
      // Reset flags when heart rate is normal
      flags['highHR'] = false;
      flags['lowHR'] = false;
    }
  }

  // Check oxygen saturation
  final spo2 = healthData['vitals']?['oxygen_saturation']?.toDouble();
  print('Background Service: SpO2 = $spo2');

  if (spo2 != null && spo2 > 0) {
    if (spo2 < 95 && !flags['lowSpo2']!) {
      alerts.add({
        'title': 'Low Blood Oxygen Alert',
        'details': 'Your blood oxygen level is ${spo2.toInt()}%, which is below the normal range (95-100%).',
        'type': 'spo2_low'
      });
      flags['lowSpo2'] = true;
    } else if (spo2 >= 95) {
      // Reset flag when SpO2 is normal
      flags['lowSpo2'] = false;
    }
  }

  // Check posture
  final rulaScore = healthData['posture']?['rula_score']?.toDouble();
  print('Background Service: RULA Score = $rulaScore');

  if (rulaScore != null && rulaScore > 0) {
    if (rulaScore >= 6 && !flags['poorPosture']!) {
      String postureAssessment = rulaScore >= 7 ? "Very Poor" : "Poor";
      alerts.add({
        'title': 'Poor Posture Alert',
        'details': 'Your posture score is ${rulaScore.toInt()}/7 ($postureAssessment). Consider adjusting your position.',
        'type': 'posture_poor'
      });
      flags['poorPosture'] = true;
    } else if (rulaScore < 6) {
      // Reset flag when posture improves
      flags['poorPosture'] = false;
    }
  }

  // Check stress - IMPROVED LOGIC
  final stressLevel = healthData['stress']?['stress_level']?.toString();
  final gsrReading = healthData['stress']?['gsr_reading']?.toDouble();

  print('Background Service: Stress Level = $stressLevel, GSR = $gsrReading');

  if (!flags['highStress']!) {
    bool shouldAlert = false;
    String alertDetails = '';

    // Only alert for genuinely high stress levels
    if (stressLevel != null && stressLevel.isNotEmpty) {
      final lowerStressLevel = stressLevel.toLowerCase();
      if (lowerStressLevel == 'high' || lowerStressLevel == 'severe' || lowerStressLevel == 'very_high') {
        shouldAlert = true;
        alertDetails = 'Your stress level is detected as $stressLevel. Consider taking a moment to relax.';
      }
    }

    // Only use GSR as backup if stress level is not available and GSR is very high
    if (!shouldAlert && (stressLevel == null || stressLevel.isEmpty) && gsrReading != null && gsrReading > 10) {
      shouldAlert = true;
      alertDetails = 'Your stress indicators show very elevated levels (GSR: ${gsrReading.toInt()}). Consider taking a break.';
    }

    if (shouldAlert) {
      alerts.add({
        'title': 'High Stress Alert',
        'details': alertDetails,
        'type': 'stress_high'
      });
      flags['highStress'] = true;
    }
  } else {
    // Reset stress flag when stress returns to normal levels
    if (stressLevel != null && stressLevel.isNotEmpty) {
      final lowerStressLevel = stressLevel.toLowerCase();
      if (lowerStressLevel == 'low' || lowerStressLevel == 'normal' || lowerStressLevel == 'moderate') {
        flags['highStress'] = false;
        print('Background Service: Stress level normalized, resetting flag');
      }
    } else if (gsrReading != null && gsrReading <= 6) {
      flags['highStress'] = false;
      print('Background Service: GSR normalized, resetting stress flag');
    }
  }

  // Send notifications and save to Firestore
  if (alerts.isNotEmpty) {
    print('Background Service: Creating ${alerts.length} new alerts');

    for (var alert in alerts) {
      // Save to Firestore
      await _saveNotificationToFirestore(userId, {
        'title': alert['title']!,
        'details': alert['details']!,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Show local notification
      await notificationService.showHighPriorityAlert(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title: alert['title']!,
        body: alert['details']!,
      );
    }
  } else {
    print('Background Service: No alerts needed for current health data');
  }

  return alerts.length;
}

_saveNotificationToFirestore(String userId, Map<String, dynamic> notificationData) {
  FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add(notificationData);
}
