import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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


class EditPersonalInformationScreen extends StatefulWidget {
  const EditPersonalInformationScreen({super.key});
  @override
  State<EditPersonalInformationScreen> createState() =>
      _EditPersonalInformationScreenState();
}

class _EditPersonalInformationScreenState
    extends State<EditPersonalInformationScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  bool _isLoading = true;
  String _errorMessage = '';

  final Map<String, String> _genderDisplayMap = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
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
          _firstNameController.text = userData['firstName'] ?? '';
          _middleNameController.text = userData['middleName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          if (userData['birthday'] != null && userData['birthday'] is Timestamp) {
            _selectedBirthday = (userData['birthday'] as Timestamp).toDate();
          }
          _selectedGender = userData['gender']?.toString().toLowerCase();
        }
      } else {
        _errorMessage = 'User profile data not found.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load profile data: ${e.toString()}';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
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
    if (picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
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
      'firstName': _firstNameController.text.trim(),
      'middleName': _middleNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'gender': _selectedGender,
      'birthday': _selectedBirthday != null ? Timestamp.fromDate(_selectedBirthday!) : null,
    };
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update(dataToUpdate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personal information updated successfully!')));
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
        title: Text('Personal Info', style: AppTextStyles.heading),
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
                controller: _firstNameController,
                decoration: _buildInputDecoration(label: 'First Name', icon: Icons.person_outline_rounded),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your first name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _middleNameController,
                decoration: _buildInputDecoration(label: 'Middle Name (Optional)', icon: Icons.person_outline_rounded),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: _buildInputDecoration(label: 'Last Name', icon: Icons.person_outline_rounded),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your last name' : null,
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () => _selectBirthday(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(label: 'Birthday', icon: Icons.cake_rounded),
                  child: Text(
                      _selectedBirthday != null
                          ? DateFormat.yMMMMd().format(_selectedBirthday!)
                          : 'Select your birthday',
                      style: AppTextStyles.bodyText.copyWith(
                          color: _selectedBirthday == null ? AppColors.secondaryText : AppColors.primaryText,
                          fontSize: 16
                      )
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _buildInputDecoration(label: 'Gender', icon: Icons.wc_rounded),
                hint: Text("Select Gender", style: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText)),
                items: _genderDisplayMap.entries.map((entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value, style: AppTextStyles.bodyText),
                )).toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
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