import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database
import 'dart:async'; // For StreamSubscription

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic>? _sensorData;
  StreamSubscription<DatabaseEvent>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize the DatabaseReference.
    // Make sure your Firebase app is initialized in main.dart
    // The URL from your Firebase console is used to initialize Firebase an
    // the path you want to listen to (e.g. '/', or a specific child node)
    _databaseReference = FirebaseDatabase.instance
        .ref(); // Points to the root of your database

    // Listen to data changes from the root.
    // You might want to point to a more specific path if your data is nested
    // e.g., .ref("your_data_node_path")
    _dataSubscription = _databaseReference.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        // Convert keys to String if they are not already (Firebase keys are strings)
        final Map<String, dynamic> stringKeyedData = {};
        data.forEach((key, value) {
          stringKeyedData[key.toString()] = value;
        });
        setState(() {
          _sensorData = stringKeyedData;
        });
      } else {
        setState(() {
          _sensorData = {"message": "No data available or an error occurred."};
        });
      }
    }, onError: (error) {
      // Handle error
      print("Error fetching data: $error");
      setState(() {
        _sensorData = {"error": "Failed to load data."};
      });
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel(); // Cancel the subscription when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications / Sensor Data'),
      ),
      body: _sensorData == null
          ? const Center(child: CircularProgressIndicator())
          : _sensorData!.containsKey("error") || _sensorData!.containsKey("message")
          ? Center(child: Text(_sensorData!.values.first.toString()))
          : ListView.builder(
        itemCount: _sensorData!.keys.length,
        itemBuilder: (context, index) {
          String key = _sensorData!.keys.elementAt(index);
          var value = _sensorData![key];

          // Assuming the value is a Map containing sensor readings
          if (value is Map) {
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Timestamp/ID: $key', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    if (value.containsKey('accX'))
                      Text('accX: ${value['accX']}'),
                    if (value.containsKey('accY'))
                      Text('accY: ${value['accY']}'),
                    if (value.containsKey('accZ'))
                      Text('accZ: ${value['accZ']}'),
                    if (value.containsKey('gsr'))
                      Text('gsr: ${value['gsr']}'),
                    // Add more fields as needed
                  ],
                ),
              ),
            );
          } else {
            // Fallback for unexpected data structure
            return ListTile(
              title: Text('ID: $key'),
              subtitle: Text('Data: ${value.toString()}'),
            );
          }
        },
      ),
    );
  }
}