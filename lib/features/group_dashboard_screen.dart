import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

// Reusing AppColors and AppTextStyles from home.dart for consistency
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color stressColor = Color(0xFFF2C94C);
  static const Color profileColor = Color(0xFF5667FD);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );
  static final TextStyle cardTitle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
  );
  static final TextStyle metricValue = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );
  static final TextStyle metricUnit = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
  );
}

class UserHealthData {
  final String name;
  final double heartRate;
  final double spo2;
  final String postureStatus;
  final String stressLevel;

  UserHealthData({
    required this.name,
    required this.heartRate,
    required this.spo2,
    required this.postureStatus,
    required this.stressLevel,
  });
}

class GroupDashboardScreen extends StatefulWidget {
  const GroupDashboardScreen({super.key});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  final Random _random = Random();

  List<UserHealthData> _simulatedUsers = [];

  // Simulated Group Data
  late double _avgHeartRate;
  late double _avgSpo2;
  late String _mostCommonPostureIssue;
  late String _overallStressLevel;
  late Map<String, int> _postureDistribution;
  late Map<String, int> _stressDistribution;

  @override
  void initState() {
    super.initState();
    _generateSimulatedUsers();
    _calculateGroupSummary();
  }

  void _generateSimulatedUsers() {
    final List<String> names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"];
    _simulatedUsers = List.generate(names.length, (index) {
      final heartRate = 60 + _random.nextDouble() * 60; // 60-120 BPM
      final spo2 = 95 + _random.nextDouble() * 5; // 95-100%
      final rulaScore = 1 + _random.nextInt(7); // 1-7
      final gsrReading = 200 + _random.nextDouble() * 600; // 200-800

      String postureStatus;
      if (rulaScore <= 2) postureStatus = "Good";
      else if (rulaScore <= 4) postureStatus = "Fair";
      else if (rulaScore <= 6) postureStatus = "Poor";
      else postureStatus = "Very Poor";

      String stressLevel;
      if (gsrReading < 400) stressLevel = "Low";
      else if (gsrReading < 700) stressLevel = "Medium";
      else stressLevel = "High";

      return UserHealthData(
        name: names[index],
        heartRate: heartRate,
        spo2: spo2,
        postureStatus: postureStatus,
        stressLevel: stressLevel,
      );
    });
  }

  void _calculateGroupSummary() {
    if (_simulatedUsers.isEmpty) {
      _avgHeartRate = 0;
      _avgSpo2 = 0;
      _mostCommonPostureIssue = "N/A";
      _overallStressLevel = "N/A";
      _postureDistribution = {};
      _stressDistribution = {};
      return;
    }

    double totalHeartRate = 0;
    double totalSpo2 = 0;
    Map<String, int> tempPostureDistribution = {};
    Map<String, int> tempStressDistribution = {};

    for (var user in _simulatedUsers) {
      totalHeartRate += user.heartRate;
      totalSpo2 += user.spo2;

      tempPostureDistribution[user.postureStatus] = (tempPostureDistribution[user.postureStatus] ?? 0) + 1;
      tempStressDistribution[user.stressLevel] = (tempStressDistribution[user.stressLevel] ?? 0) + 1;
    }

    _avgHeartRate = totalHeartRate / _simulatedUsers.length;
    _avgSpo2 = totalSpo2 / _simulatedUsers.length;

    _mostCommonPostureIssue = tempPostureDistribution.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    _overallStressLevel = tempStressDistribution.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    _postureDistribution = _normalizeDistribution(tempPostureDistribution);
    _stressDistribution = _normalizeDistribution(tempStressDistribution);
  }

  Map<String, int> _normalizeDistribution(Map<String, int> distribution) {
    final total = distribution.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return {};
    final normalized = <String, int>{};
    distribution.forEach((key, value) {
      normalized[key] = ((value / total) * 100).round();
    });
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Group Dashboard', style: AppTextStyles.heading),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDisclaimerCard(),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8, // Adjust as needed
              ),
              itemCount: _simulatedUsers.length,
              itemBuilder: (context, index) {
                return _buildUserHealthCard(_simulatedUsers[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHealthCard(UserHealthData user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.profileColor.withOpacity(0.2),
                child: Text(user.name[0].toUpperCase(), style: AppTextStyles.cardTitle.copyWith(color: AppColors.profileColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user.name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricRow("HR", "${user.heartRate.toStringAsFixed(0)} BPM", AppColors.heartRateColor),
          _buildMetricRow("SpO2", "${user.spo2.toStringAsFixed(1)}%", AppColors.oxygenColor),
          _buildMetricRow("Posture", user.postureStatus, AppColors.postureColor),
          _buildMetricRow("Stress", user.stressLevel, AppColors.stressColor),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text('$label: ', style: AppTextStyles.secondaryInfo.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: AppTextStyles.secondaryInfo, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Displaying simulated group data for demonstration purposes. Real-time group analytics require multiple connected devices and advanced data aggregation.",
              style: AppTextStyles.secondaryInfo.copyWith(color: Colors.amber[800]),
            ),
          ),
        ],
      ),
    );
  }
}
