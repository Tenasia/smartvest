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
