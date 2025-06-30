import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// A data class to hold statistics for Firebase health data
class FirebaseHealthStats {
  final double? min;
  final double? max;
  final double? avg;
  final Map<dynamic, dynamic>? latest;
  final int count;

  FirebaseHealthStats({
    this.min,
    this.max,
    this.avg,
    this.latest,
    this.count = 0,
  });
}

class HealthService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Get health data from Firebase Realtime Database
  Future<List<Map<dynamic, dynamic>>> getFirebaseHealthData(
      DateTime startTime,
      DateTime endTime,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final startEpoch = startTime.millisecondsSinceEpoch ~/ 1000;
      final endEpoch = endTime.millisecondsSinceEpoch ~/ 1000;

      final snapshot = await _dbRef
          .child('users/${user.uid}/healthData')
          .orderByChild('epoch_time')
          .startAt(startEpoch)
          .endAt(endEpoch)
          .get();

      if (!snapshot.exists) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      List<Map<dynamic, dynamic>> healthDataList = [];

      data.forEach((key, value) {
        final entry = value as Map<dynamic, dynamic>;
        final epochTime = entry['epoch_time'] as int?;
        if (epochTime != null) {
          entry['key'] = key;
          entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
          healthDataList.add(entry);
        }
      });

      // Sort by timestamp
      healthDataList.sort((a, b) =>
          (a['parsedTimestamp'] as DateTime).compareTo(b['parsedTimestamp'] as DateTime));

      return healthDataList;
    } catch (e) {
      debugPrint("Error fetching Firebase health data: $e");
      return [];
    }
  }

  // Get heart rate statistics for a time period
  Future<FirebaseHealthStats> getHeartRateStats(DateTime startTime, DateTime endTime) async {
    final data = await getFirebaseHealthData(startTime, endTime);

    if (data.isEmpty) return FirebaseHealthStats();

    List<double> heartRates = [];
    Map<dynamic, dynamic>? latestEntry;
    DateTime? latestTime;

    for (var entry in data) {
      final heartRate = entry['vitals']?['heart_rate']?.toDouble();
      final timestamp = entry['parsedTimestamp'] as DateTime?;

      if (heartRate != null && heartRate > 0) {
        heartRates.add(heartRate);

        if (timestamp != null && (latestTime == null || timestamp.isAfter(latestTime))) {
          latestTime = timestamp;
          latestEntry = entry;
        }
      }
    }

    if (heartRates.isEmpty) return FirebaseHealthStats();

    return FirebaseHealthStats(
      min: heartRates.reduce((a, b) => a < b ? a : b),
      max: heartRates.reduce((a, b) => a > b ? a : b),
      avg: heartRates.reduce((a, b) => a + b) / heartRates.length,
      latest: latestEntry,
      count: heartRates.length,
    );
  }

  // Get blood oxygen statistics for a time period
  Future<FirebaseHealthStats> getBloodOxygenStats(DateTime startTime, DateTime endTime) async {
    final data = await getFirebaseHealthData(startTime, endTime);

    if (data.isEmpty) return FirebaseHealthStats();

    List<double> spo2Values = [];
    Map<dynamic, dynamic>? latestEntry;
    DateTime? latestTime;

    for (var entry in data) {
      final spo2 = entry['vitals']?['oxygen_saturation']?.toDouble();
      final timestamp = entry['parsedTimestamp'] as DateTime?;

      if (spo2 != null && spo2 > 0) {
        spo2Values.add(spo2);

        if (timestamp != null && (latestTime == null || timestamp.isAfter(latestTime))) {
          latestTime = timestamp;
          latestEntry = entry;
        }
      }
    }

    if (spo2Values.isEmpty) return FirebaseHealthStats();

    return FirebaseHealthStats(
      min: spo2Values.reduce((a, b) => a < b ? a : b),
      max: spo2Values.reduce((a, b) => a > b ? a : b),
      avg: spo2Values.reduce((a, b) => a + b) / spo2Values.length,
      latest: latestEntry,
      count: spo2Values.length,
    );
  }

  // Get posture statistics for a time period
  Future<FirebaseHealthStats> getPostureStats(DateTime startTime, DateTime endTime) async {
    final data = await getFirebaseHealthData(startTime, endTime);

    if (data.isEmpty) return FirebaseHealthStats();

    List<double> rulaScores = [];
    Map<dynamic, dynamic>? latestEntry;
    DateTime? latestTime;

    for (var entry in data) {
      final rulaScore = entry['posture']?['rula_score']?.toDouble();
      final timestamp = entry['parsedTimestamp'] as DateTime?;

      if (rulaScore != null && rulaScore > 0) {
        rulaScores.add(rulaScore);

        if (timestamp != null && (latestTime == null || timestamp.isAfter(latestTime))) {
          latestTime = timestamp;
          latestEntry = entry;
        }
      }
    }

    if (rulaScores.isEmpty) return FirebaseHealthStats();

    return FirebaseHealthStats(
      min: rulaScores.reduce((a, b) => a < b ? a : b),
      max: rulaScores.reduce((a, b) => a > b ? a : b),
      avg: rulaScores.reduce((a, b) => a + b) / rulaScores.length,
      latest: latestEntry,
      count: rulaScores.length,
    );
  }

  // Get stress statistics for a time period
  Future<FirebaseHealthStats> getStressStats(DateTime startTime, DateTime endTime) async {
    final data = await getFirebaseHealthData(startTime, endTime);

    if (data.isEmpty) return FirebaseHealthStats();

    List<double> gsrReadings = [];
    Map<dynamic, dynamic>? latestEntry;
    DateTime? latestTime;

    for (var entry in data) {
      final gsrReading = entry['stress']?['gsr_reading']?.toDouble();
      final timestamp = entry['parsedTimestamp'] as DateTime?;

      if (gsrReading != null && gsrReading >= 0) {
        gsrReadings.add(gsrReading);

        if (timestamp != null && (latestTime == null || timestamp.isAfter(latestTime))) {
          latestTime = timestamp;
          latestEntry = entry;
        }
      }
    }

    if (gsrReadings.isEmpty) return FirebaseHealthStats();

    return FirebaseHealthStats(
      min: gsrReadings.reduce((a, b) => a < b ? a : b),
      max: gsrReadings.reduce((a, b) => a > b ? a : b),
      avg: gsrReadings.reduce((a, b) => a + b) / gsrReadings.length,
      latest: latestEntry,
      count: gsrReadings.length,
    );
  }

  // Get today's statistics for all metrics
  Future<Map<String, FirebaseHealthStats>> getStatsForToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      getHeartRateStats(startOfDay, now),
      getBloodOxygenStats(startOfDay, now),
      getPostureStats(startOfDay, now),
      getStressStats(startOfDay, now),
    ]);

    return {
      'heartRate': results[0],
      'bloodOxygen': results[1],
      'posture': results[2],
      'stress': results[3],
    };
  }

  // Get the latest health data entry
  Future<Map<dynamic, dynamic>?> getLatestHealthData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snapshot = await _dbRef
          .child('users/${user.uid}/healthData')
          .orderByChild('epoch_time')
          .limitToLast(1)
          .get();

      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final entry = data.values.first as Map<dynamic, dynamic>;
      final epochTime = entry['epoch_time'] as int?;

      if (epochTime != null) {
        entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
      }

      return entry;
    } catch (e) {
      debugPrint("Error fetching latest health data: $e");
      return null;
    }
  }

  // Stream real-time health data updates
  Stream<Map<dynamic, dynamic>?> getHealthDataStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return _dbRef
        .child('users/${user.uid}/healthData')
        .orderByChild('epoch_time')
        .limitToLast(1)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return null;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final entry = data.values.first as Map<dynamic, dynamic>;
      final epochTime = entry['epoch_time'] as int?;

      if (epochTime != null) {
        entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
      }

      return entry;
    });
  }

  // Check if user has permission (always true for Firebase data)
  Future<bool> requestPermissions() async {
    // Since we're using Firebase instead of device health data,
    // we don't need special permissions
    return true;
  }
}
