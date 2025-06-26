// lib/features/notifications.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smartvest/core/services/notification_service.dart';

// Model for our displayed notifications
class AppNotification {
  final String id;
  final DateTime timestamp;
  final String title;
  final String details;

  AppNotification({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.details,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _notifications = [];
  bool _isLoading = true;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('healthMonitor/data');
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  // State for alert logic
  Timer? _postureAlertTimer;
  Timer? _stressAlertTimer;
  bool _isPoorPostureState = false;
  bool _isHighStressState = false;

  @override
  void initState() {
    super.initState();
    _listenToHealthData();
  }

  void _listenToHealthData() {
    if (_dataSubscription != null) return;

    _dataSubscription = _dbRef.limitToLast(1).onValue.listen(
          (DatabaseEvent event) {
        if (!mounted || event.snapshot.value == null) return;

        setState(() { _isLoading = false; });

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final latestData = data.values.first as Map<dynamic, dynamic>;

        // Process Posture Data
        if (latestData.containsKey('posture')) {
          _handlePostureData(latestData['posture']);
        }
        // Process Stress Data
        if (latestData.containsKey('stress')) {
          _handleStressData(latestData['stress']);
        }
      },
      onError: (error) {
        print("Error listening to Firebase: $error");
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _handlePostureData(Map<dynamic, dynamic> postureData) {
    final assessment = postureData['rulaAssessment']?.toString().toUpperCase();

    // Check if posture is poor
    if (assessment == 'POOR' || assessment == 'CRITICAL') {
      // If we are not already in a poor posture state, start the timer.
      if (!_isPoorPostureState) {
        setState(() => _isPoorPostureState = true);

        // Cancel any existing timer to be safe
        _postureAlertTimer?.cancel();
        _postureAlertTimer = Timer(const Duration(minutes: 5), () {
          // If the timer completes, it means posture was poor for 5 mins.
          NotificationService().showNotification(
            id: 1, // Unique ID for posture notifications
            title: 'Posture Alert',
            body: 'You have been in a poor posture for 5 minutes. Please adjust your position.',
          );
          // Add to the list shown on screen
          _addNotificationToList('Posture Alert', 'Sustained poor posture detected. Consider taking a break to stretch.');
          // Reset the state to allow for a new alert cycle
          setState(() => _isPoorPostureState = false);
        });
      }
    } else { // Posture is good
      // If we were in a poor state, reset it and cancel the timer.
      if (_isPoorPostureState) {
        setState(() => _isPoorPostureState = false);
        _postureAlertTimer?.cancel();
      }
    }
  }

  void _handleStressData(Map<dynamic, dynamic> stressData) {
    final level = stressData['stressLevel']?.toString().toUpperCase();

    // Check if stress is high
    if (level == 'HIGH_STRESS' || level == 'MILD_STRESS') {
      if (!_isHighStressState) {
        setState(() => _isHighStressState = true);

        _stressAlertTimer?.cancel();
        _stressAlertTimer = Timer(const Duration(minutes: 5), () {
          NotificationService().showNotification(
            id: 2, // Unique ID for stress notifications
            title: 'Stress Level Alert',
            body: 'Your stress levels have been elevated for 5 minutes. Try taking a few deep breaths.',
          );
          _addNotificationToList('Stress Alert', 'Elevated stress detected. A short break or a mindfulness exercise could help.');
          setState(() => _isHighStressState = false);
        });
      }
    } else { // Stress is relaxed
      if (_isHighStressState) {
        setState(() => _isHighStressState = false);
        _stressAlertTimer?.cancel();
      }
    }
  }

  void _addNotificationToList(String title, String details) {
    if (!mounted) return;
    setState(() {
      _notifications.insert(
        0,
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          title: title,
          details: details,
        ),
      );
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _postureAlertTimer?.cancel();
    _stressAlertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Notifications'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "No new notifications.\n\nThis screen will show alerts for sustained poor posture or high stress.",
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: Icon(
                notification.title.contains("Posture")
                    ? Icons.accessibility_new_rounded
                    : Icons.sentiment_very_dissatisfied,
                color: Theme.of(context).primaryColor,
                size: 32,
              ),
              title: Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4.0),
                  Text(notification.details),
                  const SizedBox(height: 8.0),
                  Text(
                    DateFormat('MMM d, hh:mm a').format(notification.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}