import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
}
// --- END OF DESIGN SYSTEM ---


class EditPhysicalInformationScreen extends StatefulWidget {
  const EditPhysicalInformationScreen({super.key});
  @override
  State<EditPhysicalInformationScreen> createState() =>
      _EditPhysicalInformationScreenState();
}

class _EditPhysicalInformationScreenState
    extends State<EditPhysicalInformationScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _heightController;
  late TextEditingController _weightController;
  String? _selectedActivityLevel;
  bool _isLoading = true;
  String _errorMessage = '';

  final List<String> _activityLevelOptions = ['sedentary', 'light', 'active', 'very_active'];
  final Map<String, String> _activityLevelDisplay = {
    'sedentary': 'Sedentary',
    'light': 'Light Activity',
    'active': 'Active',
    'very_active': 'Very Active',
  };

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // ... Functionality is unchanged ...
    setState(() { _isLoading = true; _errorMessage = ''; });
    if (_currentUser == null) {
      setState(() { _isLoading = false; _errorMessage = 'User not logged in.'; });
      return;
    }
    try {
      final docSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          _heightController.text = userData['heightCm']?.toString() ?? '';
          _weightController.text = userData['weightKg']?.toString() ?? '';
          _selectedActivityLevel = userData['activityLevel'];
        }
      } else {
        _errorMessage = 'User profile data not found.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load profile data: ${e.toString()}';
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      return;
    }
    setState(() => _isLoading = true);
    Map<String, dynamic> dataToUpdate = {
      'heightCm': int.tryParse(_heightController.text.trim()),
      'weightKg': double.tryParse(_weightController.text.trim()),
      'activityLevel': _selectedActivityLevel,
    };
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update(dataToUpdate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Physical information updated successfully!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update information: ${e.toString()}')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODERNIZED UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Physical Info', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _heightController,
                decoration: _buildInputDecoration(label: 'Height (cm)', icon: Icons.height_rounded),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter your height';
                  if (int.tryParse(value.trim()) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: _buildInputDecoration(label: 'Weight (kg)', icon: Icons.monitor_weight_rounded),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter your weight';
                  if (double.tryParse(value.trim()) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedActivityLevel,
                decoration: _buildInputDecoration(label: 'Activity Level', icon: Icons.directions_run_rounded),
                hint: Text("Select Activity Level", style: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText)),
                items: _activityLevelOptions.map((level) => DropdownMenuItem(
                  value: level,
                  child: Text(_activityLevelDisplay[level] ?? level, style: AppTextStyles.bodyText),
                )).toList(),
                onChanged: (value) => setState(() => _selectedActivityLevel = value),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please select your activity level';
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.profileColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Text('Save Changes', style: AppTextStyles.buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A reusable helper for consistent input field styling
  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 22),
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.profileColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
    );
  }
}