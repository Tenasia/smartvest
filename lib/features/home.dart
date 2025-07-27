import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Assuming these are defined in your project
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:smartvest/features/posture_screen.dart';
import 'package:smartvest/features/stress_level_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartvest/widgets/data_privacy_disclaimer.dart';

import 'heartrate_screen.dart';
import 'oxygen_saturation_screen.dart';

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
  final GeminiService _geminiService = GeminiService();
  Timer? _simulationTimer;
  final Random _random = Random();

  String _userName = "User"; // Default to "User"
  String? _profileImageUrl; // New variable for profile image URL
  bool _hasAgreedToDisclaimer = false; // New state variable

  // Simulated data
  double _heartRate = 80;
  double _spo2 = 98;
  int _rulaScore = 2;
  String _postureStatus = "Acceptable";
  double _gsrReading = 400;
  String _stressLevel = "Low";

  List<FlSpot> _heartRateData = [];
  List<FlSpot> _spo2Data = [];
  List<FlSpot> _postureData = [];
  List<FlSpot> _stressData = [];

  String _globalAiSummary = "Tap to generate your daily wellness summary.";
  bool _isGeneratingSummary = false;

  @override
  void initState() {
    super.initState();
    _checkDisclaimerStatus();
    _fetchUserName();
    _startDataSimulation();
  }

  Future<void> _checkDisclaimerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool('hasAgreedToDisclaimer') ?? false;
    if (!agreed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return DataPrivacyDisclaimer(
              onAgreed: () {
                setState(() {
                  _hasAgreedToDisclaimer = true;
                });
                Navigator.of(context).pop();
              },
            );
          },
        );
      });
    } else {
      setState(() {
        _hasAgreedToDisclaimer = true;
      });
    }
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userName = doc.data()!['firstName'] ?? "User";
          _profileImageUrl = doc.data()!['profileImageUrl'];
        });
      }
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startDataSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Simulate Heart Rate (60-120 bpm)
        _heartRate = 60 + _random.nextDouble() * 60;
        // Simulate SpO2 (95-100%)
        _spo2 = 95 + _random.nextDouble() * 5;
        // Simulate Posture (RULA Score 1-7)
        _rulaScore = 1 + _random.nextInt(7);
        _postureStatus = _getPostureStatus(_rulaScore);
        // Simulate Stress (GSR Reading mapped to levels)
        _gsrReading = 200 + _random.nextDouble() * 600;
        _stressLevel = _getStressLevel(_gsrReading);

        // Update chart data
        final now = DateTime.now().millisecondsSinceEpoch.toDouble();
        _heartRateData.add(FlSpot(now, _heartRate));
        _spo2Data.add(FlSpot(now, _spo2));
        _postureData.add(FlSpot(now, _rulaScore.toDouble()));
        _stressData.add(FlSpot(now, _gsrReading));

        // Keep chart data to a reasonable size (e.g., last 60 points)
        if (_heartRateData.length > 60) _heartRateData.removeAt(0);
        if (_spo2Data.length > 60) _spo2Data.removeAt(0);
        if (_postureData.length > 60) _postureData.removeAt(0);
        if (_stressData.length > 60) _stressData.removeAt(0);
      });
    });
  }

  String _getPostureStatus(int score) {
    if (score <= 2) return "Acceptable";
    if (score <= 4) return "Further Investigation";
    if (score <= 6) return "Investigate & Change";
    return "Change Immediately";
  }

  String _getStressLevel(double gsr) {
    if (gsr < 400) return "Low";
    if (gsr < 700) return "Medium";
    return "High";
  }

  Future<void> _generateGlobalAiSummary({bool forceRefresh = false}) async {
    if (_isGeneratingSummary) return;

    setState(() {
      _isGeneratingSummary = true;
      _globalAiSummary = "Analyzing your day's data...";
    });

    try {
      final promptData = StringBuffer();
      promptData.writeln("Analyze the following simulated daily health data for a user and provide a holistic summary, including a section for burnout prediction.");
      promptData.writeln("\n- Heart Rate: Fluctuating around ${_heartRate.toStringAsFixed(0)} BPM.");
      promptData.writeln("- Blood Oxygen: Stable around ${_spo2.toStringAsFixed(1)}%.");
      promptData.writeln("- Posture: Currently '${_postureStatus}'.");
      promptData.writeln("- Stress: Current level is '${_stressLevel}' (GSR: ${_gsrReading.toStringAsFixed(0)}).");
      promptData.writeln("\nProvide a summary that: \n1. Gives a friendly, overall status. \n2. Highlights any interesting simulated patterns. \n3. Offers one or two simple, actionable recommendations for tomorrow. \n4. **Burnout Prediction**: Based on the stress levels and any other relevant data, provide a brief assessment of potential burnout risk (e.g., Low, Medium, High) and suggest proactive measures. Use markdown for formatting.");

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Home Dashboard', style: AppTextStyles.heading),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_work_rounded, color: AppColors.primaryText),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.groupDashboardScreen),
            tooltip: 'Group Dashboard',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildBentoGrid(),
            const SizedBox(height: 16),
            _buildAiSummaryCard(),
          ],
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
          child: _buildPostureCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3,
          child: _buildStressCard(),
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
      ],
    );
  }

  Widget _buildSimulatedLineChart(List<FlSpot> data, Color lineColor) {
    if (data.isEmpty) {
      return Center(child: Text("No chart data.", style: AppTextStyles.secondaryInfo));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data,
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
                    backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                    child: _profileImageUrl == null
                        ? Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U', style: AppTextStyles.heading.copyWith(color: AppColors.profileColor))
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
                          _userName,
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
    return HealthMetricCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HeartRateScreen(hourlyData: _heartRateData),
        ),
      ),
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
                text: _heartRate.toStringAsFixed(0),
                style: AppTextStyles.metricValue.copyWith(color: AppColors.heartRateColor),
                children: [TextSpan(text: ' BPM', style: AppTextStyles.metricUnit)],
              ),
            ),
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildSimulatedLineChart(
                _heartRateData,
                AppColors.heartRateColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpo2Card() {
    return HealthMetricCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OxygenSaturationScreen(hourlyData: _spo2Data),
        ),
      ),
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
                text: _spo2.toStringAsFixed(0),
                style: AppTextStyles.metricValue.copyWith(color: AppColors.oxygenColor),
                children: [TextSpan(text: ' %', style: AppTextStyles.metricUnit)],
              ),
            ),
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildSimulatedLineChart(
                _spo2Data,
                AppColors.oxygenColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureCard() {
    return HealthMetricCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostureScreen(hourlyData: _postureData),
        ),
      ),
      title: "Posture",
      icon: Icons.accessibility_new_rounded,
      iconColor: AppColors.postureColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _postureStatus,
            style: AppTextStyles.metricValue.copyWith(color: AppColors.postureColor, fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSimulatedLineChart(
              _postureData,
              AppColors.postureColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressCard() {
    return HealthMetricCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StressLevelScreen(hourlyData: _stressData),
        ),
      ),
      title: "Stress",
      icon: Icons.bolt_rounded,
      iconColor: AppColors.stressColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stressLevel,
            style: AppTextStyles.metricValue.copyWith(color: AppColors.stressColor, fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSimulatedLineChart(
              _stressData,
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