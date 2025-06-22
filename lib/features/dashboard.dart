import 'package:flutter/material.dart';

// Import your page files
import 'package:smartvest/features/home.dart';
import 'package:smartvest/features/calendar.dart';
import 'package:smartvest/features/notifications.dart';
import 'package:smartvest/features/profile/profile_screen.dart';
// The HealthDataScreen is no longer needed here
// import 'package:smartvest/features/health_data_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  // UPDATED: Removed HealthDataScreen from the list of pages.
  final List<Widget> _pages = [
    const HomeScreen(),           // Index 0: Home
    const CalendarScreen(),       // Index 1: Calendar
    const NotificationsScreen(),  // Index 2: Notifications
    const ProfileScreen(),        // Index 3: Profile (previously 4)
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimerDialog(context);
    });
  }

  void _showDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Important Disclaimer"),
          content: const SingleChildScrollView(
            child: Text(
                "The data provided by SmartVest is for reference and informational purposes only and is not intended for clinical or medical diagnostic use. Please consult with a healthcare professional for any health concerns or before making any decisions related to your health. User discretion is advised for the data gathered."
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("I Understand"),
              onPressed: () {
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
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        // UPDATED: Removed the "Health" item from the navigation bar.
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
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
