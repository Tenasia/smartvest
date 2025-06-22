import 'package:flutter/material.dart';
import 'package:smartvest/features/auth/login.dart';
import 'package:smartvest/features/auth/register.dart';
import 'package:smartvest/features/auth/forgot_password.dart';
import 'package:smartvest/features/welcome/welcome.dart';
import 'package:smartvest/features/welcome/name.dart';
import 'package:smartvest/features/welcome/gender_and_birthday.dart';
import 'package:smartvest/features/welcome/activity_level.dart';
import 'package:smartvest/features/welcome/height_and_weight.dart';
import 'package:smartvest/features/device/search_and_connect.dart';
import 'package:smartvest/features/dashboard.dart';
import 'package:smartvest/features/home.dart';
import 'package:smartvest/features/calendar.dart';
import 'package:smartvest/features/notifications.dart';
import 'package:smartvest/features/profile/profile_screen.dart';
import 'package:smartvest/features/profile/edit_personal_information_screen.dart';
import 'package:smartvest/features/profile/edit_physical_information_screen.dart';
import 'package:smartvest/features/posture_screen.dart';
import 'package:smartvest/features/heartrate_screen.dart';
import 'package:smartvest/features/stress_level_screen.dart';
import 'package:smartvest/features/smart_vest_screen.dart';
import 'package:smartvest/features/oxygen_saturation_screen.dart'; // Import the new screen

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot_password';
  static const String welcome = '/welcome';
  static const String welcomeName = '/welcomeName';
  static const String welcomeGender = '/welcomeGender';
  static const String activityLevel = '/activityLevel';
  static const String heightAndWeight = '/heightAndWeight';
  static const String searchAndConnect = '/searchAndConnect';
  static const String dashboard = '/dashboard';
  static const String home = '/home';
  static const String calendar = '/calendar';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editPersonalInformation = '/edit_personal_information';
  static const String editPhysicalInformation = '/edit_physical_information';
  static const String postureScreen = '/posture_screen';
  static const String heartRateScreen = '/heart_rate_screen';
  static const String stressLevelScreen = '/stress_level_screen';
  static const String smartVestScreen = '/smart_vest_screen';
  static const String oxygenSaturationScreen = '/oxygen_saturation_screen'; // New route name

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    welcome: (context) => const WelcomeScreen(),
    welcomeName: (context) => const WelcomeNameScreen(),
    welcomeGender: (context) => const GenderAndBirthdayScreen(),
    activityLevel: (context) => const ActivityLevelScreen(),
    heightAndWeight: (context) => const HeightAndWeightScreen(),
    searchAndConnect: (context) => const SearchingDeviceScreen(),
    dashboard: (context) => const DashboardScreen(),
    home: (context) => const HomeScreen(),
    calendar: (context) => const CalendarScreen(),
    notifications: (context) => const NotificationsScreen(),
    profile: (context) => const ProfileScreen(),
    editPersonalInformation: (context) => const EditPersonalInformationScreen(),
    editPhysicalInformation: (context) => const EditPhysicalInformationScreen(),
    postureScreen: (context) => const PostureScreen(),
    heartRateScreen: (context) => const HeartRateScreen(),
    stressLevelScreen: (context) => const StressLevelScreen(),
    smartVestScreen: (context) => const SmartVestScreen(),
    oxygenSaturationScreen: (context) => const OxygenSaturationScreen(), // Add the new route
  };
}
