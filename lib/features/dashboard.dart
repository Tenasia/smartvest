import 'package:flutter/material.dart';

// Import your page files
import 'package:smartvest/features/home.dart';
import 'package:smartvest/features/calendar.dart';
import 'package:smartvest/features/notifications.dart';
import 'package:smartvest/features/profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  // List of pages corresponding to the bottom navigation items.
  final List<Widget> _pages = [
    const HomeScreen(),       // Index 0: Home
    const CalendarScreen(),   // Index 1: Calendar
    const NotificationsScreen(), // Index 2: Notifications
    const ProfileScreen(),     // Index 3: Profile
  ];

  @override
  void initState() {
    super.initState();
    // Show disclaimer after the first frame when DashboardScreen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimerDialog(context);
    });
  }

  void _showDisclaimerDialog(BuildContext context) {
    // Check if disclaimer has been shown before using shared_preferences
    // For simplicity, this example shows it every time.
    // You might want to add logic here to show it only once using shared_preferences.
    showDialog(
      context: context,
      barrierDismissible: false, // User must acknowledge
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Important Disclaimer"),
          content: SingleChildScrollView( // In case of long text
            child: Text(
                "The data provided by SmartVest is for reference and informational purposes only and is not intended for clinical or medical diagnostic use. Please consult with a healthcare professional for any health concerns or before making any decisions related to your health. User discretion is advised for the data gathered."
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("I Understand"),
              onPressed: () {
                // Potentially save a flag in shared_preferences so it doesn't show again
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // Display the selected page.
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue, // Change as needed
        unselectedItemColor: Colors.grey, // Change as needed
        onTap: _onItemTapped,
      ),
    );
  }
}