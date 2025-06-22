import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartvest/config/app_routes.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';

// --- Style Constants ---
const Color _scaffoldBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _primaryAppColor = Color(0xFF4A79FF);
const Color _heartIconColor = Color(0xFFF25C54);
const Color _oxygenIconColor = Color(0xFF27AE60);

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _statValueStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _statLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _heartRateBPMStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _heartIconColor);
const TextStyle _oxygenPercentStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _oxygenIconColor);
const TextStyle _unitStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: _secondaryTextColor);
const TextStyle _averageStyle = TextStyle(fontSize: 13, color: Color(0xFF666666));
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

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

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = ''; });

    await _fetchUserData();

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
            children: [
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
            children: [
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
      body: _isLoading
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
