import 'package:flutter/material.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color profileColor = Color(0xFF5667FD);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle metricValue = GoogleFonts.poppins(
      fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle metricUnit = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.secondaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.primaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w600);
}

// --- Firebase Health Data Models ---
class FirebaseHealthDataPoint {
  final DateTime timestamp;
  final double value;

  FirebaseHealthDataPoint({required this.timestamp, required this.value});
}

class FirebaseHealthStats {
  final double? min;
  final double? max;
  final double? avg;
  final FirebaseHealthDataPoint? latest;

  FirebaseHealthStats({this.min, this.max, this.avg, this.latest});
}

// --- Caching Logic ---
String _cachedSpo2Summary = "Generating summary...";
DateTime? _lastSpo2SummaryTimestamp;

class OxygenSaturationScreen extends StatefulWidget {
  const OxygenSaturationScreen({super.key});

  @override
  State<OxygenSaturationScreen> createState() => _OxygenSaturationScreenState();
}

class _OxygenSaturationScreenState extends State<OxygenSaturationScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int _selectedSegment = 0;
  bool _isLoading = true;

  List<FirebaseHealthDataPoint> _dataPoints = [];
  FirebaseHealthStats _stats = FirebaseHealthStats();
  String _aiSummary = _cachedSpo2Summary;
  DateTime? _chartStartTime;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _fetchDataForSegment();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if(mounted) _fetchDataForSegment();
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDataForSegment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted || user == null) return;

    setState(() { _isLoading = true; });

    final now = DateTime.now();
    DateTime startTime;
    switch (_selectedSegment) {
      case 0: startTime = now.subtract(const Duration(hours: 1)); break; // 1 hour
      case 1: startTime = DateTime(now.year, now.month, now.day); break; // Day
      case 2: startTime = now.subtract(const Duration(days: 7)); break; // Week
      case 3: startTime = now.subtract(const Duration(days: 30)); break; // Month
      default: startTime = now.subtract(const Duration(hours: 1));
    }
    _chartStartTime = startTime;

    try {
      // Get all data first, then filter by time
      final snapshot = await _dbRef
          .child('users/${user.uid}/healthData')
          .orderByChild('epochTime')
          .limitToLast(1000) // Get recent data
          .get();

      List<FirebaseHealthDataPoint> points = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          // Try both field name variations
          final epochTime = entry['epochTime'] as int? ?? entry['epoch_time'] as int?;
          final vitals = entry['vitals'] as Map<dynamic, dynamic>?;
          final spo2 = vitals?['oxygen_saturation'] as num?;

          if (epochTime != null && spo2 != null && spo2 > 0) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);

            // Filter by selected time period
            if (timestamp.isAfter(startTime) && timestamp.isBefore(now)) {
              points.add(FirebaseHealthDataPoint(
                timestamp: timestamp,
                value: spo2.toDouble(),
              ));
            }
          }
        });
      }

      points.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      double? min, max;
      double sum = 0;

      if (points.isNotEmpty) {
        for (var p in points) {
          sum += p.value;
          if (min == null || p.value < min) min = p.value;
          if (max == null || p.value > max) max = p.value;
        }
      }

      final currentStats = FirebaseHealthStats(
        min: min,
        max: max,
        avg: points.isEmpty ? 0 : sum / points.length,
        latest: points.isNotEmpty ? points.last : null,
      );

      if (mounted) {
        setState(() {
          _dataPoints = points;
          _stats = currentStats;
          _isLoading = false;
        });
        _generateAiSummary();
      }
    } catch (e) {
      print('Error fetching oxygen saturation data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastSpo2SummaryTimestamp != null &&
        DateTime.now().difference(_lastSpo2SummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) setState(() => _aiSummary = _cachedSpo2Summary);
      return;
    }
    if (_dataPoints.isEmpty) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }
    if (mounted) setState(() => _aiSummary = "Generating new summary...");

    User? user = FirebaseAuth.instance.currentUser;
    int? userAge;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('birthday')) {
          final birthday = (doc.data()!['birthday'] as Timestamp).toDate();
          userAge = DateTime.now().year - birthday.year;
        }
      } catch (e) {
        print('Error fetching user age: $e');
      }
    }

    final dataString = _dataPoints.map((point) =>
    "${point.value.toInt()}% at ${DateFormat.Hm().format(point.timestamp)}"
    ).join(', ');

    try {
      final summary = await _geminiService.getSummaryFromRawString(
        metricName: "Blood Oxygen (SpO2)",
        dataSummary: dataString,
        userAge: userAge,
        analysisInstructions: """Based on the blood oxygen saturation data (normal: 95-100%), provide:
        1. **Oxygen Status**: Overall assessment of oxygen saturation levels.
        2. **Key Observations**: Notable patterns or concerning readings.
        3. **Health Recommendations**: 2-3 actionable tips for respiratory health.""",
      );

      _cachedSpo2Summary = summary;
      _lastSpo2SummaryTimestamp = DateTime.now();
      if (mounted) setState(() => _aiSummary = summary);
    } catch (e) {
      print('Error generating AI summary: $e');
      if(mounted) setState(() => _aiSummary = "Unable to generate summary at this time.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Blood Oxygen', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        centerTitle: false,
      ),
      body: _isLoading && _dataPoints.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: <Widget>[
          const SizedBox(height: 16),
          _buildCurrentSpo2Card(),
          const SizedBox(height: 16),
          _buildGraphCard(),
          const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required Widget child, String? title}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: AppTextStyles.cardTitle),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildCurrentSpo2Card() {
    final latestPoint = _stats.latest;
    final spo2 = latestPoint != null ? latestPoint.value.toStringAsFixed(0) : "--";
    final time = latestPoint != null ? DateFormat('MMM d, hh:mm a').format(latestPoint.timestamp.toLocal()) : "No recent data";

    return _buildInfoCard(
      title: "Latest Reading",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              text: spo2,
              style: AppTextStyles.metricValue.copyWith(color: AppColors.oxygenColor),
              children: [TextSpan(text: ' %', style: AppTextStyles.metricUnit)],
            ),
          ),
          Text(time, style: AppTextStyles.secondaryInfo),
        ],
      ),
    );
  }

  Widget _buildGraphCard() {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSegmentedControl(),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.oxygenColor))
                : _dataPoints.isEmpty
                ? Center(child: Text("No data for this period.", style: AppTextStyles.secondaryInfo))
                : _buildLineChart(_chartStartTime!),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem('${_stats.max?.toStringAsFixed(0) ?? '--'}%', "Maximum"),
              _buildSummaryStatItem('${_stats.avg?.toStringAsFixed(0) ?? '--'}%', "Average"),
              _buildSummaryStatItem('${_stats.min?.toStringAsFixed(0) ?? '--'}%', "Minimum"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.profileColor, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text("AI Summary", style: AppTextStyles.cardTitle)),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.secondaryText),
                onPressed: () => _generateAiSummary(forceRefresh: true),
                tooltip: 'Refresh Summary',
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: _aiSummary,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: AppTextStyles.bodyText,
              listBullet: AppTextStyles.bodyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    final segments = ["1 Hour", "Day", "Week", "Month"];
    return Row(
      children: List.generate(segments.length, (index) {
        bool isSelected = _selectedSegment == index;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedSegment = index);
              _fetchDataForSegment();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.oxygenColor : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                segments[index],
                textAlign: TextAlign.center,
                style: AppTextStyles.buttonText.copyWith(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).expand((widget) => [widget, const SizedBox(width: 4)]).toList()..removeLast(),
    );
  }

  Widget _buildSummaryStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.cardTitle),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.secondaryInfo),
      ],
    );
  }

  Widget _buildLineChart(DateTime startTime) {
    final spots = _dataPoints.map((point) {
      final xValue = point.timestamp.millisecondsSinceEpoch.toDouble();
      return FlSpot(xValue, point.value);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 90,
        maxY: 100,
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: DateTime.now().millisecondsSinceEpoch.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.oxygenColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.oxygenColor.withOpacity(0.3), AppColors.oxygenColor.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 5,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${value.toInt()}%', style: AppTextStyles.secondaryInfo),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                String text;
                if (_selectedSegment == 0) { // 1 hour view
                  if (date.minute % 15 != 0) return Container(); // Show every 15 minutes
                  text = DateFormat.Hm().format(date);
                } else if (_selectedSegment == 1) { // Day view
                  if (date.hour % 6 != 0) return Container();
                  text = DateFormat.jm().format(date);
                } else { // Week/Month view
                  if (date.weekday != DateTime.monday && _selectedSegment == 2) return Container();
                  if (date.day % 7 != 1 && _selectedSegment == 3) return Container();
                  text = DateFormat.Md().format(date);
                }
                return SideTitleWidget(meta: meta, child: Text(text, style: AppTextStyles.secondaryInfo.copyWith(fontSize: 10)));
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.secondaryText.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)}%\n',
                  const TextStyle(color: AppColors.oxygenColor, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: DateFormat('MMM d, hh:mm a').format(date),
                      style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.white, fontSize: 12),
                    ),
                  ],
                  textAlign: TextAlign.center,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
