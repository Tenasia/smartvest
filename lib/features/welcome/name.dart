import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WelcomeNameScreen extends StatefulWidget {
  const WelcomeNameScreen({super.key});

  @override
  State<WelcomeNameScreen> createState() => _WelcomeNameScreenState();
}

class _WelcomeNameScreenState extends State<WelcomeNameScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

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
        title: const Text('Tell Us Your Name'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'What is your name?',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15.0),
            TextField(
              controller: _middleNameController,
              decoration: const InputDecoration(
                labelText: 'Middle Name (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15.0),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async { // Make the onPressed async
                  final firstName = _firstNameController.text.trim();
                  final lastName = _lastNameController.text.trim();
                  final middleName = _middleNameController.text.trim();

                  if (firstName.isNotEmpty && lastName.isNotEmpty) {
                    // Get the user
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      //update firestore
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({
                          'welcomeNameCompleted': true,
                          'firstName': firstName,
                          'middleName': middleName,
                          'lastName': lastName,
                        });
                        print("Firestore updated for welcomeNameCompleted");
                      } catch (e) {
                        print("Error updating Firestore: $e");
                      }
                    }
                    Navigator.pushReplacementNamed(context, '/welcomeGender');
                  } else {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your first and last name.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
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
          ],
        ),
      ),
    );
  }
}

