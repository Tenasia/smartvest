// lib/features/profile/profile_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/auth_service.dart';

// Helper function to format gender for display
// This should be at the top level or as a static method.
const Map<String, String> _genderDisplayMap = {
  'male': 'Male',
  'female': 'Female',
  'other': 'Other',
  'prefer_not_to_say': 'Prefer not to say',
};

String formatGenderForDisplay(String? gender) {
  if (gender == null || gender.isEmpty) return 'Not set';
  String lowerCaseGender = gender.toLowerCase();
  return _genderDisplayMap[lowerCaseGender] ?? (gender[0].toUpperCase() + gender.substring(1));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isDeviceActionLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        if (!_isUploadingImage && !_isDeviceActionLoading) {
          _isLoading = true;
        }
        _errorMessage = '';
      });
    }

    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in.';
        });
      }
      return;
    }

    try {
      await _currentUser?.reload();
      _currentUser = FirebaseAuth.instance.currentUser;

      final docSnapshot =
      await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (docSnapshot.exists) {
        if (mounted) {
          setState(() {
            _userData = docSnapshot.data();
          });
        }
      } else {
        if (mounted) {
          _errorMessage = 'User profile data not found.';
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        _errorMessage = 'Failed to load profile data. Please try again.';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not set';
    try {
      return DateFormat.yMMMd().format(timestamp.toDate());
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? 'Not set' : subtitle),
    );
  }

  Widget _buildDeviceStatusIndicator() {
    final bool hasDeviceConnected =
        _userData?['hasDeviceConnected'] as bool? ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasDeviceConnected
              ? Icons.bluetooth_connected
              : Icons.bluetooth_disabled,
          color: hasDeviceConnected ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          hasDeviceConnected
              ? 'SmartVest Connected'
              : 'SmartVest Not Connected',
          style: TextStyle(
            fontSize: 16,
            color: hasDeviceConnected ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Future<void> _disconnectDevice() async {
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isDeviceActionLoading = true;
      });
    }
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'hasDeviceConnected': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SmartVest disconnected.')),
        );
      }
      await _loadUserData(); // Refresh data
    } catch (e) {
      print('Error disconnecting device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to disconnect SmartVest: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeviceActionLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("User not logged in.")));
      }
      return;
    }

    final ImageSource? source;
    try {
      if (!mounted) return;
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print("Error showing image source picker: $e");
      return;
    }

    if (source == null) {
      print("No image source selected");
      return;
    }

    final XFile? pickedFile;
    try {
      pickedFile = await _picker.pickImage(source: source);
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to pick image: ${e.toString()}')));
      }
      return;
    }

    if (pickedFile == null) {
      print("No file was picked.");
      return;
    }

    if (mounted) {
      setState(() {
        _isUploadingImage = true;
      });
    }

    File imageFile = File(pickedFile.path);
    String fileExtension = pickedFile.path.split('.').lastOrNull ?? 'jpg';
    String fileName =
        '${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    Reference storageRef = _storage.ref().child('profile_pictures/$fileName');

    try {
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        await _currentUser!.updatePhotoURL(downloadUrl);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({
          'photoURL': downloadUrl,
        });

        await _currentUser!.reload();
        _currentUser = FirebaseAuth.instance.currentUser;
        await _loadUserData(); // Reload data to update UI

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Profile picture updated successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Image upload failed. State: ${snapshot.state}')),
          );
        }
      }
    } catch (e) {
      print("Error during image upload or URL retrieval: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      print("ProfileScreen: Initiating sign out...");
      await _authService.signOut();
      print("ProfileScreen: Sign out from AuthService completed.");

      if (mounted) {
        print("ProfileScreen: Navigating to login screen.");
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      } else {
        print(
            "ProfileScreen: Widget not mounted after sign out, cannot navigate.");
      }
    } catch (e) {
      print("Error in ProfileScreen _signOut: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? photoUrl = _userData?['photoURL'] ?? _currentUser?.photoURL;
    String? rawGender = _userData?['gender'] as String?;
    String displayGender = formatGenderForDisplay(rawGender); // Corrected: Use top-level function
    final bool hasDeviceConnected = _userData?['hasDeviceConnected'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage, // Corrected: Added argument
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : _userData == null && !_isLoading
          ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load profile data.'), // Corrected: Added argument
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loadUserData,
                  child: const Text('Retry'),
                )
              ],
            ),
          ))
          : RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isUploadingImage
                        ? null
                        : _updateProfilePicture,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: (photoUrl != null &&
                              photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null ||
                              photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        if (_isUploadingImage)
                          const CircularProgressIndicator(
                              color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_userData?['firstName'] ?? ''} ${_userData?['middleName'] ?? ''} ${_userData?['lastName'] ?? ''}'
                        .trim()
                        .replaceAll('  ', ' '),
                    style:
                    Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _userData?['email'] ??
                        _currentUser?.email ??
                        'No email',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            Text('Personal Information',
                style: Theme.of(context).textTheme.titleMedium),
            _buildInfoTile(Icons.person_outline, 'First Name',
                _userData?['firstName'] ?? ''),
            _buildInfoTile(Icons.person_outline, 'Middle Name',
                _userData?['middleName'] ?? ''),
            _buildInfoTile(Icons.person_outline, 'Last Name',
                _userData?['lastName'] ?? ''),
            _buildInfoTile(
                Icons.cake_outlined,
                'Birthday',
                _formatDate(
                    _userData?['birthday'] as Timestamp?)),
            _buildInfoTile(
                rawGender?.toLowerCase() == 'male'
                    ? Icons.male
                    : rawGender?.toLowerCase() == 'female'
                    ? Icons.female
                    : Icons.person_search,
                'Gender',
                displayGender),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Personal Information'),
              onPressed: () {
                Navigator.pushNamed(context,
                    AppRoutes.editPersonalInformation)
                    .then((_) {
                  _loadUserData();
                });
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45)),
            ),
            const SizedBox(height: 10),
            const Divider(),
            Text('Physical Information',
                style: Theme.of(context).textTheme.titleMedium),
            _buildInfoTile(Icons.height, 'Height',
                '${_userData?['heightCm'] ?? 'N/A'} cm'),
            _buildInfoTile(
                Icons.monitor_weight_outlined,
                'Weight',
                '${_userData?['weightKg'] ?? 'N/A'} kg'),
            _buildInfoTile(Icons.directions_run,
                'Activity Level', _userData?['activityLevel'] ?? ''),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Physical Information'),
              onPressed: () {
                Navigator.pushNamed(context,
                    AppRoutes.editPhysicalInformation)
                    .then((_) {
                  _loadUserData();
                });
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45)),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  _buildDeviceStatusIndicator(),
                  const SizedBox(height: 16),
                  if (_isDeviceActionLoading)
                    const CircularProgressIndicator()
                  else if (hasDeviceConnected)
                    ElevatedButton.icon(
                      icon:
                      const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect SmartVest'),
                      onPressed: _disconnectDevice, // Corrected: Added onPressed
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          minimumSize: const Size(200, 45)),
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(
                          Icons.bluetooth_searching),
                      label:
                      const Text('Search for SmartVest'),
                      onPressed: () { // Corrected: Added onPressed
                        if (mounted) {
                          Navigator.pushNamed(context, AppRoutes.searchAndConnect);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 45)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out',
                  style: TextStyle(color: Colors.red)),
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}