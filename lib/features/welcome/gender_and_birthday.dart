import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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


class GenderAndBirthdayScreen extends StatefulWidget {
  const GenderAndBirthdayScreen({super.key});

  @override
  State<GenderAndBirthdayScreen> createState() => _GenderAndBirthdayScreenState();
}

class _GenderAndBirthdayScreenState extends State<GenderAndBirthdayScreen> {
  String? _selectedGender;
  // Default to a reasonable age, e.g., 18 years ago
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 365 * 18));
  bool _isLoading = false;

  Future<void> _onContinue() async {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'welcomeGenderCompleted': true,
          'gender': _selectedGender,
          'birthday': _selectedDate,
        });
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.activityLevel);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save data: ${e.toString()}')),
          );
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.profileColor),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
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
              value: 2 / 4, // Step 2 of 4
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
                    Text('About You', style: AppTextStyles.heading),
                    const SizedBox(height: 8.0),
                    Text('This helps us provide more accurate health insights.', style: AppTextStyles.secondaryInfo),
                    const SizedBox(height: 40.0),

                    // Gender Selection
                    Text('Your Gender', style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildGenderCard('male', 'Male', Icons.male_rounded),
                        const SizedBox(width: 16),
                        _buildGenderCard('female', 'Female', Icons.female_rounded),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Birthday Selection
                    Text('Your Birthday', style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectBirthday(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.transparent)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_rounded, color: AppColors.secondaryText),
                            const SizedBox(width: 16),
                            Text(
                                DateFormat.yMMMMd().format(_selectedDate),
                                style: AppTextStyles.bodyText.copyWith(fontSize: 16)
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

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

  Widget _buildGenderCard(String value, String label, IconData icon) {
    final bool isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.profileColor : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? null : Border.all(color: AppColors.secondaryText.withOpacity(0.2)),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                size: 32.0,
                color: isSelected ? Colors.white : AppColors.secondaryText,
              ),
              const SizedBox(height: 8.0),
              Text(
                label,
                style: AppTextStyles.bodyText.copyWith(
                  color: isSelected ? Colors.white : AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}