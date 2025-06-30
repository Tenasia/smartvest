import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _dataSubscription;
  List<AppNotification> _notifications = [];

  // Track last processed data to prevent duplicate notifications
  String? _lastProcessedDataKey;
  DateTime? _lastNotificationTime;
  final Duration _notificationCooldown = const Duration(minutes: 5); // Prevent spam

  @override
  void initState() {
    super.initState();
    _listenToFirebaseNotifications();
    // _listenToFirebaseHealthData(); // DISABLED - Let background service handle alerts
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _listenToFirebaseNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          return AppNotification(
            id: doc.id,
            title: data['title'] ?? 'No Title',
            details: data['details'] ?? 'No Details',
            timestamp: data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
          );
        }).toList();
      });
    });
  }

  void _listenToFirebaseHealthData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _dataSubscription = _dbRef
        .child('users/${user.uid}/healthData')
        .orderByChild('epoch_time')
        .limitToLast(5) // Get last 5 entries to check for new data
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

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

        // Only process if this is new data
        if (mostRecentKey != null &&
            mostRecentKey != _lastProcessedDataKey &&
            mostRecentEntry != null) {

          print('Processing new health data: $mostRecentKey at ${DateTime.fromMillisecondsSinceEpoch(mostRecentTime * 1000)}');
          _lastProcessedDataKey = mostRecentKey;
          _checkForHealthAlerts(mostRecentEntry!);
        }
      }
    });
  }

  Future<void> _checkForHealthAlerts(Map<dynamic, dynamic> healthData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Implement cooldown to prevent notification spam
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < _notificationCooldown) {
      print('Notification cooldown active, skipping alerts');
      return;
    }

    List<Map<String, String>> alerts = [];

    // Check heart rate
    final heartRate = healthData['vitals']?['heart_rate']?.toDouble();
    if (heartRate != null && heartRate > 0) {
      if (heartRate > 100) {
        alerts.add({
          'title': 'High Heart Rate Alert',
          'details': 'Your heart rate is ${heartRate.toInt()} BPM, which is above normal resting range (60-100 BPM).'
        });
      } else if (heartRate < 60) {
        alerts.add({
          'title': 'Low Heart Rate Alert',
          'details': 'Your heart rate is ${heartRate.toInt()} BPM, which is below normal resting range (60-100 BPM).'
        });
      }
    }

    // Check oxygen saturation
    final spo2 = healthData['vitals']?['oxygen_saturation']?.toDouble();
    if (spo2 != null && spo2 > 0 && spo2 < 95) {
      alerts.add({
        'title': 'Low Blood Oxygen Alert',
        'details': 'Your blood oxygen level is ${spo2.toInt()}%, which is below the normal range (95-100%).'
      });
    }

    // Check posture using correct field name
    final rulaScore = healthData['posture']?['rula_score']?.toDouble();
    if (rulaScore != null && rulaScore > 0 && rulaScore >= 5) {
      String postureAssessment = "Poor";
      if (rulaScore >= 7) postureAssessment = "Very Poor";
      else if (rulaScore >= 5) postureAssessment = "Poor";

      alerts.add({
        'title': 'Poor Posture Alert',
        'details': 'Your posture score is ${rulaScore.toInt()}/7 ($postureAssessment). Consider adjusting your position or taking a break.'
      });
    }

    // Check stress using correct field name
    final stressLevel = healthData['stress']?['stress_level']?.toString();
    final gsrReading = healthData['stress']?['gsr_reading']?.toDouble();

    // Only trigger stress alerts for meaningful values
    if (stressLevel != null && stressLevel.isNotEmpty &&
        (stressLevel.toLowerCase().contains('high') || stressLevel.toLowerCase().contains('severe'))) {
      alerts.add({
        'title': 'High Stress Alert',
        'details': 'Your stress level is detected as $stressLevel. Consider taking a moment to relax and practice deep breathing.'
      });
    } else if (gsrReading != null && gsrReading > 8) {
      alerts.add({
        'title': 'Elevated Stress Alert',
        'details': 'Your stress indicators show elevated levels (GSR: ${gsrReading.toInt()}). Consider taking a break to relax.'
      });
    }

    // Only save alerts if there are any and update last notification time
    if (alerts.isNotEmpty) {
      print('Creating ${alerts.length} new alerts');
      _lastNotificationTime = now;

      for (var alert in alerts) {
        await FirebaseFirestore.instance
            .collection('users').doc(user.uid)
            .collection('notifications')
            .add({
          'title': alert['title'],
          'details': alert['details'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } else {
      print('No alerts needed for current health data');
    }
  }

  Future<void> _clearNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('notifications').doc(notificationId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear notification: ${e.toString()}')),
        );
      }
    }
  }

  void _debugHealthData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _dbRef
        .child('users/${user.uid}/healthData')
        .orderByChild('epoch_time')
        .limitToLast(1)
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          print('Notifications Screen Debug: Latest data = $entry');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final batch = FirebaseFirestore.instance.batch();
                  for (var notification in _notifications) {
                    batch.delete(FirebaseFirestore.instance
                        .collection('users').doc(user.uid)
                        .collection('notifications').doc(notification.id));
                  }
                  await batch.commit();
                }
              },
              tooltip: 'Clear All',
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _notifications.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: AppColors.secondaryText),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We\'ll notify you about important health alerts',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Dismissible(
            key: Key(notification.id),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              _clearNotification(notification.id);
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: NotificationCard(notification: notification),
          );
        },
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const NotificationCard({Key? key, required this.notification})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildNotificationIcon(notification),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.details,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, hh:mm a').format(notification.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(AppNotification notification) {
    IconData iconData;
    Color color;
    final title = notification.title.toLowerCase();
    if (title.contains("posture")) {
      iconData = Icons.accessibility_new_rounded;
      color = AppColors.postureColor;
    } else if (title.contains("stress")) {
      iconData = Icons.sentiment_very_dissatisfied_rounded;
      color = AppColors.stressColor;
    } else if (title.contains("heart")) {
      iconData = Icons.monitor_heart_rounded;
      color = AppColors.heartRateColor;
    } else {
      iconData = Icons.bloodtype_rounded;
      color = AppColors.oxygenColor;
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String details;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.details,
    required this.timestamp,
  });
}

class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color stressColor = Color(0xFFF2C94C);
}
