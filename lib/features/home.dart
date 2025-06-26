import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart'; // Import for visual gauges

// --- Style Constants ---
const Color _scaffoldBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _primaryAppColor = Color(0xFF4A79FF);
const Color _heartIconColor = Color(0xFFF25C54);
const Color _oxygenIconColor = Color(0xFF27AE60);
const Color _postureIconColor = Color(0xFF007AFF);
const Color _stressIconColor = Color(0xFFFFA000);


final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _statValueStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _statLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _heartRateBPMStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _heartIconColor);
const TextStyle _oxygenPercentStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _oxygenIconColor);
const TextStyle _postureStatusStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _postureIconColor);
const TextStyle _stressStatusStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _stressIconColor);
const TextStyle _unitStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: _secondaryTextColor);
const TextStyle _averageStyle = TextStyle(fontSize: 13, color: Color(0xFF666666));
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _cardTitleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _secondaryTextColor);


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HealthService _healthService = HealthService();

  User? _user;
  Map<String, dynamic>? _userData;

  HealthStats? _heartRateStats;
  List<HealthDataPoint> _heartRateDataPoints = [];
  HealthStats? _spo2Stats;
  List<HealthDataPoint> _spo2DataPoints = [];

  // Firebase Realtime Database state
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
          // Add the key as 'epochTime' for consistent processing
          latestEntry['epochTime'] = int.tryParse(latestKey) ?? 0;
        }
        setState(() {
          _latestHealthData = latestEntry;
        });
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

  int? _calculateAge(Timestamp? birthdayTimestamp) {
    if (birthdayTimestamp == null) return null;
    final birthday = birthdayTimestamp.toDate();
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month || (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  /// Checks if the provided sensor data object has a timestamp from today.
  bool _isDataFromToday(Map<dynamic, dynamic>? data) {
    if (data == null) return false;
    // The new data has an 'epochTime' field with seconds since epoch.
    final epochSeconds = data['epochTime'];
    if (epochSeconds == null || epochSeconds is! int) {
      return false;
    }

    try {
      // Convert epoch seconds to milliseconds for DateTime constructor
      final dataTimestamp = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
      final now = DateTime.now();
      return dataTimestamp.year == now.year &&
          dataTimestamp.month == now.month &&
          dataTimestamp.day == now.day;
    } catch (e) {
      print("Error parsing timestamp in _isDataFromToday: $e");
      return false;
    }
  }


  // --- UI WIDGETS ---

  Widget _buildUserDetailsCard() {
    final String firstName = _userData?['firstName'] ?? 'User';
    final String location = "Manila, Philippines";
    String? photoUrl = _userData?['photoURL'] ?? _user?.photoURL;
    photoUrl = (photoUrl == null || photoUrl.isEmpty) ? "https://via.placeholder.com/100" : photoUrl;

    final int? age = _calculateAge(_userData?['birthday'] as Timestamp?);
    final int? heightCm = _userData?['heightCm'] as int?;
    final double? weightKg = _userData?['weightKg'] as double?;

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hello, $firstName!", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor)),
                      const SizedBox(height: 4),
                      Text(location, style: const TextStyle(fontSize: 14, color: _secondaryTextColor)),
                    ],
                  ),
                ),
                CircleAvatar(radius: 32, backgroundColor: Colors.grey.shade200, backgroundImage: NetworkImage(photoUrl)),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoStatItem(age != null ? age.toString() : '--', 'Age'),
                _buildInfoStatItem(heightCm != null ? '${heightCm}cm' : '--', 'Height'),
                _buildInfoStatItem(weightKg != null ? '${weightKg.toStringAsFixed(0)}kg' : '--', 'Weight'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInfoStatItem(String value, String label) => Column(
    children: [Text(value, style: _statValueStyle), const SizedBox(height: 2), Text(label, style: _statLabelStyle)],
  );

  Widget _buildLineChart(List<HealthDataPoint> data, Color lineColor) {
    if (data.isEmpty) return const Center(child: Text("No chart data.", style: _subtleTextStyle));
    final spots = data.map((p) => FlSpot((p.dateFrom.hour * 60 + p.dateFrom.minute).toDouble(), (p.value as NumericHealthValue).numericValue.toDouble())).toList();
    return LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: lineColor, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.2)))]));
  }

  Widget _buildHeartRateCard() {
    final currentBpm = _heartRateStats?.latest != null ? (_heartRateStats!.latest!.value as NumericHealthValue).numericValue.toStringAsFixed(0) : "--";
    final averageBpm = _heartRateStats?.avg != null ? _heartRateStats!.avg!.toStringAsFixed(0) : "--";

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.heartRateScreen),
      borderRadius: _cardBorderRadius,
      child: Card(
        elevation: _cardElevation, shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        child: Padding(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("HEART RATE", style: _cardTitleStyle.copyWith(color: _heartIconColor)),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.favorite_rounded, color: _heartIconColor, size: 50), const SizedBox(width: 12), Expanded(child: RichText(text: TextSpan(text: currentBpm, style: _heartRateBPMStyle, children: const [TextSpan(text: ' BPM', style: _unitStyle)])))]),
              const SizedBox(height: 12),
              RichText(text: TextSpan(text: '24-Hour Average: ', style: _averageStyle, children: [TextSpan(text: '$averageBpm BPM', style: _averageStyle.copyWith(fontWeight: FontWeight.bold))])),
              const SizedBox(height: 16),
              SizedBox(height: 120, child: _buildLineChart(_heartRateDataPoints, _heartIconColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpo2Card() {
    final currentSpo2 = _spo2Stats?.latest != null ? (_spo2Stats!.latest!.value as NumericHealthValue).numericValue.toStringAsFixed(0) : "--";
    final averageSpo2 = _spo2Stats?.avg != null ? _spo2Stats!.avg!.toStringAsFixed(0) : "--";

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.oxygenSaturationScreen),
      borderRadius: _cardBorderRadius,
      child: Card(
        elevation: _cardElevation, shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        child: Padding(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("BLOOD OXYGEN", style: _cardTitleStyle.copyWith(color: _oxygenIconColor)),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.bloodtype, color: _oxygenIconColor, size: 50), const SizedBox(width: 12), Expanded(child: RichText(text: TextSpan(text: currentSpo2, style: _oxygenPercentStyle, children: const [TextSpan(text: ' %', style: _unitStyle)])))]),
              const SizedBox(height: 12),
              RichText(text: TextSpan(text: '24-Hour Average: ', style: _averageStyle, children: [TextSpan(text: '$averageSpo2 %', style: _averageStyle.copyWith(fontWeight: FontWeight.bold))])),
              const SizedBox(height: 16),
              SizedBox(height: 120, child: _buildLineChart(_spo2DataPoints, _oxygenIconColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostureAngleDetails(Map<dynamic, dynamic> postureData) {
    final flexion = postureData['trunkFlexion']?.toDouble() ?? 0.0;
    final sideBend = postureData['trunkSideBend']?.toDouble() ?? 0.0;
    final twist = postureData['trunkTwist']?.toDouble() ?? 0.0;

    Widget angleRow(String label, double value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: _subtleTextStyle.copyWith(fontSize: 14)),
            Text('${value.toStringAsFixed(1)}°', style: _averageStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: [
        angleRow("Trunk Flexion", flexion),
        angleRow("Side Bend", sideBend),
        angleRow("Twist", twist),
      ],
    );
  }

  Widget _buildPostureCard() {
    // Check if the latest data is valid and from today.
    final bool hasDataForToday = _isDataFromToday(_latestHealthData);

    // If data is available, extract it. The check above ensures _latestHealthData is not null.
    final postureData = hasDataForToday ? _latestHealthData!['posture'] : null;
    final String status = postureData?['rulaAssessment'] ?? '...';
    final int score = postureData?['rulaScore'] ?? 0;
    final double progress = (score > 0) ? score / 7.0 : 0.0;

    Color progressColor;
    if (score <= 2) {
      progressColor = Colors.green;
    } else if (score <= 4) {
      progressColor = Colors.yellow.shade700;
    } else {
      progressColor = Colors.orange;
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.postureScreen),
      borderRadius: _cardBorderRadius,
      child: Card(
        elevation: _cardElevation,
        shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        child: Padding(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("POSTURE", style: _cardTitleStyle.copyWith(color: _postureIconColor)),
              const SizedBox(height: 8),
              if (!hasDataForToday)
                const Center(
                    heightFactor: 5,
                    child: Text("No data recorded today.", style: _subtleTextStyle))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.accessibility_new_rounded, color: _postureIconColor, size: 50),
                        const SizedBox(width: 12),
                        Expanded(child: Text(status, style: _postureStatusStyle)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text("RULA Score: $score", style: _averageStyle.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    // The 'hasDataForToday' check ensures postureData is not null here.
                    _buildPostureAngleDetails(postureData!),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStressCard() {
    // Check if the latest data is valid and from today.
    final bool hasDataForToday = _isDataFromToday(_latestHealthData);

    // If data is available, extract it.
    final stressData = hasDataForToday ? _latestHealthData!['stress'] : null;
    final String level = stressData?['stressLevel']?.replaceAll('_', ' ') ?? '...';
    final int gsrDeviation = stressData?['gsrDeviation']?.toInt() ?? 0;

    // Calculate a percentage based on deviation. Assume a deviation of 50 is "max" for visual purposes.
    final double percent = (gsrDeviation.abs() / 50.0).clamp(0.0, 1.0);

    Color stressColor;
    if (level == 'RELAXED') {
      stressColor = Colors.teal;
    } else if (level == 'MILD STRESS') {
      stressColor = Colors.orange.shade600;
    } else { // HIGH_STRESS or other
      stressColor = Colors.red.shade700;
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.stressLevelScreen),
      borderRadius: _cardBorderRadius,
      child: Card(
        elevation: _cardElevation,
        shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        child: Padding(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("STRESS", style: _cardTitleStyle.copyWith(color: _stressIconColor)),
              const SizedBox(height: 8),
              if (!hasDataForToday)
                const Center(
                    heightFactor: 5,
                    child: Text("No data recorded today.", style: _subtleTextStyle))
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(level, style: _stressStatusStyle, softWrap: true,),
                          const SizedBox(height: 8),
                          Text("GSR Deviation: $gsrDeviation", style: _averageStyle.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: CircularPercentIndicator(
                        radius: 45.0,
                        lineWidth: 10.0,
                        percent: percent,
                        center: Icon(Icons.bolt, color: stressColor, size: 30),
                        progressColor: stressColor,
                        backgroundColor: Colors.grey.shade300,
                        circularStrokeCap: CircularStrokeCap.round,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Welcome, ${_userData?['firstName'] ?? 'User'}'),
        backgroundColor: _scaffoldBgColor,
        elevation: 0,
        foregroundColor: _primaryTextColor,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      // Only show a full-screen loader on the very first load when user data is not yet available.
      body: _isLoading && _userData == null
          ? const Center(child: CircularProgressIndicator(color: _primaryAppColor))
          : RefreshIndicator(
        onRefresh: _fetchAllData,
        color: _primaryAppColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserDetailsCard(),
              const SizedBox(height: 8),
              _buildPostureCard(),
              const SizedBox(height: 16),
              _buildStressCard(),
              const SizedBox(height: 16),
              _buildHeartRateCard(),
              const SizedBox(height: 16),
              _buildSpo2Card(),
            ],
          ),
        ),
      ),
    );
  }
}