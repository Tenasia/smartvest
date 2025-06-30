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
  static const Color heartRateColor = Color(0xFFF25C54);
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
String _cachedHeartRateSummary = "Generating summary...";
DateTime? _lastHeartRateSummaryTimestamp;

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int _selectedSegment = 0;
  bool _isLoading = true;

  List<FirebaseHealthDataPoint> _dataPoints = [];
  FirebaseHealthStats _stats = FirebaseHealthStats();
  String _aiSummary = _cachedHeartRateSummary;
  DateTime? _chartStartTime;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _fetchDataForSegment();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
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
      case 0: startTime = now.subtract(const Duration(hours: 1)); break; // Changed from day to 1 hour
      case 1: startTime = DateTime(now.year, now.month, now.day); break; // Day moved to position 1
      case 2: startTime = now.subtract(const Duration(days: 7)); break; // Week moved to position 2
      case 3: startTime = now.subtract(const Duration(days: 30)); break; // Month moved to position 3
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
          final heartRate = vitals?['heart_rate'] as num?;

          if (epochTime != null && heartRate != null && heartRate > 0) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);

            // Filter by selected time period
            if (timestamp.isAfter(startTime) && timestamp.isBefore(now)) {
              points.add(FirebaseHealthDataPoint(
                timestamp: timestamp,
                value: heartRate.toDouble(),
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
      print('Error fetching heart rate data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastHeartRateSummaryTimestamp != null &&
        DateTime.now().difference(_lastHeartRateSummaryTimestamp!) < const Duration(hours: 1)) {
      if(mounted) setState(() => _aiSummary = _cachedHeartRateSummary);
      return;
    }
    if (_dataPoints.isEmpty) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }
    if (mounted) setState(() => _aiSummary = "Generating new summary...");

    String timePeriodDescription;
    switch (_selectedSegment) {
      case 0: timePeriodDescription = "last 24 hours"; break;
      case 1: timePeriodDescription = "last 7 days"; break;
      case 2: timePeriodDescription = "last 30 days"; break;
      default: timePeriodDescription = "selected period";
    }

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

    // Convert Firebase data points to string for AI analysis
    final dataString = _dataPoints.map((point) =>
    "${point.value.toInt()} BPM at ${DateFormat.Hm().format(point.timestamp)}"
    ).join(', ');

    try {
      final summary = await _geminiService.getSummaryFromRawString(
        metricName: "Heart Rate",
        dataSummary: dataString,
        userAge: userAge,
        analysisInstructions: """Based on the heart rate data (normal resting: 60-100 BPM), provide:
        1. **Heart Rate Status**: Overall assessment of heart rate patterns.
        2. **Key Observations**: Notable peaks, valleys, or patterns in the data.
        3. **Health Recommendations**: 2-3 actionable tips for heart health.""",
      );

      _cachedHeartRateSummary = summary;
      _lastHeartRateSummaryTimestamp = DateTime.now();
      if(mounted) setState(() => _aiSummary = summary);
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
        title: Text('Heart Rate', style: AppTextStyles.heading),
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
          _buildCurrentHeartRateCard(),
          const SizedBox(height: 16),
          _buildHeartRateGraphCard(),
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

  Widget _buildCurrentHeartRateCard() {
    final latestPoint = _stats.latest;
    final bpm = latestPoint != null ? latestPoint.value.toStringAsFixed(0) : "--";
    final time = latestPoint != null ? DateFormat('MMM d, hh:mm a').format(latestPoint.timestamp.toLocal()) : "No recent data";

    return _buildInfoCard(
      title: "Latest Reading",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              text: bpm,
              style: AppTextStyles.metricValue.copyWith(color: AppColors.heartRateColor),
              children: [TextSpan(text: ' BPM', style: AppTextStyles.metricUnit)],
            ),
          ),
          Text(time, style: AppTextStyles.secondaryInfo),
        ],
      ),
    );
  }

  Widget _buildHeartRateGraphCard() {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSegmentedControl(),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.heartRateColor))
                : _dataPoints.isEmpty
                ? Center(child: Text("No data for this period.", style: AppTextStyles.secondaryInfo))
                : _buildBarChart(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem(_stats.max?.toStringAsFixed(0) ?? '--', "Maximum"),
              _buildSummaryStatItem(_stats.avg?.toStringAsFixed(0) ?? '--', "Average"),
              _buildSummaryStatItem(_stats.min?.toStringAsFixed(0) ?? '--', "Minimum"),
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
    final segments = ["1 Hour", "Day", "Week", "Month"]; // Updated segments
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
                color: isSelected ? AppColors.heartRateColor : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                segments[index],
                textAlign: TextAlign.center,
                style: AppTextStyles.buttonText.copyWith(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                  fontSize: 12, // Smaller font to fit 4 options
                ),
              ),
            ),
          ),
        );
      }).expand((widget) => [widget, const SizedBox(width: 4)]).toList()..removeLast(), // Reduced spacing
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

  Widget _buildBarChart() {
    bool isHourView = _selectedSegment == 0;
    bool isDayView = _selectedSegment == 1;
    List<BarChartGroupData> barGroups = [];

    if (isHourView) {
      // Group by 5-minute intervals for 1-hour view
      Map<int, List<double>> intervalData = {};
      for (var point in _dataPoints) {
        int intervalMinutes = (point.timestamp.minute ~/ 5) * 5; // Round to nearest 5 minutes
        int key = point.timestamp.hour * 100 + intervalMinutes; // Create unique key
        if (!intervalData.containsKey(key)) intervalData[key] = [];
        intervalData[key]!.add(point.value);
      }

      intervalData.forEach((key, values) {
        double avgValue = values.reduce((a, b) => a + b) / values.length;
        barGroups.add(BarChartGroupData(
            x: key,
            barRods: [BarChartRodData(
                toY: avgValue,
                color: AppColors.heartRateColor,
                width: 6,
                borderRadius: const BorderRadius.all(Radius.circular(2))
            )]
        ));
      });
    } else if (isDayView) {
      // Existing hourly logic for day view
      Map<int, List<double>> hourlyData = {};
      for (var point in _dataPoints) {
        int hour = point.timestamp.hour;
        if (!hourlyData.containsKey(hour)) hourlyData[hour] = [];
        hourlyData[hour]!.add(point.value);
      }
      for (int hour = 0; hour < 24; hour++) {
        double avgValue = hourlyData.containsKey(hour) &&
            hourlyData[hour]!.isNotEmpty
            ? hourlyData[hour]!.reduce((a, b) => a + b) /
            hourlyData[hour]!.length
            : 0;
        barGroups.add(BarChartGroupData(
            x: hour,
            barRods: [BarChartRodData(
                toY: avgValue,
                color: AppColors.heartRateColor,
                width: 8,
                borderRadius: const BorderRadius.all(Radius.circular(2))
            )]
        ));
      }
    } else {
      // Existing daily logic for week/month views
      Map<int, List<double>> dailyData = {};
      for (var point in _dataPoints) {
        int daysSinceStart = point.timestamp
            .difference(_chartStartTime!)
            .inDays;
        if (!dailyData.containsKey(daysSinceStart))
          dailyData[daysSinceStart] = [];
        dailyData[daysSinceStart]!.add(point.value);
      }
      dailyData.forEach((day, values) {
        double avgValue = values.reduce((a, b) => a + b) / values.length;
        barGroups.add(BarChartGroupData(
            x: day,
            barRods: [BarChartRodData(
                toY: avgValue,
                color: AppColors.heartRateColor,
                width: 12,
                borderRadius: const BorderRadius.all(Radius.circular(2))
            )]
        ));
      });
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_stats.max ?? 120) + 20,
        minY: (_stats.min ?? 40) - 20,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 30,
                  getTitlesWidget: (value, meta) =>
                      SideTitleWidget(
                          meta: meta,
                          child: Text(value.toInt().toString(),
                              style: AppTextStyles.secondaryInfo)
                      )
              )
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: isHourView ? 500 : (isDayView ? 6 : null),
              getTitlesWidget: (value, meta) {
                if (isHourView) {
                  int hour = value.toInt() ~/ 100;
                  int minute = value.toInt() % 100;
                  if (minute % 15 != 0) return Container(); // Show every 15 minutes
                  return SideTitleWidget(meta: meta,
                      child: Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                          style: AppTextStyles.secondaryInfo.copyWith(fontSize: 10)));
                } else if (isDayView) {
                  String text;
                  switch (value.toInt()) {
                    case 0: text = '12am'; break;
                    case 6: text = '6am'; break;
                    case 12: text = '12pm'; break;
                    case 18: text = '6pm'; break;
                    default: return Container();
                  }
                  return SideTitleWidget(meta: meta,
                      child: Text(text, style: AppTextStyles.secondaryInfo));
                } else {
                  final date = _chartStartTime!.add(
                      Duration(days: value.toInt()));
                  if (value.toInt() % (_selectedSegment == 2 ? 1 : 7) != 0) {
                    return Container();
                  }
                  return SideTitleWidget(meta: meta,
                      child: Text(DateFormat.Md().format(date),
                          style: AppTextStyles.secondaryInfo));
                }
              },
            ),
          ),
        ),
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 30,
            getDrawingHorizontalLine: (value) =>
                FlLine(
                    color: AppColors.secondaryText.withOpacity(0.1),
                    strokeWidth: 1
                )
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label;
              if (isHourView) {
                int hour = group.x.toInt() ~/ 100;
                int minute = group.x.toInt() % 100;
                label = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} - ${hour.toString().padLeft(2, '0')}:${(minute + 5).toString().padLeft(2, '0')}';
              } else if (isDayView) {
                label = '${group.x.toInt()}:00 - ${group.x.toInt() + 1}:00';
              } else {
                final date = _chartStartTime!.add(
                    Duration(days: group.x.toInt()));
                label = DateFormat.yMMMMd().format(date);
              }
              return BarTooltipItem(
                '$label\n',
                const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY).toStringAsFixed(0),
                    style: const TextStyle(color: AppColors.heartRateColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const TextSpan(
                    text: ' BPM',
                    style: TextStyle(color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
