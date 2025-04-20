import 'package:flutter/material.dart';
// Authentication Page
import 'package:smartvest/features/auth/login.dart';
import 'package:smartvest/features/auth/register.dart';
import 'package:smartvest/features/auth/forgot_password.dart';
// Welcome Page
import 'package:smartvest/features/welcome/welcome.dart';
import 'package:smartvest/features/welcome/name.dart';
import 'package:smartvest/features/welcome/gender_and_birthday.dart';
import 'package:smartvest/features/welcome/activity_level.dart';
import 'package:smartvest/features/welcome/height_and_weight.dart';
// Device Page
import 'package:smartvest/features/device/search_and_connect.dart';
// Main Page
import 'package:smartvest/features/dashboard.dart'; // Import the DashboardScreen
import 'package:smartvest/features/home.dart';
import 'package:smartvest/features/calendar.dart';
import 'package:smartvest/features/notifications.dart';
import 'package:smartvest/features/profile.dart';

class AppRoutes {
  // Authentication Page
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot_password';
  // Welcome Page
  static const String welcome = '/welcome';
  static const String welcomeName = '/welcomeName';
  static const String welcomeGender = '/welcomeGender';
  static const String activityLevel = '/activityLevel';
  static const String heightAndWeight = '/heightAndWeight';
  // Device Page
  static const String searchAndConnect = '/searchAndConnect';
  // Main Page
  static const String dashboard = '/dashboard';
  static const String home = '/home';
  static const String calendar = '/calendar';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    // Authentication Page
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    // Welcome Page
    welcome: (context) => const WelcomeScreen(),
    welcomeName: (context) => const WelcomeNameScreen(),
    welcomeGender: (context) => const GenderAndBirthdayScreen(),
    activityLevel: (context) => const ActivityLevelScreen(),
    heightAndWeight: (context) => const HeightAndWeightScreen(),
    // Device Page
    searchAndConnect: (context) => const SearchingDeviceScreen(),
    // Main Page
    dashboard: (context) => const DashboardScreen(),
    home: (context) => const HomeScreen(),
    calendar: (context) => const CalendarScreen(),
    notifications: (context) => const NotificationsScreen(),
    profile: (context) => const ProfileScreen(),
  };
}
