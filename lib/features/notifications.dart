import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM (Unchanged) ---
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

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
}
// --- END OF DESIGN SYSTEM ---


// --- AppNotification Model (Unchanged) ---
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

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      details: data['details'] ?? 'No Details',
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
  List<AppNotification> _notifications = [];
  StreamSubscription? _notificationSubscription;
  bool _isLoading = true;
  bool _isClearingAll = false; // NEW: State for "Clear All" loading indicator

  // Unchanged logic for posture/stress listening
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('healthMonitor/data');
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _listenToPostureAndStress();
    _listenForHealthAlerts();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForHealthAlerts() {
    // ... Unchanged ...
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _notificationSubscription?.cancel();
    _notificationSubscription = FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('notifications')
        .orderBy('timestamp', descending: true).limit(50)
        .snapshots().listen((snapshot) {
      if (mounted) {
        final notifications = snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) setState(() => _isLoading = false);
    });
  }
  void _listenToPostureAndStress() { /* ... Unchanged ... */ }

  // --- NEW: LOGIC FOR DELETING NOTIFICATIONS ---

  Future<void> _clearIndividualNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('notifications').doc(notificationId)
          .delete();
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear notification: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _notifications.isEmpty) return;

    setState(() => _isClearingAll = true);
    Navigator.of(context).pop(); // Close the confirmation dialog

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('notifications');

      final writeBatch = FirebaseFirestore.instance.batch();
      var snapshot = await collectionRef.limit(500).get(); // Batch delete up to 500 at a time

      for (var doc in snapshot.docs) {
        writeBatch.delete(doc.reference);
      }

      await writeBatch.commit();

    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear all notifications: ${e.toString()}'))
        );
      }
    } finally {
      if(mounted) setState(() => _isClearingAll = false);
    }
  }

  void _showClearAllConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Clear All?"),
          content: const Text("Are you sure you want to delete all notifications? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Clear All", style: TextStyle(color: AppColors.heartRateColor)),
              onPressed: _clearAllNotifications,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        // --- NEW: "CLEAR ALL" ACTION BUTTON ---
        actions: [
          if (_notifications.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.primaryText),
              onPressed: _showClearAllConfirmationDialog,
              tooltip: 'Clear All Notifications',
            ),
          if (_isClearingAll)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryText))),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        color: AppColors.primaryText,
        onRefresh: () async {
          _listenForHealthAlerts();
          await Future.delayed(const Duration(seconds: 1));
        },
        // --- NEW: WRAPPED LISTVIEW ITEM WITH DISMISSIBLE ---
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            return Dismissible(
              key: Key(notification.id), // Unique key is crucial
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                _clearIndividualNotification(notification.id);
              },
              background: Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: BoxDecoration(
                  color: AppColors.heartRateColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    _buildNotificationIcon(notification),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.title, style: AppTextStyles.cardTitle),
                          const SizedBox(height: 4),
                          Text(notification.details, style: AppTextStyles.bodyText),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d, hh:mm a').format(notification.timestamp),
                            style: AppTextStyles.secondaryInfo,
                          ),
                        ],
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

  // --- MODERNIZED UI WIDGETS (Unchanged) ---
  Widget _buildNotificationIcon(AppNotification notification) {
    IconData iconData;
    Color color;
    final title = notification.title.toLowerCase();
    if (title.contains("posture")) {
      iconData = Icons.accessibility_new_rounded; color = AppColors.postureColor;
    } else if (title.contains("stress")) {
      iconData = Icons.sentiment_very_dissatisfied_rounded; color = AppColors.stressColor;
    } else if (title.contains("heart")) {
      iconData = Icons.monitor_heart_rounded; color = AppColors.heartRateColor;
    } else {
      iconData = Icons.bloodtype_rounded; color = AppColors.oxygenColor;
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 60, color: AppColors.secondaryText.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text('All Clear!', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text("You have no new notifications.\nWe'll let you know when something comes up.", textAlign: TextAlign.center, style: AppTextStyles.bodyText),
          ],
        ),
      ),
    );
  }
}