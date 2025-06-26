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
          ? Center( /* ... Empty state UI ... */ )
          : ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];

          IconData icon;
          if (notification.title.contains("Posture")) {
            icon = Icons.accessibility_new_rounded;
          } else if (notification.title.contains("Stress")) {
            icon = Icons.sentiment_very_dissatisfied;
          } else if (notification.title.contains("Heart")) {
            icon = Icons.monitor_heart;
          } else { // SpO2
            icon = Icons.bloodtype;
          }

          return Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: Icon(
                icon,
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