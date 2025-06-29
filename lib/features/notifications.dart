import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
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

  // Factory constructor to create an AppNotification from a Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      details: data['details'] ?? 'No Details',
      // Firestore timestamp needs to be converted to DateTime
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // This list will be populated by the Firestore stream
  List<AppNotification> _notifications = [];
  StreamSubscription? _notificationSubscription;
  bool _isLoading = true;

  // This part for posture/stress can remain as is
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('healthMonitor/data');
  StreamSubscription<DatabaseEvent>? _dataSubscription;
  Timer? _postureAlertTimer;
  Timer? _stressAlertTimer;
  bool _isPoorPostureState = false;
  bool _isHighStressState = false;

  @override
  void initState() {
    super.initState();
    _listenToPostureAndStress(); // For posture and stress from Firebase
    _listenForHealthAlerts(); // NEW: For HR and SpO2 from Firestore
  }

  // NEW: Listens for notifications from Firestore
  void _listenForHealthAlerts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _notificationSubscription?.cancel();
    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50) // Get the last 50 notifications
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final notifications = snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("Error listening to notifications: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // Renamed for clarity
  void _listenToPostureAndStress() {
    // ... (This function's content remains the same, just handling posture/stress)
    if (_dataSubscription != null) return;
    _dataSubscription = _dbRef.limitToLast(1).onValue.listen(
          (DatabaseEvent event) {
        if (!mounted || event.snapshot.value == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final latestData = data.values.first as Map<dynamic, dynamic>;

        // You might want to save posture/stress alerts to Firestore too
        // For now, we leave them as transient alerts
        if (latestData.containsKey('posture')) _handlePostureData(latestData['posture']);
        if (latestData.containsKey('stress')) _handleStressData(latestData['stress']);
      },
      onError: (error) {
        print("Error listening to Firebase RTDB: $error");
      },
    );
  }

  // These handlers can remain, but for full persistence, they should also
  // write to Firestore instead of just calling _addNotificationToList.
  void _handlePostureData(Map<dynamic, dynamic> postureData) {
    // ...
  }
  void _handleStressData(Map<dynamic, dynamic> stressData) {
    // ...
  }
  // This is a placeholder now, as the main list is driven by Firestore.
  // We will keep it for the non-persistent posture/stress alerts.
  void _addNotificationToList(String title, String details) {
    if (!mounted) return;
    setState(() {
      _notifications.insert(0, AppNotification(id: "transient", timestamp: DateTime.now(), title: title, details: details));
    });
  }


  @override
  void dispose() {
    _dataSubscription?.cancel();
    _notificationSubscription?.cancel(); // Cancel Firestore listener
    _postureAlertTimer?.cancel();
    _stressAlertTimer?.cancel();
    super.dispose();
  }

  Widget _buildNotificationIcon(AppNotification notification) {
    IconData iconData;
    Color backgroundColor;
    Color iconColor;

    // Use theme colors for a more integrated look
    final colorScheme = Theme.of(context).colorScheme;

    if (notification.title.contains("Posture")) {
      iconData = Icons.accessibility_new_rounded;
      backgroundColor = colorScheme.secondaryContainer;
      iconColor = colorScheme.onSecondaryContainer;
    } else if (notification.title.contains("Stress")) {
      iconData = Icons.sentiment_very_dissatisfied;
      backgroundColor = Colors.purple.shade100;
      iconColor = Colors.purple.shade800;
    } else if (notification.title.contains("Heart")) {
      iconData = Icons.monitor_heart_outlined;
      backgroundColor = colorScheme.errorContainer;
      iconColor = colorScheme.onErrorContainer;
    } else { // SpO2
      iconData = Icons.bloodtype_outlined;
      backgroundColor = Colors.teal.shade100;
      iconColor = Colors.teal.shade800;
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: backgroundColor,
      child: Icon(iconData, color: iconColor, size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the color scheme for consistency
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Notifications'),
        centerTitle: true,
        // A subtle background color from the theme
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState(textTheme, colorScheme)
          : RefreshIndicator(
        onRefresh: () async {
          // Although Firestore streams update automatically,
          // this gives users a manual way to refresh.
          _listenForHealthAlerts();
          // Add a small delay for user feedback
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            return Card(
              // Use margin for spacing between cards
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              // Use modern M3 card styling
              elevation: 1.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                leading: _buildNotificationIcon(notification),
                title: Text(
                  notification.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4.0),
                    Text(
                      notification.details,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      DateFormat('MMM d, hh:mm a').format(notification.timestamp),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // A dedicated widget for the "empty" state for better readability
  Widget _buildEmptyState(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'All Clear!',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no new notifications.\nWe\'ll let you know when something comes up.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}