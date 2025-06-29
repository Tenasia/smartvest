import 'package:flutter/material.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color profileColor = Color(0xFF5667FD); // For AI/intellectual features
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
// --- END OF DESIGN SYSTEM ---

// --- Caching Logic (Unchanged) ---
String _cachedHeartRateSummary = "Generating summary...";
DateTime? _lastHeartRateSummaryTimestamp;


class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
  final HealthService _healthService = HealthService();
  final GeminiService _geminiService = GeminiService();
  int _selectedSegment = 0;
  bool _isLoading = true;

  List<HealthDataPoint> _dataPoints = [];
  HealthStats _stats = HealthStats();
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
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final now = DateTime.now();
    DateTime startTime;

    switch (_selectedSegment) {
      case 0: startTime = DateTime(now.year, now.month, now.day); break;
      case 1: startTime = now.subtract(const Duration(days: 7)); break;
      case 2: startTime = now.subtract(const Duration(days: 30)); break;
      default: startTime = DateTime(now.year, now.month, now.day);
    }
    _chartStartTime = startTime;

    final points = await _healthService.getHealthData(startTime, now, HealthDataType.HEART_RATE);

    double? min, max;
    double sum = 0;

    if (points.isNotEmpty) {
      points.sort((a,b) => a.dateFrom.compareTo(b.dateFrom));
      for (var p in points) {
        final value = (p.value as NumericHealthValue).numericValue.toDouble();
        sum += value;
        if (min == null || value < min) min = value;
        if (max == null || value > max) max = value;
      }
    }

    final currentStats = HealthStats(
      min: min, max: max, avg: points.isEmpty ? 0 : sum / points.length,
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('birthday')) {
        final birthday = (doc.data()!['birthday'] as Timestamp).toDate();
        userAge = DateTime.now().year - birthday.year;
      }
    }
    final summary = await _geminiService.getHealthSummary("Heart Rate", _dataPoints, userAge, timePeriodDescription);
    _cachedHeartRateSummary = summary;
    _lastHeartRateSummaryTimestamp = DateTime.now();
    if(mounted) setState(() => _aiSummary = summary);
  }

  // --- MODERNIZED UI BUILD METHOD ---
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

  // --- MODERNIZED UI WIDGETS ---

  // A reusable card widget for consistent styling
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
    final bpm = latestPoint != null ? (latestPoint.value as NumericHealthValue).numericValue.toStringAsFixed(0) : "--";
    final time = latestPoint != null ? DateFormat('MMM d, hh:mm a').format(latestPoint.dateFrom.toLocal()) : "No recent data";

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
    final segments = ["Day", "Week", "Month"];
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
                ),
              ),
            ),
          ),
        );
      }).expand((widget) => [widget, const SizedBox(width: 8)]).toList()..removeLast(),
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

  // in heartrate_screen.dart

  Widget _buildBarChart() {
    bool isDayView = _selectedSegment == 0;
    List<BarChartGroupData> barGroups = [];
    // Bar chart data generation logic is unchanged.
    if (isDayView) {
      Map<int, List<double>> hourlyData = {};
      for (var point in _dataPoints) {
        int hour = point.dateFrom.hour;
        double value = (point.value as NumericHealthValue).numericValue.toDouble();
        if (!hourlyData.containsKey(hour)) hourlyData[hour] = [];
        hourlyData[hour]!.add(value);
      }
      for (int hour = 0; hour < 24; hour++) {
        double avgValue = hourlyData.containsKey(hour) && hourlyData[hour]!.isNotEmpty ? hourlyData[hour]!.reduce((a, b) => a + b) / hourlyData[hour]!.length : 0;
        barGroups.add(BarChartGroupData(x: hour, barRods: [BarChartRodData(toY: avgValue, color: AppColors.heartRateColor, width: 8, borderRadius: const BorderRadius.all(Radius.circular(2)))]));
      }
    } else {
      Map<int, List<double>> dailyData = {};
      for (var point in _dataPoints) {
        int daysSinceStart = point.dateFrom.difference(_chartStartTime!).inDays;
        double value = (point.value as NumericHealthValue).numericValue.toDouble();
        if (!dailyData.containsKey(daysSinceStart)) dailyData[daysSinceStart] = [];
        dailyData[daysSinceStart]!.add(value);
      }
      dailyData.forEach((day, values) {
        double avgValue = values.reduce((a, b) => a + b) / values.length;
        barGroups.add(BarChartGroupData(x: day, barRods: [BarChartRodData(toY: avgValue, color: AppColors.heartRateColor, width: 12, borderRadius: const BorderRadius.all(Radius.circular(2)))]));
      });
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_stats.max ?? 120) + 20,
        minY: (_stats.min ?? 40) - 20,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 30, getTitlesWidget: (value, meta) => SideTitleWidget(meta: meta, child: Text(value.toInt().toString(), style: AppTextStyles.secondaryInfo)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              // The interval tells the chart where to place ticks. 6 is perfect for 0, 6, 12, 18.
              interval: 6,
              getTitlesWidget: (value, meta) {
                // --- THIS IS THE FIX ---
                // We now check the value and only return a label for specific hours.
                if (isDayView) {
                  String text;
                  switch (value.toInt()) {
                    case 0:
                      text = '12am';
                      break;
                    case 6:
                      text = '6am';
                      break;
                    case 12:
                      text = '12pm';
                      break;
                    case 18:
                      text = '6pm';
                      break;
                    default:
                    // For all other hours, return an empty container so nothing is drawn.
                      return Container();
                  }
                  return SideTitleWidget(meta: meta, child: Text(text, style: AppTextStyles.secondaryInfo));
                } else {
                  // This logic for Week/Month view is fine.
                  final date = _chartStartTime!.add(Duration(days: value.toInt()));
                  // Adjust interval for week/month to prevent clutter there too.
                  if (value.toInt() % (_selectedSegment == 1 ? 1 : 7) != 0) {
                    return Container();
                  }
                  return SideTitleWidget(meta: meta, child: Text(DateFormat.Md().format(date), style: AppTextStyles.secondaryInfo));
                }
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 30, getDrawingHorizontalLine: (value) => FlLine(color: AppColors.secondaryText.withOpacity(0.1), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label;
              if (isDayView) {
                label = '${group.x.toInt()}:00 - ${group.x.toInt() + 1}:00';
              } else {
                final date = _chartStartTime!.add(Duration(days: group.x.toInt()));
                label = DateFormat.yMMMMd().format(date);
              }
              return BarTooltipItem(
                '$label\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY).toStringAsFixed(0),
                    style: const TextStyle(color: AppColors.heartRateColor, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const TextSpan(
                    text: ' BPM',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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