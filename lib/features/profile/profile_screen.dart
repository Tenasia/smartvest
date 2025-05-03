import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:smartvest/core/services/auth_service.dart'; // Your AuthService

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
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
      // Optionally navigate back to login
      // Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      final docSnapshot =
      await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (docSnapshot.exists) {
        setState(() {
          _userData = docSnapshot.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User profile data not found.';
          // Potentially navigate to welcome flow if profile is missing
          // Navigator.of(context).pushReplacementNamed('/welcome');
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load profile data. Please try again.';
      });
    }
  }

  // Helper to format Firestore Timestamp to readable date
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not set';
    try {
      return DateFormat.yMMMd().format(timestamp.toDate()); // Example format: Jan 1, 2024
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Helper widget to display profile info cleanly
  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle.isEmpty ? 'Not set' : subtitle),
      // Add trailing edit icon/button later if needed
    );
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut(context);
      // Navigate to login screen after sign out and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print("Sign out error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get photoUrl safely
    String? photoUrl = _userData?['photoURL'] ?? _currentUser?.photoURL;

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
          : _userData == null
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
          : RefreshIndicator( // Allow pull-to-refresh
        onRefresh: _loadUserData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null, // Use NetworkImage for URLs
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(Icons.person, size: 50) // Placeholder
                        : null,
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

            // Personal Information Section
            Text('Personal Information', style: Theme.of(context).textTheme.titleMedium),
            _buildInfoTile(Icons.person_outline, 'First Name', _userData?['firstName'] ?? ''),
            _buildInfoTile(Icons.person_outline, 'Middle Name', _userData?['middleName'] ?? ''),
            _buildInfoTile(Icons.person_outline, 'Last Name', _userData?['lastName'] ?? ''),
            _buildInfoTile(Icons.cake_outlined, 'Birthday', _formatDate(_userData?['birthday'] as Timestamp?)),
            _buildInfoTile(
                _userData?['gender'] == 'Male' ? Icons.male :
                _userData?['gender'] == 'Female' ? Icons.female :
                Icons.person_search, // Default icon if gender is not set or different
                'Gender',
                _userData?['gender'] ?? ''
            ),
            const SizedBox(height: 10),
            const Divider(),

            // Physical Information Section
            Text('Physical Information', style: Theme.of(context).textTheme.titleMedium),
            _buildInfoTile(Icons.height, 'Height', '${_userData?['heightCm'] ?? 'N/A'} cm'),
            _buildInfoTile(Icons.monitor_weight_outlined, 'Weight', '${_userData?['weightKg'] ?? 'N/A'} kg'),
            _buildInfoTile(Icons.directions_run, 'Activity Level', _userData?['activityLevel'] ?? ''),
            const SizedBox(height: 10),
            const Divider(),

            // Actions Section
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Search for SmartVest'),
              onPressed: () {
                // Navigate to the device search screen
                Navigator.pushNamed(context, '/search_device');
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)), // Full width
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'), // Placeholder
              onPressed: () {
                // TODO: Implement navigation to an edit profile screen or enable editing here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile functionality not yet implemented.')),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)), // Full width
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45), // Full width
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}