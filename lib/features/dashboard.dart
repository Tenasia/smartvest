import 'package:flutter/material.dart';
import 'package:smartvest/features/home.dart';
import 'package:smartvest/features/notifications.dart';
import 'package:smartvest/features/profile/profile_screen.dart';
// The HealthDataScreen is no longer needed here
import 'package:smartvest/features/health_data_screen.dart';
import 'package:smartvest/features/calendar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // The list of pages to be managed by the BottomNavigationBar
  final List<Widget> _pages = [
    const HomeScreen(),
    const CalendarScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- THIS IS THE FIX ---
      // IndexedStack keeps all pages in the widget tree but only shows the
      // one at the current index. This preserves the state of each page.
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
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
      ),
    );
  }
}