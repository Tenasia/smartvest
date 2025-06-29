import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Assuming these are defined in your project
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:smartvest/core/services/gemini_service.dart';

// --- [1] CLEAN & MODERN DESIGN SYSTEM ---
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

// --- MAIN WIDGET ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HealthService _healthService = HealthService();
  final GeminiService _geminiService = GeminiService();

  User? _user;
  Map<String, dynamic>? _userData;

  HealthStats? _heartRateStats;
  List<HealthDataPoint> _heartRateDataPoints = [];
  HealthStats? _spo2Stats;
  List<HealthDataPoint> _spo2DataPoints = [];

  StreamSubscription? _healthMonitorSubscription;
  Map<dynamic, dynamic>? _latestHealthData;
  List<Map<dynamic, dynamic>> _recentFirebaseData = [];

  String _globalAiSummary = "Tap to generate your daily wellness summary.";
  bool _isGeneratingSummary = false;

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  @override
  void dispose() {
    _healthMonitorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _generateGlobalAiSummary({bool forceRefresh = false}) async {
    if (_isGeneratingSummary) return;

    if (_recentFirebaseData.isEmpty && _heartRateDataPoints.isEmpty && _spo2DataPoints.isEmpty) {
      if (mounted) setState(() => _globalAiSummary = "Not enough data to generate a summary for today.");
      return;
    }

    setState(() {
      _isGeneratingSummary = true;
      _globalAiSummary = "Analyzing your day's data...";
    });

    try {
      final promptData = StringBuffer();
      final userName = _userData?['firstName'] ?? 'User';
      promptData.writeln("Analyze the following daily health data for $userName and provide a holistic summary.");

      if (_heartRateStats != null && _heartRateStats!.avg != null) {
        promptData.writeln("\n- Heart Rate: Average of ${_heartRateStats!.avg!.toStringAsFixed(0)} BPM, Min of ${_heartRateStats!.min?.toStringAsFixed(0)}, Max of ${_heartRateStats!.max?.toStringAsFixed(0)}.");
      }
      if (_spo2Stats != null && _spo2Stats!.avg != null) {
        promptData.writeln("- Blood Oxygen: Average of ${_spo2Stats!.avg!.toStringAsFixed(1)}%, Min of ${_spo2Stats!.min?.toStringAsFixed(1)}, Max of ${_spo2Stats!.max?.toStringAsFixed(1)}.");
      }
      if (_recentFirebaseData.isNotEmpty) {
        final postureScores = _recentFirebaseData.where((d) => d['posture'] != null).map((d) => d['posture']['rulaScore']).toList();
        final stressScores = _recentFirebaseData.where((d) => d['stress'] != null).map((d) => d['stress']['gsrReading']).toList();
        if (postureScores.isNotEmpty) {
          promptData.writeln("- Posture: Recorded ${postureScores.length} posture readings. The RULA scores ranged from ${postureScores.reduce((a, b) => a < b ? a : b)} (best) to ${postureScores.reduce((a, b) => a > b ? a : b)} (worst).");
        }
        if (stressScores.isNotEmpty) {
          promptData.writeln("- Stress: Recorded ${stressScores.length} GSR readings, indicating fluctuations in stress levels throughout the day.");
        }
      }
      promptData.writeln("\nProvide a summary that: \n1. Gives a friendly, overall status. \n2. Highlights any correlations (e.g., 'stress levels seemed to rise when posture was poor'). \n3. Offers one or two simple, actionable recommendations for tomorrow. Use markdown for formatting.");

      // Use the new global summary method from the service
      final summary = await _geminiService.getGlobalSummary(promptData.toString());

      if (mounted) {
        setState(() {
          _globalAiSummary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _globalAiSummary = "Sorry, I couldn't generate a summary right now. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingSummary = false;
        });
      }
    }
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    await _fetchUserData();
    _initFirebaseRealtimeListener();
    bool permissionsGranted = await _healthService.requestPermissions();
    if (permissionsGranted) {
      await _fetchHealthData();
    } else {
      if (mounted) setState(() => _errorMessage = 'Health permissions not granted.');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUserData() async {
    _user = _auth.currentUser;
    if (_user != null) {
      try {
        final doc = await _firestore.collection('users').doc(_user!.uid).get();
        if (mounted && doc.exists) setState(() => _userData = doc.data());
      } catch (e) {
        if(mounted) setState(() => _errorMessage = 'Failed to load profile.');
      }
    }
  }

  void _initFirebaseRealtimeListener() {
    final databaseReference = FirebaseDatabase.instance.ref('healthMonitor/data');
    _healthMonitorSubscription?.cancel();
    _healthMonitorSubscription = databaseReference.limitToLast(50).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final dataMap = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<dynamic, dynamic>> tempList = [];

        dataMap.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          final epochSeconds = entry['epochTime'] as int? ?? int.tryParse(key.toString());
          if (epochSeconds != null) {
            entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
            tempList.add(entry);
          }
        });

        tempList.sort((a, b) => a['parsedTimestamp'].compareTo(b['parsedTimestamp']));

        if (tempList.isNotEmpty) {
          setState(() {
            _latestHealthData = tempList.last;
            _recentFirebaseData = tempList;
          });
        }
      }
    }, onError: (error) {
      if (mounted) setState(() => _errorMessage = "Failed to load sensor data.");
    });
  }

  Future<void> _fetchHealthData() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final hrStats = await _healthService.getStatsForToday(HealthDataType.HEART_RATE);
      final hrPoints = await _healthService.getHealthData(todayStart, now, HealthDataType.HEART_RATE);
      final spo2Stats = await _healthService.getStatsForToday(HealthDataType.BLOOD_OXYGEN);
      final spo2Points = await _healthService.getHealthData(todayStart, now, HealthDataType.BLOOD_OXYGEN);
      if (mounted) {
        setState(() {
          _heartRateStats = hrStats;
          _heartRateDataPoints = hrPoints;
          _spo2Stats = spo2Stats;
          _spo2DataPoints = spo2Points;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load health data.');
    }
  }

  bool _isDataFromToday(Map<dynamic, dynamic>? data) {
    if (data == null) return false;
    final timestamp = data['parsedTimestamp'];
    if (timestamp == null || timestamp is! DateTime) return false;
    final now = DateTime.now();
    return timestamp.year == now.year && timestamp.month == now.month && timestamp.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Home Dashboard', style: AppTextStyles.heading),
        actions: [],
      ),
      body: _isLoading && _userData == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : RefreshIndicator(
        onRefresh: _fetchAllData,
        color: AppColors.primaryText,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : Column(
            children: [
              _buildBentoGrid(),
              const SizedBox(height: 16),
              _buildAiSummaryCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoGrid() {
    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 0.9,
          child: _buildUserProfileCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3,
          child: _buildHeartRateCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3,
          child: _buildSpo2Card(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3,
          child: _buildPostureCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3,
          child: _buildStressCard(),
        ),
      ],
    );
  }

  Widget _buildSimpleBarChart(List<HealthDataPoint> data, Color barColor) {
    if (data.isEmpty) {
      return Center(child: Text("No chart data.", style: AppTextStyles.secondaryInfo));
    }
    final recentData = data.length > 24 ? data.sublist(data.length - 24) : data;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: recentData.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;
          final value = (point.value as NumericHealthValue).numericValue.toDouble();
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: barColor,
                width: 5,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFirebaseLineChart(List<Map<dynamic, dynamic>> data, String dataKey, String nestedKey, Color lineColor) {
    if (data.isEmpty) {
      return Center(child: Text("No chart data.", style: AppTextStyles.secondaryInfo));
    }

    final spots = data.map((entry) {
      final value = entry[dataKey]?[nestedKey]?.toDouble() ?? 0.0;
      final timestamp = (entry['parsedTimestamp'] as DateTime).millisecondsSinceEpoch.toDouble();
      return FlSpot(timestamp, value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard() {
    final String firstName = _userData?['firstName'] ?? 'User';
    String? photoUrl = _userData?['photoURL'] ?? _user?.photoURL;
    photoUrl = (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.profileColor, size: 24),
                const SizedBox(width: 8),
                Text("Profile", style: AppTextStyles.cardTitle),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.profileColor.withOpacity(0.2),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(firstName.isNotEmpty ? firstName[0] : 'U', style: AppTextStyles.heading.copyWith(color: AppColors.profileColor))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Hello,", style: AppTextStyles.secondaryInfo),
                        Text(
                          firstName,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateCard() {
    final currentBpm = _heartRateStats?.latest != null
        ? (_heartRateStats!.latest!.value as NumericHealthValue).numericValue.toStringAsFixed(0)
        : "--";

    return HealthMetricCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.heartRateScreen),
      title: "Heart rate",
      icon: Icons.favorite_rounded,
      iconColor: AppColors.heartRateColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                text: currentBpm,
                style: AppTextStyles.metricValue.copyWith(color: AppColors.heartRateColor),
                children: [TextSpan(text: ' BPM', style: AppTextStyles.metricUnit)],
              ),
            ),
          ),
          Text('Just now', style: AppTextStyles.secondaryInfo),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildSimpleBarChart(_heartRateDataPoints, AppColors.heartRateColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpo2Card() {
    final currentSpo2 = _spo2Stats?.latest != null
        ? (_spo2Stats!.latest!.value as NumericHealthValue).numericValue.toStringAsFixed(0)
        : "--";

    return HealthMetricCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.oxygenSaturationScreen),
      title: "Blood oxygen",
      icon: Icons.bloodtype_rounded,
      iconColor: AppColors.oxygenColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                text: currentSpo2,
                style: AppTextStyles.metricValue.copyWith(color: AppColors.oxygenColor),
                children: [TextSpan(text: ' %', style: AppTextStyles.metricUnit)],
              ),
            ),
          ),
          Text('Just now', style: AppTextStyles.secondaryInfo),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildSimpleBarChart(_spo2DataPoints, AppColors.oxygenColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureCard() {
    final bool hasDataForToday = _isDataFromToday(_latestHealthData);
    final postureData = hasDataForToday ? _latestHealthData!['posture'] : null;
    final String status = postureData?['rulaAssessment']?.replaceAll('_', ' ') ?? 'No Data';

    return HealthMetricCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.postureScreen),
      title: "Posture",
      icon: Icons.accessibility_new_rounded,
      iconColor: AppColors.postureColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: AppTextStyles.metricValue.copyWith(color: AppColors.postureColor, fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          const SizedBox(height: 8),
          Expanded(
            child: _buildFirebaseLineChart(
              _recentFirebaseData,
              'posture',
              'rulaScore',
              AppColors.postureColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressCard() {
    final bool hasDataForToday = _isDataFromToday(_latestHealthData);
    final stressData = hasDataForToday ? _latestHealthData!['stress'] : null;
    final String level = stressData?['stressLevel']?.replaceAll('_', ' ') ?? 'No Data';

    return HealthMetricCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.stressLevelScreen),
      title: "Stress",
      icon: Icons.bolt_rounded,
      iconColor: AppColors.stressColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            level,
            style: AppTextStyles.metricValue.copyWith(color: AppColors.stressColor, fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          const SizedBox(height: 8),
          Expanded(
            child: _buildFirebaseLineChart(
              _recentFirebaseData,
              'stress',
              'gsrReading',
              AppColors.stressColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    return GestureDetector(
      onTap: (_globalAiSummary.contains("Tap to generate") && !_isGeneratingSummary)
          ? () => _generateGlobalAiSummary(forceRefresh: true)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.profileColor, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text("Daily AI Summary", style: AppTextStyles.cardTitle.copyWith(fontSize: 16))),
                if (!_isGeneratingSummary)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: AppColors.secondaryText),
                    onPressed: () => _generateGlobalAiSummary(forceRefresh: true),
                    tooltip: 'Refresh Summary',
                  ),
              ],
            ),
            const Divider(height: 24, color: AppColors.background),
            if (_isGeneratingSummary)
              const Center(child: CircularProgressIndicator(color: AppColors.profileColor))
            else
              MarkdownBody(
                data: _globalAiSummary,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: AppTextStyles.secondaryInfo.copyWith(fontSize: 14, height: 1.5),
                  listBullet: AppTextStyles.secondaryInfo.copyWith(fontSize: 14, height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HealthMetricCard extends StatelessWidget {
  final Widget child;
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const HealthMetricCard({
    super.key,
    required this.child,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.cardTitle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}