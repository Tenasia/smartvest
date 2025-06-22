import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:smartvest/models/chart_models.dart'; // Import the new models

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('healthMonitor');

  Stream<Map<String, dynamic>> getFirebaseDataStream(int limit) {
    return _dbRef.child('data').limitToLast(limit).onValue.map((event) {
      final Map<String, dynamic> allData = {};
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map;
        final posturePoints = <PostureDataPoint>[];
        final stressPoints = <StressDataPoint>[];

        data.forEach((key, value) {
          final entry = Map<String, dynamic>.from(value as Map);
          if (entry['timestamp'] == null) return;

          final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(entry['timestamp']));

          if (entry.containsKey('posture')) {
            posturePoints.add(PostureDataPoint(
              timestamp: timestamp,
              rulaScore: entry['posture']['rulaScore'] ?? 0,
              assessment: entry['posture']['rulaAssessment'] ?? 'N/A',
            ));
          }
          if (entry.containsKey('stress')) {
            stressPoints.add(StressDataPoint(
              timestamp: timestamp,
              gsrDeviation: entry['stress']['gsrDeviation'] ?? 0,
              stressLevel: entry['stress']['stressLevel'] ?? 'N/A',
            ));
          }
        });

        posturePoints.sort((a,b) => b.timestamp.compareTo(a.timestamp));
        stressPoints.sort((a,b) => b.timestamp.compareTo(a.timestamp));

        allData['latestPosture'] = posturePoints.isNotEmpty ? posturePoints.first : null;
        allData['latestStress'] = stressPoints.isNotEmpty ? stressPoints.first : null;
        allData['allPosture'] = posturePoints;
        allData['allStress'] = stressPoints;
      }
      return allData;
    });
  }
}
