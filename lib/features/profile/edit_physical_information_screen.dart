import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditPhysicalInformationScreen extends StatefulWidget {
  const EditPhysicalInformationScreen({super.key});

  @override
  State<EditPhysicalInformationScreen> createState() =>
      _EditPhysicalInformationScreenState();
}

class _EditPhysicalInformationScreenState
    extends State<EditPhysicalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _heightController;
  late TextEditingController _weightController;
  String? _selectedActivityLevel;
  // bool? _hasDeviceConnected; // No longer needed for display in this screen

  bool _isLoading = true;
  String _errorMessage = '';

  // Based on your ActivityLevelScreen options
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
          _heightController.text = userData['heightCm']?.toString() ?? '';
          _weightController.text = userData['weightKg']?.toString() ?? '';
          _selectedActivityLevel = userData['activityLevel'];
          // _hasDeviceConnected = userData['hasDeviceConnected'] as bool?; // Data still loaded if needed elsewhere, but UI removed

          if (_selectedActivityLevel != null && !_activityLevelOptions.contains(_selectedActivityLevel)) {
            // Handle if stored value is not in options
            // For example, if 'Active' (capitalized) was stored, convert or clear:
            if (_activityLevelDisplay.containsValue(_selectedActivityLevel)) {
              _selectedActivityLevel = _activityLevelDisplay.entries
                  .firstWhere((entry) => entry.value == _selectedActivityLevel, orElse: () => _activityLevelDisplay.entries.first)
                  .key;
            } else {
              // Or set to null if not found, so hintText shows
              // _selectedActivityLevel = null;
            }
          }
        }
      } else {
        _errorMessage = 'User profile data not found.';
      }
    } catch (e) {
      _errorMessage = 'Failed to load profile data: ${e.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
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
      'heightCm': int.tryParse(_heightController.text.trim()),
      'weightKg': double.tryParse(_weightController.text.trim()),
      'activityLevel': _selectedActivityLevel,
    };

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .update(dataToUpdate);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Physical information updated successfully!')),
      );
      if (mounted) { // Check if the widget is still in the tree
        Navigator.of(context).pop(); // Go back to profile screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update information: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Physical Information'),
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
                controller: _heightController,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your height';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number for height';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your weight';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number for weight';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedActivityLevel,
                decoration: const InputDecoration(labelText: 'Activity Level'),
                hint: const Text("Select Activity Level"), // Shows when value is null
                items: _activityLevelOptions
                    .map((level) => DropdownMenuItem(
                  value: level,
                  child: Text(_activityLevelDisplay[level] ?? level),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedActivityLevel = value;
                  });
                },
                validator: (value) {
                  // if (value == null || value.isEmpty) { // Optional: make activity level mandatory
                  //   return 'Please select your activity level';
                  // }
                  return null;
                },
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
              // REMOVED Device Status Section from here
              // const SizedBox(height: 24),
              // const Divider(),
              // const SizedBox(height: 16),
              // Text(
              //   'Device Status',
              //   style: Theme.of(context).textTheme.titleMedium,
              // ),
              // const SizedBox(height: 8),
              // Row(
              //   children: [
              //     Icon(
              //       _hasDeviceConnected == true ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              //       color: _hasDeviceConnected == true ? Colors.green : Colors.red,
              //       size: 20,
              //     ),
              //     const SizedBox(width: 8),
              //     Text(
              //       _hasDeviceConnected == true ? 'SmartVest Connected' : 'SmartVest Not Connected',
              //       style: TextStyle(
              //         fontSize: 16,
              //         color: _hasDeviceConnected == true ? Colors.green : Colors.red,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
