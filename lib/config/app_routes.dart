import 'package:flutter/material.dart';
import 'package:smartvest/features/auth/login.dart'; // Import your LoginScreen
// Import other screens as needed, e.g.:
// import 'package:smartvest/features/auth/register.dart';
// import 'package:smartvest/features/auth/forgot_password.dart';
// import 'package:smartvest/features/home/home_screen.dart'; // Import your home screen

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot_password';
  static const String home = '/home'; // Add this line

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(), // Use the imported LoginScreen
    // Add other routes here, e.g.:
    // register: (context) => const RegisterScreen(),
    // forgotPassword: (context) => const ForgotPasswordScreen(),
    // home: (context) => const HomeScreen(), // Add this line and the import
  };
}