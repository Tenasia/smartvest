import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10.0),
              const Text(
                'You have successfully registered.',
                style: TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30.0),
              // Replace with your actual logo asset
              Image.asset(
                'assets/mascot.png',
                height: 100.0,
              ),
              const SizedBox(height: 30.0),
              const Text(
                'Welcome to App Name! (To replace later). To help us take better care of you, please fill out the following form.',
                style: TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40.0),
              ElevatedButton(
                onPressed: () {
                  // Navigate to the first setup page
                  Navigator.pushReplacementNamed(context, '/welcomeName'); // Assuming your first setup page route is '/welcome1'
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 12.0),
                  child: Text(
                    'Start Set Up',
                    style: TextStyle(fontSize: 18.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}