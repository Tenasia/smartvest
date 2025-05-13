import 'dart:io'; // Required for File type

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:firebase_storage/firebase_storage.dart'; // For uploading images
import 'package:smartvest/core/services/auth_service.dart'; // Your AuthService

// Assuming you have this map defined for gender display,
// or you can define it here or in a shared constants file.
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
  final FirebaseStorage _storage = FirebaseStorage.instance; // Firebase Storage instance
  final ImagePicker _picker = ImagePicker(); // ImagePicker instance

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isDeviceActionLoading = false;
  bool _isUploadingImage = false; // For profile picture upload loading state

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
      if(mounted){
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
    final bool hasDeviceConnected = _userData?['hasDeviceConnected'] as bool? ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasDeviceConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          color: hasDeviceConnected ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          hasDeviceConnected ? 'SmartVest Connected' : 'SmartVest Not Connected',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SmartVest disconnected.')),
      );
      await _loadUserData();
    } catch (e) {
      print('Error disconnecting device: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to disconnect SmartVest: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeviceActionLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut(context);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print("Sign out error: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      return;
    }

    final ImageSource? source;
    try {
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
    } catch(e) {
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
            SnackBar(content: Text('Failed to pick image: ${e.toString()}'))
        );
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
    String fileName = '${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    Reference storageRef = _storage.ref().child('profile_pictures/$fileName');

    print("Attempting to upload to: ${storageRef.fullPath}");

    try {
      // 1. Upload the file
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      print("Upload Task completed. State: ${snapshot.state}");

      // Check if upload was successful before getting URL
      if (snapshot.state == TaskState.success) {
        print("File uploaded successfully to ${snapshot.ref.fullPath}. Attempting to get Download URL.");

        // 2. Get the download URL
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        print('Download URL: $downloadUrl');

        // 3. Update Firebase Auth
        await _currentUser!.updatePhotoURL(downloadUrl);
        print('Firebase Auth photoURL updated.');

        // 4. Update Firestore
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'photoURL': downloadUrl,
        });
        print('Firestore photoURL updated.');

        // 5. Refresh user data for UI
        await _currentUser!.reload();
        _currentUser = FirebaseAuth.instance.currentUser;
        await _loadUserData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      } else {
        // Handle other states like error, paused, canceled if needed, though await should throw for errors.
        print("Upload was not successful. State: ${snapshot.state}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed. State: ${snapshot.state}')),
          );
        }
      }
    } catch (e) {
      print("Error during image upload or URL retrieval: $e");
      if (e is FirebaseException && e.code == 'object-not-found') {
        print("Object not found specifically. This likely means rules are blocking or upload failed silently before getDownloadURL.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed: File not found. Please check Firebase Storage rules and try again.')),
          );
        }
      } else if (mounted) {
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


  @override
  Widget build(BuildContext context) {
    String? photoUrl = _userData?['photoURL'] ?? _currentUser?.photoURL;
    String? rawGender = _userData?['gender'] as String?;
    String displayGender = formatGenderForDisplay(rawGender);
    final bool hasDeviceConnected = _userData?['hasDeviceConnected'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
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
                const Text('Could not load profile data.'),
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
                    onTap: _isUploadingImage ? null : _updateProfilePicture,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        if (_isUploadingImage)
                          const CircularProgressIndicator(color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_userData?['firstName'] ?? ''} ${_userData?['middleName'] ?? ''} ${_userData?['lastName'] ?? ''}'.trim().replaceAll('  ', ' '),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _userData?['email'] ?? _currentUser?.email ?? 'No email',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),

            Text('Personal Information', style: Theme.of(context).textTheme.titleMedium),
            _buildInfoTile(Icons.person_outline, 'First Name', _userData?['firstName'] ?? ''),
            _buildInfoTile(Icons.person_outline, 'Middle Name', _userData?['middleName'] ?? ''),
            _buildInfoTile(Icons.person_outline, 'Last Name', _userData?['lastName'] ?? ''),
            _buildInfoTile(Icons.cake_outlined, 'Birthday', _formatDate(_userData?['birthday'] as Timestamp?)),
            _buildInfoTile(
                rawGender?.toLowerCase() == 'male' ? Icons.male :
                rawGender?.toLowerCase() == 'female' ? Icons.female :
                Icons.person_search,
                'Gender',
                displayGender
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Personal Information'),
              onPressed: () {
                Navigator.pushNamed(context, '/edit_personal_information').then((_) {
                  _loadUserData();
                });
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
            ),
            const SizedBox(height: 10),
            const Divider(),

            Text('Physical Information', style: Theme.of(context).textTheme.titleMedium),
            _buildInfoTile(Icons.height, 'Height', '${_userData?['heightCm'] ?? 'N/A'} cm'),
            _buildInfoTile(Icons.monitor_weight_outlined, 'Weight', '${_userData?['weightKg'] ?? 'N/A'} kg'),
            _buildInfoTile(Icons.directions_run, 'Activity Level', _userData?['activityLevel'] ?? ''),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Physical Information'),
              onPressed: () {
                Navigator.pushNamed(context, '/edit_physical_information').then((_) {
                  _loadUserData();
                });
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
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
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect SmartVest'),
                      onPressed: _disconnectDevice,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          minimumSize: const Size(200, 45)
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Search for SmartVest'),
                      onPressed: () {
                        Navigator.pushNamed(context, '/search_device');
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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
