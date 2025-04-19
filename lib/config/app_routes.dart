import 'package:flutter/material.dart';
import 'package:smartvest/features/auth/login.dart';
import 'package:smartvest/features/auth/register.dart';
import 'package:smartvest/features/dashboard.dart';
import 'package:smartvest/features/auth/forgot_password.dart'; // Import the ForgotPasswordScreen
// Import other screens as needed, e.g.:
// import 'package:smartvest/features/auth/register.dart';
// import 'package:smartvest/features/auth/forgot_password.dart';
// import 'package:smartvest/features/home/home_screen.dart'; // Import your home screen

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot_password';
  static const String dashboard = '/dashboard'; // Add this line

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(), // Use the imported LoginScreen
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(), // Add this line
    dashboard: (context) => const DashboardScreen(),
    // Add other routes here, e.g.:
    // register: (context) => const RegisterScreen(),
    // forgotPassword: (context) => const ForgotPasswordScreen(),
    // home: (context) => const HomeScreen(), // Add this line and the import
  };
}