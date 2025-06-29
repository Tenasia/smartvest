import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartvest/config/app_routes.dart'; // Assuming you have this for routes

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color profileColor = Color(0xFF5667FD);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 16,
      height: 1.5, // Improved line spacing for readability
      fontWeight: FontWeight.normal,
      color: AppColors.secondaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
}
// --- END OF DESIGN SYSTEM ---

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // Align content to the center and stretch horizontally
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Spacer to push content down from the top
              const Spacer(flex: 2),

              // Mascot image as the centerpiece
              Image.asset(
                'assets/mascot.png', // Make sure this path is correct in your pubspec.yaml
                height: 150.0,
              ),
              const SizedBox(height: 40.0),

              // Main heading
              Text(
                'Welcome to ErgoTrack!',
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),

              // Subtitle with more context
              Text(
                'Your registration is complete. Let\'s set up your profile to personalize your health journey.',
                style: AppTextStyles.secondaryInfo,
                textAlign: TextAlign.center,
              ),

              // Spacer to push the button towards the bottom
              const Spacer(flex: 3),

              // Primary action button, styled consistently
              ElevatedButton(
                onPressed: () {
                  // Navigate to the first step of the profile setup
                  Navigator.pushReplacementNamed(context, AppRoutes.welcomeName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.profileColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: AppColors.profileColor.withOpacity(0.4),
                ),
                child: Text(
                  'Start Setup',
                  style: AppTextStyles.buttonText,
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}