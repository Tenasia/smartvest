import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GenderAndBirthdayScreen extends StatefulWidget {
  const GenderAndBirthdayScreen({super.key});

  @override
  State<GenderAndBirthdayScreen> createState() => _GenderAndBirthdayScreenState();
}

class _GenderAndBirthdayScreenState extends State<GenderAndBirthdayScreen> {
  String? _selectedGender;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Gender'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Select your gender',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = 'female';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15.0),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'female'
                          ? Colors.blue
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.female,
                          size: 40.0,
                          color: _selectedGender == 'female'
                              ? Colors.white
                              : Colors.blueGrey,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Female',
                          style: TextStyle(
                            color: _selectedGender == 'female'
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = 'male';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15.0),
                    decoration: BoxDecoration(
                      color:
                      _selectedGender == 'male' ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.male,
                          size: 40.0,
                          color: _selectedGender == 'male'
                              ? Colors.white
                              : Colors.blueGrey,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Male',
                          style: TextStyle(
                            color: _selectedGender == 'male'
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30.0),
            const Text(
              'Date of Birth',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10.0),
            const Text(
              'Choose your birth date',
              style: TextStyle(fontSize: 16.0),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                },
              ),
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedGender != null
                    ? () async { // Make onPressed async
                  // Access selected gender and _selectedDate here
                  print('Selected Gender: $_selectedGender');
                  print('Selected Date: $_selectedDate');

                  //get user
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    //update firestore
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'welcomeGenderCompleted': true,
                        'gender': _selectedGender, // Store gender
                        'birthday': _selectedDate, // Store birthday
                      });
                      print("Firestore updated for welcomeGenderCompleted");
                    } catch (e) {
                      print("Error updating Firestore: $e");
                    }
                  }
                  Navigator.pushReplacementNamed(
                      context, '/activityLevel');
                }
                    : null,
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

