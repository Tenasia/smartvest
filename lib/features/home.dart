import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    _user = _auth.currentUser;
    if (_user != null) {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
      await _firestore.collection('users').doc(_user!.uid).get();
      if (snapshot.exists) {
        setState(() {
          _userData = snapshot.data();
        });
      }
    }
  }

  // Helper function to calculate age from birthday Timestamp
  int? _calculateAge(Timestamp? birthdayTimestamp) {
    if (birthdayTimestamp == null) {
      return null;
    }
    DateTime birthday = birthdayTimestamp.toDate();
    DateTime today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }


  Widget _buildConnectDeviceNotice(String message) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to your device connection screen
                  Navigator.pushNamed(context, '/connect_device'); // Replace with your route
                },
                child: const Text('Connect Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDeviceConnected = _userData?['hasDeviceConnected'] ?? false;
    final bool previouslyHasDeviceConnected = _userData?['previouslyHasDeviceConnected'] ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton( // Changed from Icon to IconButton
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Add navigation functionality
          },
        ),
        title: Text('Welcome, ${_userData?['firstName'] ?? 'User'} ${_userData?['lastName'] ?? ''}'),
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always show user details regardless of device connection status
            _buildUserDetailsCard(),
            const SizedBox(height: 20),

            if (hasDeviceConnected) ...[
              _buildPostureCard(),
              const SizedBox(height: 20),
              _buildHeartRateCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildHrvCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStressLevelCard()),
                ],
              ),
              const SizedBox(height: 20),
              _buildDeviceCard(),
            ] else if (previouslyHasDeviceConnected && !hasDeviceConnected) ...[
              _buildConnectDeviceNotice('Your device is disconnected. Please reconnect to view your data.'),
              const SizedBox(height: 20),
              // Optionally show placeholders or less detailed versions of other cards
            ] else ...[
              _buildConnectDeviceNotice('Connect your device to start viewing your health data.'),
              const SizedBox(height: 20),
              // Optionally show empty state indicators for other cards
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailsCard() {
    // Access the data directly from _userData
    final String firstName = _userData?['firstName'] ?? '';
    final String lastName = _userData?['lastName'] ?? '';
    final Timestamp? birthdayTimestamp = _userData?['birthday'] as Timestamp?;
    final int? age = _calculateAge(birthdayTimestamp); // Calculate age
    final int? heightCm = _userData?['heightCm'] as int?;
    final double? weightKg = _userData?['weightKg'] as double?; // Assuming weight is stored as double

    return Card(
      margin: EdgeInsets.zero, // Adjust margin if needed
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(width: 16),
            Expanded( // Use Expanded to prevent overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  // Replace static location with data if available, otherwise use static or placeholder
                  // Text(_userData?['location'] ?? 'Location not set', style: const TextStyle(color: Colors.grey)),
                  const Text('Manila', style: TextStyle(color: Colors.grey)), // Keeping static as per original code

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute items
                    children: [
                      _buildDetailItem(age != null ? age.toString() : '--', 'Age'),
                      // Ensure null check and add units
                      _buildDetailItem(heightCm != null ? '$heightCm cm' : '--', 'Height'),
                      // Ensure null check and add units
                      _buildDetailItem(weightKg != null ? '${weightKg.toStringAsFixed(1)} kg' : '--', 'Weight'), // Format weight
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildPostureCard() {
    return Card(
      // ... (rest of your _buildPostureCard widget)
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Posture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            // ... (rest of the posture card content)
            Text('Good', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 8),
            LinearProgressIndicator(value: 0.8), // Example progress
            SizedBox(height: 8),
            Text('80% of the time', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateCard() {
    return Card(
      // ... (rest of your _buildHeartRateCard widget)
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Heart Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            // ... (rest of the heart rate card content)
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current', style: TextStyle(color: Colors.grey)),
                    Text('75 bpm', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resting Avg', style: TextStyle(color: Colors.grey)),
                    Text('68 bpm', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Placeholder for a chart
            Container(height: 100, color: Colors.blueGrey[50]),
          ],
        ),
      ),
    );
  }

  Widget _buildHrvCard() {
    return Card(
      // ... (rest of your _buildHrvCard widget)
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HRV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            // ... (rest of the HRV card content)
            Text('Excellent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 4),
            Text('Avg: 60 ms', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStressLevelCard() {
    return Card(
      // ... (rest of your _buildStressLevelCard widget)
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stress Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            // ... (rest of the stress level card content)
            Text('Low', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
            SizedBox(height: 4),
            Text('Score: 25', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Card(
      // ... (rest of your _buildDeviceCard widget)
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            // ... (rest of the device card content)
            Row(
              children: [
                Icon(Icons.watch),
                SizedBox(width: 8),
                Text('My Health Tracker (Connected)', style: TextStyle(fontSize: 16, color: Colors.green)),
              ],
            ),
            SizedBox(height: 8),
            Text('Last Sync: Just now', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}