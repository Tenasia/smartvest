import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart'; // Using Google Fonts for a modern feel
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // For the bento-style grid

// Assuming these are defined in your project
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/health_service.dart';

// --- [1] CLEAN & MODERN DESIGN SYSTEM ---
// A new design system inspired by modern health apps, featuring a light background,
// clean cards, and vibrant accent colors.
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);

  // Data-specific colors for icons and charts
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color stressColor = Color(0xFFF2C94C);
  static const Color profileColor = Color(0xFF5667FD);
}

class AppTextStyles {
  // Using 'Poppins' for a friendly and modern look.
  static final TextStyle heading = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );

  static final TextStyle cardTitle = GoogleFonts.poppins(
    fontSize: 14, // Adjusted for better fit
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
  // --- STATE MANAGEMENT & DATA LOGIC (UNCHANGED) ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HealthService _healthService = HealthService();

  User? _user;
  Map<String, dynamic>? _userData;

  HealthStats? _heartRateStats;
  List<HealthDataPoint> _heartRateDataPoints = [];
  HealthStats? _spo2Stats;
  List<HealthDataPoint> _spo2DataPoints = [];

  StreamSubscription? _healthMonitorSubscription;
  Map<dynamic, dynamic>? _latestHealthData;

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

  // All data fetching and calculation logic remains exactly the same.
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
    _healthMonitorSubscription = databaseReference.limitToLast(1).onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final String latestKey = data.keys.first;
        final latestEntry = data.values.first as Map<dynamic, dynamic>?;
        if (latestEntry != null) {
          latestEntry['epochTime'] = int.tryParse(latestKey) ?? 0;
        }
        setState(() => _latestHealthData = latestEntry);
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
    final epochSeconds = data['epochTime'];
    if (epochSeconds == null || epochSeconds is! int) return false;
    try {
      final dataTimestamp = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
      final now = DateTime.now();
      return dataTimestamp.year == now.year && dataTimestamp.month == now.month && dataTimestamp.day == now.day;
    } catch (e) {
      return false;
    }
  }

  // --- MODERNIZED UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Home Dashboard', style: AppTextStyles.heading),
        actions: [
        ],
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
              : _buildBentoGrid(),
        ),
      ),
    );
  }

  // --- MODERNIZED UI WIDGETS ---

  Widget _buildBentoGrid() {
    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 0.9, // Adjusted height
          child: _buildUserProfileCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3, // Adjusted height
          child: _buildHeartRateCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3, // Adjusted height
          child: _buildSpo2Card(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3, // Adjusted height
          child: _buildPostureCard(),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1.3, // Adjusted height
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

  // ** MODIFIED WIDGET FOR PROFILE CARD **
  // This widget now builds its own card structure to have a custom header layout.
  Widget _buildUserProfileCard() {
    final String firstName = _userData?['firstName'] ?? 'User';
    String? photoUrl = _userData?['photoURL'] ?? _user?.photoURL;
    photoUrl = (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl;

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to a detailed profile screen if it exists.
      },
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
            // Custom header with icon and title in a Row
            Row(
              children: [
                Icon(Icons.person, color: AppColors.profileColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  "Profile",
                  style: AppTextStyles.cardTitle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // The main content of the profile card
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.profileColor.withOpacity(0.2),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(firstName.isNotEmpty ? firstName[0] : 'U',
                        style: AppTextStyles.heading.copyWith(color: AppColors.profileColor))
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
      icon: Icons.favorite,
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
      icon: Icons.bloodtype,
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
    final String status = postureData?['rulaAssessment']?.replaceAll('_', ' ') ?? '...';

    return HealthMetricCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.postureScreen),
      title: "Posture",
      icon: Icons.accessibility_new,
      iconColor: AppColors.postureColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasDataForToday ? status : 'No data',
            style: AppTextStyles.metricValue.copyWith(color: AppColors.postureColor, fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('Live', style: AppTextStyles.secondaryInfo),
          const Spacer(),
          Center(
            child: Icon(Icons.align_vertical_bottom, size: 50, color: AppColors.postureColor.withOpacity(0.2)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStressCard() {
    final bool hasDataForToday = _isDataFromToday(_latestHealthData);
    final stressData = hasDataForToday ? _latestHealthData!['stress'] : null;
    final String level = stressData?['stressLevel']?.replaceAll('_', ' ') ?? '...';

    return HealthMetricCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.stressLevelScreen),
      title: "Stress",
      icon: Icons.bolt,
      iconColor: AppColors.stressColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasDataForToday ? level : 'No data',
            style: AppTextStyles.metricValue.copyWith(color: AppColors.stressColor, fontSize: 24),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Center(
            child: Icon(Icons.psychology, size: 50, color: AppColors.stressColor.withOpacity(0.2)),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// --- [2] REUSABLE HEALTH METRIC CARD WIDGET ---
// This widget creates the clean, rounded card style seen in the reference image.
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: AppTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
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
