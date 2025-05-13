import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting and parsing

class EditPersonalInformationScreen extends StatefulWidget {
  const EditPersonalInformationScreen({super.key});

  @override
  State<EditPersonalInformationScreen> createState() =>
      _EditPersonalInformationScreenState();
}

class _EditPersonalInformationScreenState
    extends State<EditPersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  DateTime? _selectedBirthday;
  String? _selectedGender; // This will store 'male', 'female', etc. (lowercase)

  bool _isLoading = true;
  String _errorMessage = '';

  // Store actual values as lowercase, map to display text
  final Map<String, String> _genderDisplayMap = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say', // Using snake_case for consistency if needed
  };
  // Or, if you only have a few and simple capitalization:
  // final List<String> _genderOptionsValues = ['male', 'female', 'other', 'prefer not to say'];


  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not logged in.';
      });
      return;
    }

    try {
      final docSnapshot =
      await _firestore.collection('users').doc(_currentUser.uid).get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          _firstNameController.text = userData['firstName'] ?? '';
          _middleNameController.text = userData['middleName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          if (userData['birthday'] != null && userData['birthday'] is Timestamp) {
            _selectedBirthday = (userData['birthday'] as Timestamp).toDate();
          }
          // _selectedGender will be 'male', 'female', etc. from Firestore
          _selectedGender = userData['gender']?.toString().toLowerCase();

          // Ensure the loaded gender is one of the valid options
          if (_selectedGender != null && !_genderDisplayMap.containsKey(_selectedGender)) {
            // If the stored gender value is not in our map (e.g. old data, or 'Male' was stored before)
            // you might want to set it to null or a default, or attempt a conversion.
            // For now, if it's not a key, it might cause an issue if not handled,
            // but the toLowerCase() should help if 'Male' was previously stored.
            // If a completely unknown value is there, it won't match.
            // A more robust solution would be to ensure `_selectedGender` is one of the keys of `_genderDisplayMap`
            // or null.
            if (_genderDisplayMap.keys.map((k) => k.toLowerCase()).contains(_selectedGender)) {
              _selectedGender = _genderDisplayMap.keys.firstWhere((k) => k.toLowerCase() == _selectedGender);
            } else if (_selectedGender == "Male") { // explicit common case before fix
              _selectedGender = "male";
            } else if (_selectedGender == "Female") {
              _selectedGender = "female";
            }
            // If _selectedGender is still not in _genderDisplayMap.keys, it will default to hintText
          }

        }
      } else {
        _errorMessage = 'User profile data not found.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load profile data: ${e.toString()}';
      print("Error loading user data for edit: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> dataToUpdate = {
      'firstName': _firstNameController.text.trim(),
      'middleName': _middleNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'gender': _selectedGender, // Will save 'male', 'female', etc.
      'birthday': _selectedBirthday != null ? Timestamp.fromDate(_selectedBirthday!) : null,
    };

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .update(dataToUpdate);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal information updated successfully!')),
      );
      Navigator.of(context).pop(); // Go back to profile screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update information: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Personal Information'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _middleNameController,
                decoration: const InputDecoration(labelText: 'Middle Name (Optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('Birthday', style: Theme.of(context).textTheme.titleSmall),
              InkWell(
                onTap: () => _selectBirthday(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 15.0),
                  ),
                  child: Text(
                      _selectedBirthday != null
                          ? DateFormat.yMMMd().format(_selectedBirthday!)
                          : 'Select your birthday',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedBirthday == null ? Theme.of(context).hintColor : null,
                      )
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedGender, // This should be 'male', 'female', etc.
                decoration: const InputDecoration(labelText: 'Gender'),
                hint: const Text("Select Gender"), // Shows when _selectedGender is null
                items: _genderDisplayMap.entries
                    .map((entry) => DropdownMenuItem<String>(
                  value: entry.key, // 'male', 'female'
                  child: Text(entry.value), // 'Male', 'Female'
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                // validator: (value) { // Optional: make gender mandatory
                //   if (value == null || value.isEmpty) {
                //     return 'Please select your gender';
                //   }
                //   return null;
                // },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}