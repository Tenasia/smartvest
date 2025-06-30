import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color stressColor = Color(0xFFF2C94C);
  static const Color temperatureColor = Color(0xFFE74C3C);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.primaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
}

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  List<Map<dynamic, dynamic>> _healthData = [];
  String _statusMessage = 'Initializing...';
  bool _isLoading = false;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted || user == null) {
      setState(() {
        _statusMessage = 'Please log in to view health data.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching data from Firebase...';
    });

    try {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));

      final snapshot = await _dbRef
          .child('users/${user.uid}/healthData')
          .orderByChild('epochTime')
          .startAt(lastWeek.millisecondsSinceEpoch ~/ 1000)
          .endAt(now.millisecondsSinceEpoch ~/ 1000)
          .get();

      List<Map<dynamic, dynamic>> healthData = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          final epochTime = entry['epochTime'] as int?;
          if (epochTime != null) {
            entry['timestamp'] = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
            healthData.add(entry);
          }
        });
      }

      // Sort by timestamp (newest first)
      healthData.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      if (mounted) {
        setState(() {
          _healthData = healthData;
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

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatHealthData(Map<dynamic, dynamic> data) {
    List<String> parts = [];

    // Heart Rate
    final heartRate = data['vitals']?['heart_rate'];
    if (heartRate != null) {
      parts.add('Heart Rate: ${heartRate.toInt()} BPM');
    }

    // Oxygen Saturation
    final spo2 = data['vitals']?['oxygen_saturation'];
    if (spo2 != null) {
      parts.add('SpO2: ${spo2.toInt()}%');
    }

    // Temperature
    final temperature = data['temperature'];
    if (temperature != null) {
      parts.add('Temperature: ${temperature.toStringAsFixed(1)}°C');
    }

    // Posture
    final posture = data['posture'];
    if (posture != null) {
      final rulaScore = posture['rulaScore'];
      final assessment = posture['rulaAssessment'];
      if (rulaScore != null && assessment != null) {
        parts.add('Posture: $assessment (Score: $rulaScore)');
      }
    }

    // Stress
    final stress = data['stress'];
    if (stress != null) {
      final gsrReading = stress['gsrReading'];
      final stressLevel = stress['stressLevel'];
      if (gsrReading != null && stressLevel != null) {
        parts.add('Stress: $stressLevel (GSR: $gsrReading)');
      }
    }

    return parts.isEmpty ? 'No health metrics available' : parts.join(' • ');
  }

  Color _getCardColor(Map<dynamic, dynamic> data) {
    // Determine card color based on data type priority
    if (data['vitals']?['heart_rate'] != null) return AppColors.heartRateColor;
    if (data['vitals']?['oxygen_saturation'] != null) return AppColors.oxygenColor;
    if (data['temperature'] != null) return AppColors.temperatureColor;
    if (data['posture'] != null) return AppColors.postureColor;
    if (data['stress'] != null) return AppColors.stressColor;
    return AppColors.primaryText;
  }

  IconData _getCardIcon(Map<dynamic, dynamic> data) {
    if (data['vitals']?['heart_rate'] != null) return Icons.favorite_rounded;
    if (data['vitals']?['oxygen_saturation'] != null) return Icons.bloodtype_rounded;
    if (data['temperature'] != null) return Icons.thermostat_rounded;
    if (data['posture'] != null) return Icons.accessibility_new_rounded;
    if (data['stress'] != null) return Icons.bolt_rounded;
    return Icons.health_and_safety_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Health Data', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : _statusMessage.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                size: 60,
                color: AppColors.secondaryText.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryText,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _healthData.length,
        itemBuilder: (_, index) {
          final data = _healthData[index];
          final timestamp = data['timestamp'] as DateTime;
          final color = _getCardColor(data);
          final icon = _getCardIcon(data);

          return Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatHealthData(data),
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recorded: ${DateFormat('MMM d, yyyy • hh:mm a').format(timestamp.toLocal())}',
                        style: AppTextStyles.secondaryInfo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
