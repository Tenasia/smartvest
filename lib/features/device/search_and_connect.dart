import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchingDeviceScreen extends StatefulWidget {
  const SearchingDeviceScreen({super.key});

  @override
  State<SearchingDeviceScreen> createState() => _SearchingDeviceScreenState();
}

class _SearchingDeviceScreenState extends State<SearchingDeviceScreen> {
  bool _isSearching = true;
  bool _noDeviceFound = false;
  Timer? _searchTimeoutTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _hasInitializedDeviceFields = false;

  @override
  void initState() {
    super.initState();
    _initializeDeviceConnectionFields();
    // Simulate device searching for 5 seconds
    _searchTimeoutTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _isSearching = false;
        _noDeviceFound = true;
      });
    });
  }

  Future<void> _initializeDeviceConnectionFields() async {
    if (_user != null && !_hasInitializedDeviceFields) {
      try {
        await _firestore.collection('users').doc(_user.uid).update({
          'hasDeviceConnected': false,
          'previouslyHasDeviceConnected': false,
        });
        setState(() {
          _hasInitializedDeviceFields = true;
        });
        print("Initialized device connection fields for UID: ${_user.uid}");
      } catch (e) {
        print("Error initializing device connection fields: $e");
      }
    }
  }

  @override
  void dispose() {
    _searchTimeoutTimer?.cancel(); // Cancel the timer if the widget is disposed
    super.dispose();
  }

  // Method to update the device connection status to true
  Future<void> _markDeviceAsConnected() async {
    if (_user != null) {
      try {
        await _firestore.collection('users').doc(_user.uid).update({
          'hasDeviceConnected': true,
          'previouslyHasDeviceConnected': true,
        });
        print("Device marked as connected for UID: ${_user.uid}");
        // You might want to navigate to the next screen here
        Navigator.pushReplacementNamed(context, '/dashboard');
      } catch (e) {
        print("Error updating device connection status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true, // Keep the back button
        title: const Text(''), // Empty title
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isSearching) ...[
                const Text(
                  'Searching...',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10.0),
                const Text(
                  'Keep the device close to your phone.',
                  style: TextStyle(fontSize: 16.0, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30.0),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ] else if (_noDeviceFound) ...[
                const Text(
                  'No Device Nearby',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 10.0),
                const Text(
                  'Try again later.',
                  style: TextStyle(fontSize: 16.0, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15.0),
                      child: Text(
                        'Continue',
                        style: TextStyle(fontSize: 18.0),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // In a real scenario, you'd likely have logic here to handle successful device connection
                const Text('Device Found!'),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: _markDeviceAsConnected, // Call the method to update status
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15.0),
                    child: Text(
                      'Connect',
                      style: TextStyle(fontSize: 18.0),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20.0),
              if (_isSearching)
                OutlinedButton(
                  onPressed: () {
                    _searchTimeoutTimer?.cancel(); // Cancel the timer if user cancels
                    Navigator.pop(context); // Go back to the previous screen
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15.0),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 18.0, color: Colors.blue),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}