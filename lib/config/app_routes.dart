import 'package:flutter/material.dart';

// Authentication Page
import 'package:smartvest/features/auth/login.dart';
import 'package:smartvest/features/auth/register.dart';
import 'package:smartvest/features/auth/forgot_password.dart';

// Welcome Page
import 'package:smartvest/features/welcome/welcome.dart';
import 'package:smartvest/features/welcome/name.dart'; // Assuming your name screen file is named welcome_name.dart
import 'package:smartvest/features/welcome/gender_and_birthday.dart'; // Assuming your gender screen file is named welcome_gender.dart
import 'package:smartvest/features/welcome/activity_level.dart'; // Import the ActivityLevelScreen
import 'package:smartvest/features/welcome/height_and_weight.dart'; // Import HeightAndWeightScreen

// Device Page
import 'package:smartvest/features/device/search_and_connect.dart';

// Main Page
import 'package:smartvest/features/dashboard.dart';

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
  };
}