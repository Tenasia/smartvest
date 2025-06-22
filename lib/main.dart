import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smartvest/config/app_routes.dart';
import 'features/auth/login.dart'; // Ensure LoginScreen is imported
import 'firebase_options.dart';

void main() async {
  // This is the core of the fix. We wrap the initialization in a try-catch block.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // If Firebase initializes successfully, run the main app.
    runApp(const MyApp());
  } catch (e) {
    // If an error occurs during initialization, run an error screen instead.
    // This prevents the white screen crash.
    print("Failed to initialize Firebase: $e");
    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartVest',
      initialRoute: AppRoutes.login, // Your initial route
      routes: AppRoutes.routes,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // The 'home' property is redundant when 'initialRoute' is used,
      // but we'll leave it pointing to LoginScreen as a fallback.
      home: const LoginScreen(),
    );
  }
}

// A simple widget to display an error message if the app fails to start.
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text(
                  'Application Failed to Start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'There was an error during initialization. Please check your connection or configuration and restart the app.\n\nError: $errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}