import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color profileColor = Color(0xFF5667FD);
  static const Color heartRateColor = Color(0xFFF25C54); // For destructive actions like sign out
  static const Color goodPostureZone = Color(0xFF27AE60); // For connected status
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white);
}
// --- END OF DESIGN SYSTEM ---

// Helper function (Unchanged)
const Map<String, String> _genderDisplayMap = {
  'male': 'Male', 'female': 'Female', 'other': 'Other', 'prefer_not_to_say': 'Prefer not to say',
};
String formatGenderForDisplay(String? gender) {
  if (gender == null || gender.isEmpty) return 'Not set';
  return _genderDisplayMap[gender.toLowerCase()] ?? (gender[0].toUpperCase() + gender.substring(1));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
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
    // ... Functionality is unchanged ...
    if (mounted) setState(() {
      if (!_isUploadingImage && !_isDeviceActionLoading) _isLoading = true;
      _errorMessage = '';
    });
    if (_currentUser == null) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'User not logged in.'; });
      return;
    }
    try {
      await _currentUser?.reload();
      _currentUser = FirebaseAuth.instance.currentUser;
      final docSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (docSnapshot.exists) {
        if (mounted) setState(() => _userData = docSnapshot.data());
      } else {
        if (mounted) _errorMessage = 'User profile data not found.';
      }
    } catch (e) {
      if (mounted) _errorMessage = 'Failed to load profile data. Please try again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          const SnackBar(content: Text('Smart Vest disconnected.')),
        );
      }
      await _loadUserData(); // Refresh data
    } catch (e) {
      print('Error disconnecting device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to disconnect Smart Vest: ${e.toString()}')),
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

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: ${e.toString()}')),
        );
      }
    }
  }

  // --- MODERNIZED UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
          : RefreshIndicator(
        onRefresh: _loadUserData,
        color: AppColors.primaryText,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            const SizedBox(height: 16),
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Personal Information',
              icon: Icons.person_rounded,
              onEdit: () => Navigator.pushNamed(context, AppRoutes.editPersonalInformation).then((_) => _loadUserData()),
              children: [
                _buildInfoRow('First Name', _userData?['firstName'] ?? 'Not set'),
                _buildInfoRow('Middle Name', _userData?['middleName'] ?? 'Not set'),
                _buildInfoRow('Last Name', _userData?['lastName'] ?? 'Not set'),
                _buildInfoRow('Birthday', _formatDate(_userData?['birthday'] as Timestamp?)),
                _buildInfoRow('Gender', formatGenderForDisplay(_userData?['gender'])),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Physical Information',
              icon: Icons.monitor_weight_rounded,
              onEdit: () => Navigator.pushNamed(context, AppRoutes.editPhysicalInformation).then((_) => _loadUserData()),
              children: [
                _buildInfoRow('Height', '${_userData?['heightCm'] ?? '--'} cm'),
                _buildInfoRow('Weight', '${_userData?['weightKg'] ?? '--'} kg'),
                _buildInfoRow('Activity Level', _userData?['activityLevel'] ?? 'Not set'),
              ],
            ),
            const SizedBox(height: 16),
            _buildDeviceCard(),
            const SizedBox(height: 16),
            _buildSignOutButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- MODERNIZED UI WIDGETS ---

  Widget _buildProfileHeader() {
    String? photoUrl = _userData?['photoURL'] ?? _currentUser?.photoURL;
    String fullName = '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? 'User'}'.trim();
    String email = _userData?['email'] ?? _currentUser?.email ?? 'No email';

    return Column(
      children: [
        GestureDetector(
          onTap: _isUploadingImage ? null : _updateProfilePicture,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.profileColor.withOpacity(0.1),
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(fullName[0], style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.profileColor))
                    : null,
              ),
              if (_isUploadingImage) const CircularProgressIndicator(color: Colors.white),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.cardBackground, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                  child: const Icon(Icons.edit, size: 20, color: AppColors.profileColor),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(fullName, style: AppTextStyles.heading.copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Text(email, style: AppTextStyles.secondaryInfo),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required VoidCallback onEdit, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.profileColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.secondaryText)),
            ],
          ),
          const Divider(height: 24, color: AppColors.background),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.secondaryInfo),
          Text(value, style: AppTextStyles.bodyText),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not set';
    try {
      return DateFormat.yMMMd().format(timestamp.toDate());
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildDeviceCard() {
    final bool hasDeviceConnected = _userData?['hasDeviceConnected'] as bool? ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasDeviceConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                color: hasDeviceConnected ? AppColors.goodPostureZone : AppColors.heartRateColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasDeviceConnected ? 'Smart Vest Connected' : 'Smart Vest Not Connected',
                style: AppTextStyles.bodyText.copyWith(color: hasDeviceConnected ? AppColors.goodPostureZone : AppColors.heartRateColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isDeviceActionLoading)
            const CircularProgressIndicator(color: AppColors.primaryText)
          else
            SizedBox(
              width: double.infinity,
              child: hasDeviceConnected
                  ? ElevatedButton.icon(
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Disconnect'),
                onPressed: _disconnectDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heartRateColor.withOpacity(0.1),
                  foregroundColor: AppColors.heartRateColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
                  : ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const Text('Search for Smart Vest'),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.searchAndConnect),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.profileColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out'),
        onPressed: _signOut,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: AppColors.heartRateColor,
          side: BorderSide(color: AppColors.heartRateColor.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}