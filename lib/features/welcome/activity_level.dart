import 'package:flutter/material.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String? _selectedActivityLevel;

  Widget _buildActivityOption(String label, String imagePath, String value) {
    final bool isSelected = _selectedActivityLevel == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivityLevel = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              imagePath,
              height: 80.0, // Adjust image height as needed
            ),
            const SizedBox(height: 8.0),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Level'),
        automaticallyImplyLeading: true, // Keep the back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Activity Level',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Select your activity level.',
              style: TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 20.0),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15.0,
                mainAxisSpacing: 15.0,
                childAspectRatio: 1.0, // To make the grid items square
                children: <Widget>[
                  _buildActivityOption('Sedentary', 'assets/sedentary.png', 'sedentary'),
                  _buildActivityOption('Light Activity', 'assets/light_activity.png', 'light'),
                  _buildActivityOption('Active', 'assets/active.png', 'active'),
                  _buildActivityOption('Very Active', 'assets/very_active.png', 'very_active'),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedActivityLevel != null ? () {
                  // Access the selected activity level: _selectedActivityLevel
                  print('Selected Activity Level: $_selectedActivityLevel');
                  Navigator.pushReplacementNamed(context, '/heightAndWeight'); // Assuming the next page is '/welcome4'
                } : null,
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