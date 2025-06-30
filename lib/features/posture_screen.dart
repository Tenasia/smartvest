import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color profileColor = Color(0xFF5667FD);
  static const Color goodPostureZone = Color(0xFF27AE60);
  static const Color warningPostureZone = Color(0xFFF2C94C);
  static const Color poorPostureZone = Color(0xFFF25C54);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle metricValue = GoogleFonts.poppins(
      fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText);
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
String _cachedPostureSummary = "Generating summary...";
DateTime? _lastPostureSummaryTimestamp;

class PostureScreen extends StatefulWidget {
  const PostureScreen({super.key});
  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int _selectedSegment = 0;
  bool _isLoading = true;

  List<FirebaseHealthDataPoint> _dataPoints = [];
  FirebaseHealthStats _stats = FirebaseHealthStats();
  String _aiSummary = _cachedPostureSummary;
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
          final posture = entry['posture'] as Map<dynamic, dynamic>?;
          final rulaScore = posture?['rula_score'] as num?;

          if (epochTime != null && rulaScore != null && rulaScore > 0) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);

            // Filter by selected time period
            if (timestamp.isAfter(startTime) && timestamp.isBefore(now)) {
              points.add(FirebaseHealthDataPoint(
                timestamp: timestamp,
                value: rulaScore.toDouble(),
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
      print('Error fetching posture data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastPostureSummaryTimestamp != null &&
        DateTime.now().difference(_lastPostureSummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) setState(() => _aiSummary = _cachedPostureSummary);
      return;
    }
    if (_dataPoints.isEmpty || !mounted) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }
    if (mounted) setState(() { _aiSummary = "Generating new summary..."; });

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

    final dataSummaryString = _dataPoints.map((point) {
      final time = DateFormat.Hm().format(point.timestamp);
      return "Score ${point.value.toInt()} at $time";
    }).join(', ');

    const analysisInstructions = """Based on the data (RULA scores from 1-7, where 1 is best and 7 is worst), provide:
      1. **Posture Status**: A one-sentence summary of the user's overall posture during this period.
      2. **Key Observations**: Mention any times of particularly good or poor posture. Note any patterns you see.
      3. **Actionable Recommendations**: Offer 2-3 simple, friendly tips to improve posture, like taking breaks or stretching.""";

    try {
      final summary = await _geminiService.getSummaryFromRawString(
        metricName: "Posture (RULA Score)",
        dataSummary: dataSummaryString,
        userAge: userAge,
        analysisInstructions: analysisInstructions,
      );

      _cachedPostureSummary = summary;
      _lastPostureSummaryTimestamp = DateTime.now();
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
        title: Text('Posture', style: AppTextStyles.heading),
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
          _buildCurrentPostureCard(),
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

  Widget _buildCurrentPostureCard() {
    final latestPoint = _stats.latest;
    final score = latestPoint != null ? latestPoint.value.toStringAsFixed(0) : '--';
    final time = latestPoint != null
        ? DateFormat('MMM d, hh:mm a').format(latestPoint.timestamp.toLocal())
        : "No recent data";

    // Get assessment from score
    String assessment = "No Data";
    if (latestPoint != null) {
      final scoreInt = latestPoint.value.toInt();
      if (scoreInt <= 2) assessment = "Good Posture";
      else if (scoreInt <= 4) assessment = "Fair Posture";
      else if (scoreInt <= 6) assessment = "Poor Posture";
      else assessment = "Very Poor";
    }

    return _buildInfoCard(
      title: "Latest Reading",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  text: assessment,
                  style: AppTextStyles.metricValue.copyWith(color: AppColors.postureColor, fontSize: 28),
                  children: [TextSpan(text: ' (Score: $score)', style: AppTextStyles.metricUnit)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.postureColor))
                : _dataPoints.isEmpty
                ? Center(child: Text("No data for this period.", style: AppTextStyles.secondaryInfo))
                : _buildChart(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem(_stats.max?.toStringAsFixed(0) ?? '--', "Worst"),
              _buildSummaryStatItem(_stats.avg?.toStringAsFixed(1) ?? '--', "Average"),
              _buildSummaryStatItem(_stats.min?.toStringAsFixed(0) ?? '--', "Best"),
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
                color: isSelected ? AppColors.postureColor : AppColors.background,
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

  Widget _buildChart() {
    if (_dataPoints.isEmpty) return Container();

    final spots = _dataPoints.map((point) {
      final timestamp = point.timestamp.millisecondsSinceEpoch.toDouble();
      return FlSpot(timestamp, point.value);
    }).toList();

    final startTime = _chartStartTime!;
    final endTime = DateTime.now();

    return LineChart(
      LineChartData(
        minY: 1, maxY: 7,
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: endTime.millisecondsSinceEpoch.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.postureColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.postureColor.withOpacity(0.3), AppColors.postureColor.withOpacity(0.0)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 2,
              getTitlesWidget: (value, meta) {
                if(value > 7 || value < 1) return Container();
                return SideTitleWidget(meta: meta, child: Text(value.toInt().toString(), style: AppTextStyles.secondaryInfo));
              },
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
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.secondaryText.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Score: ${spot.y.toStringAsFixed(1)}\n',
                  const TextStyle(color: AppColors.postureColor, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: DateFormat('MMM d, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt())),
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
