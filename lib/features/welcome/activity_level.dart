import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartvest/config/app_routes.dart';

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
      height: 1.5,
      fontWeight: FontWeight.normal,
      color: AppColors.secondaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryText);
}
// --- END OF DESIGN SYSTEM ---


class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String? _selectedActivityLevel;
  bool _isLoading = false;

  Future<void> _onContinue() async {
    if (_selectedActivityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your activity level.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'activityLevelCompleted': true,
          'activityLevel': _selectedActivityLevel,
        });
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.heightAndWeight);
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save activity level: ${e.toString()}')),
          );
        }
      }
    }
    if(mounted) setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator for the setup flow
            const LinearProgressIndicator(
              value: 3 / 4, // Step 3 of 4
              backgroundColor: AppColors.background,
              color: AppColors.profileColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Main heading
                    Text('Your Activity Level', style: AppTextStyles.heading),
                    const SizedBox(height: 8.0),
                    Text(
                      'This helps in calculating your daily health goals.',
                      style: AppTextStyles.secondaryInfo,
                    ),
                    const SizedBox(height: 24.0),

                    // Grid of activity options
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        children: <Widget>[
                          _buildActivityOption('Sedentary', 'assets/sedentary.svg', 'sedentary'),
                          _buildActivityOption('Light', 'assets/light_activity.svg', 'light'),
                          _buildActivityOption('Active', 'assets/active.svg', 'active'),
                          _buildActivityOption('Very Active', 'assets/very_active.svg', 'very_active'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.profileColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text('Continue', style: AppTextStyles.buttonText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A modernized widget for the selection cards
  Widget _buildActivityOption(String label, String imagePath, String value) {
    final bool isSelected = _selectedActivityLevel == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedActivityLevel = value),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.profileColor : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.profileColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SvgPicture.asset(
              imagePath,
              height: 60.0,
              colorFilter: ColorFilter.mode(
                isSelected ? Colors.white : AppColors.primaryText,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                color: isSelected ? Colors.white : AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}