import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  List<HealthDataPoint> _healthData = [];
  String _statusMessage = 'Initializing...';

  final health = Health();
  static final types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    await health.configure();

    final activityPermissionStatus = await Permission.activityRecognition.request();
    if (!mounted || activityPermissionStatus != PermissionStatus.granted) {
      setState(() {
        _statusMessage = 'Activity Recognition permission is required.';
      });
      return;
    }

    final permissions = types.map((e) => HealthDataAccess.READ).toList();
    bool requested = await health.requestAuthorization(types, permissions: permissions);

    // **BUG FIX HERE**
    if (requested) {
      try {
        final now = DateTime.now();
        final lastWeek = now.subtract(const Duration(days: 7));

        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: lastWeek,
          endTime: now,
          types: types,
        );

        if (mounted) {
          setState(() {
            _healthData = health.removeDuplicates(healthData);
            if (_healthData.isEmpty) {
              _statusMessage = 'No data found for the last 7 days.';
            } else {
              _statusMessage = '';
            }
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Error fetching data: $error';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _statusMessage = 'Health Connect permissions were not granted.';
        });
      }
    }
  }

  String _formatValue(HealthDataPoint p) {
    if (p.value is NumericHealthValue) {
      return (p.value as NumericHealthValue).numericValue.toStringAsFixed(2);
    }
    return p.value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          ),
        ],
      ),
      body: _statusMessage.isNotEmpty
          ? Center(child: Text(_statusMessage, textAlign: TextAlign.center))
          : ListView.builder(
        itemCount: _healthData.length,
        itemBuilder: (_, index) {
          HealthDataPoint p = _healthData[index];
          return ListTile(
            title: Text(
                "${p.typeString}: ${_formatValue(p)} ${p.unitString ?? ''}"),
            subtitle: Text('From: ${p.dateFrom}'),
          );
        },
      ),
    );
  }
}