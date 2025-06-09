import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// Model for our notifications
enum NotificationSeverity { info, warning, critical }

class AppNotification {
  final String id;
  final DateTime timestamp;
  final String title;
  final String details;
  final NotificationSeverity severity;
  final IconData icon;

  AppNotification({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.details,
    this.severity = NotificationSeverity.info,
    required this.icon,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  late DatabaseReference _databaseReference;
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  void _initializeFirebase() async {
    try {
      // Stellen Sie sicher, dass Firebase initialisiert ist
      await Firebase.initializeApp();
      _databaseReference = FirebaseDatabase.instance.ref('smartVest/postureData');
      _listenToPostureData();
    } catch (e) {
      print('Fehler bei der Initialisierung von Firebase: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler bei der Verbindung zur Datenbank.')),
        );
      }
    }
  }

  void _listenToPostureData() {
    _dataSubscription = _databaseReference.onValue.listen((DatabaseEvent event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      if (data == null) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

      final List<AppNotification> newNotifications = [];
      final postureDataMap = data as Map<dynamic, dynamic>;

      postureDataMap.forEach((key, value) {
        final postureEntry = value as Map<dynamic, dynamic>;
        final rulaAssessment = postureEntry['rulaAssessment']?.toString() ?? 'Unknown';
        final timestampStr = postureEntry['timestamp']?.toString();

        if (timestampStr != null) {
          // Firebase-Zeitstempel ist wahrscheinlich in Millisekunden, umrechnen
          final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
          final notification = _createNotificationFromData(key, postureEntry, timestamp);
          newNotifications.add(notification);
        }
      });

      // Sortieren nach Zeitstempel, neueste zuerst
      newNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _notifications = newNotifications;
        _isLoading = false;
      });

    }, onError: (error) {
      print("Fehler beim Abhören von Daten: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  AppNotification _createNotificationFromData(String id, Map<dynamic, dynamic> data, DateTime timestamp) {
    final rulaAssessment = data['rulaAssessment']?.toString() ?? 'INFO';
    final rulaScore = data['rulaScore'] ?? 0;
    NotificationSeverity severity;
    IconData icon;
    String title;
    String details;

    switch (rulaAssessment.toUpperCase()) {
      case 'FAIR':
        severity = NotificationSeverity.warning;
        icon = Icons.accessibility_new_rounded;
        title = 'Posture Alert';
        details = 'Sustained poor posture detected. RULA Score: $rulaScore. Please adjust your position.';
        break;
      case 'POOR':
      case 'CRITICAL':
        severity = NotificationSeverity.critical;
        icon = Icons.warning_amber_rounded;
        title = 'Critical Posture Warning!';
        details = 'High-risk posture detected with a RULA score of $rulaScore. Immediate adjustment is required to prevent strain.';
        break;
      case 'GOOD':
      default:
        severity = NotificationSeverity.info;
        icon = Icons.check_circle_outline;
        title = 'Good Posture!';
        details = 'Your posture is currently good. Keep it up! RULA Score: $rulaScore.';
        break;
    }

    return AppNotification(
      id: id,
      timestamp: timestamp,
      title: title,
      details: details,
      severity: severity,
      icon: icon,
    );
  }


  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  Color _getSeverityColor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.critical:
        return Colors.redAccent.shade200;
      case NotificationSeverity.warning:
        return Colors.orange.shade400;
      case NotificationSeverity.info:
      default:
        return Colors.blue.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
        child: Text(
          "No new notifications.",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(12.0),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Card(
            elevation: 3.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
              side: BorderSide(
                color: _getSeverityColor(notification.severity).withOpacity(0.7),
                width: 1.2,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: _getSeverityColor(notification.severity).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  color: _getSeverityColor(notification.severity),
                  size: 28,
                ),
              ),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6.0),
                  Text(
                    notification.details,
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        height: 1.4
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    DateFormat('MMM d, yyyy hh:mm a').format(notification.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              isThreeLine: true, // Ermöglicht mehr Platz für den Untertitel
              onTap: () {
                // Optional: Tippen für weitere Details oder Navigation handhaben
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Alert Type: ${notification.title}')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}