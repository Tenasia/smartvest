import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your main pages
import 'package:smartvest/features/home.dart';
import 'package:smartvest/features/notifications.dart';
import 'package:smartvest/features/profile/profile_screen.dart';
import 'package:smartvest/features/calendar.dart';

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color profileColor = Color(0xFF5667FD); // Main accent color
}

class AppTextStyles {
  static final TextStyle navLabel = GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );
}
// --- END OF DESIGN SYSTEM ---


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // The list of pages to be managed by the BottomNavigationBar (Unchanged)
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
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // --- MODERNIZED BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,

        // Styling based on your design system
        type: BottomNavigationBarType.fixed, // Ensures all items are visible and spaced evenly
        backgroundColor: AppColors.cardBackground, // A clean white background
        selectedItemColor: AppColors.profileColor, // Your main accent color for the selected item
        unselectedItemColor: AppColors.secondaryText, // A muted color for unselected items
        elevation: 0, // Remove the default shadow for a flatter look

        // Custom text styles for labels
        selectedLabelStyle: AppTextStyles.navLabel.copyWith(color: AppColors.profileColor),
        unselectedLabelStyle: AppTextStyles.navLabel.copyWith(color: AppColors.secondaryText),

        // Dynamic icons for a polished feel (filled when selected, outlined when not)
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 0 ? Icons.home_filled : Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 1 ? Icons.calendar_month_rounded : Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 2 ? Icons.notifications_rounded : Icons.notifications_outlined),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 3 ? Icons.person_rounded : Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}