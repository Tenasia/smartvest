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
        leading: const Icon(Icons.arrow_back),
        title: Text('Welcome, ${_userData?['firstName'] ?? 'User'} ${_userData?['lastName'] ?? ''}'),
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDeviceConnected) ...[
              _buildUserDetailsCard(),
              const SizedBox(height: 20),
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
              _buildUserDetailsCard(), // Still show basic user info
              // Optionally show placeholders or less detailed versions of other cards
            ] else ...[
              _buildConnectDeviceNotice('Connect your device to start viewing your health data.'),
              const SizedBox(height: 20),
              _buildUserDetailsCard(), // Still show basic user info
              // Optionally show empty state indicators for other cards
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailsCard() {
    return Card(
      // ... (rest of your _buildUserDetailsCard widget)
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Text('Manila', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildDetailItem('28', 'Age'),
                    const SizedBox(width: 16),
                    _buildDetailItem('${_userData?['heightCm'] ?? '--'} cm', 'Height'),
                    const SizedBox(width: 16),
                    _buildDetailItem('${_userData?['weightKg'] ?? '--'} kg', 'Weight'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String value, String label) {
    return Column(
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateCard() {
    return Card(
      // ... (rest of your _buildHeartRateCard widget)
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heart Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            // ... (rest of the heart rate card content)
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
          ],
        ),
      ),
    );
  }
}