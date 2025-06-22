import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// A data class to hold statistics for a given health metric.
class HealthStats {
  final double? min;
  final double? max;
  final double? avg;
  final HealthDataPoint? latest;

  HealthStats({this.min, this.max, this.avg, this.latest});
}

class HealthService {
  final Health health = Health();

  static final _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
  ];

  static final _permissions =
  _types.map((e) => HealthDataAccess.READ).toList();

  Future<bool> requestPermissions() async {
    // Request activity recognition permission first, as it's often a prerequisite.
    final activityPermissionStatus =
    await Permission.activityRecognition.request();
    if (activityPermissionStatus != PermissionStatus.granted) {
      debugPrint("Activity Recognition permission denied.");
      return false;
    }

    // Now request the specific health data permissions.
    return await health.requestAuthorization(_types, permissions: _permissions);
  }

  Future<List<HealthDataPoint>> getHealthData(
      DateTime startTime, DateTime endTime, HealthDataType type) async {
    try {
      final data = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [type],
      );
      // Remove duplicates before returning
      return health.removeDuplicates(data);
    } catch (e) {
      debugPrint("Error fetching health data for $type: $e");
      return [];
    }
  }

  Future<HealthStats> getStatsForToday(HealthDataType type) async {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day); // Start of today
    final dataPoints = await getHealthData(startTime, now, type);

    if (dataPoints.isEmpty) {
      return HealthStats(); // Return empty stats
    }

    // Sort by time to find the latest point easily.
    dataPoints.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    double sum = 0;
    double? min;
    double? max;

    for (var p in dataPoints) {
      final value = (p.value as NumericHealthValue).numericValue.toDouble();
      sum += value;
      if (min == null || value < min) {
        min = value;
      }
      if (max == null || value > max) {
        max = value;
      }
    }

    return HealthStats(
      min: min,
      max: max,
      avg: sum / dataPoints.length,
      latest: dataPoints.last,
    );
  }
}
