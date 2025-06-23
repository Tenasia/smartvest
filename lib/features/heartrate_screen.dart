import 'package:flutter/material.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

// --- Caching for AI Summary ---
String _cachedHeartRateSummary = "Generating summary...";
DateTime? _lastHeartRateSummaryTimestamp;

// --- Style Constants ---
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _accentColorBlue = Color(0xFF007AFF);
const Color _heartRateColor = Color(0xFFF25C54);
const Color _aiSummaryIconColor = Color(0xFF9B59B6);

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _generalCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _summaryLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _summaryValueStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _currentHrValueStyle = TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _currentHrUnitStyle = TextStyle(fontSize: 16, color: _secondaryTextColor);
const TextStyle _currentHrTimeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);
const TextStyle _cardTitleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _secondaryTextColor);

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  final HealthService _healthService = HealthService();
  final GeminiService _geminiService = GeminiService();
  int _selectedSegment = 0; // 0: Day, 1: Week, 2: Month
  bool _isLoading = true;

  List<HealthDataPoint> _dataPoints = [];
  HealthStats _stats = HealthStats();
  String _aiSummary = _cachedHeartRateSummary;
  DateTime? _chartStartTime;

  @override
  void initState() {
    super.initState();
    _fetchDataForSegment();
  }

  Future<void> _generateAiSummary() async {
    if (_lastHeartRateSummaryTimestamp != null &&
        DateTime.now().difference(_lastHeartRateSummaryTimestamp!) < const Duration(hours: 1)) {
      if(mounted) {
        setState(() => _aiSummary = _cachedHeartRateSummary);
      }
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('birthday')) {
        final birthday = (doc.data()!['birthday'] as Timestamp).toDate();
        userAge = DateTime.now().year - birthday.year;
      }
    }

    final summary = await _geminiService.getHealthSummary("Heart Rate", _dataPoints, userAge);

    _cachedHeartRateSummary = summary;
    _lastHeartRateSummaryTimestamp = DateTime.now();

    if(mounted) setState(() => _aiSummary = summary);
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

    if (mounted) {
      setState(() {
        _dataPoints = points;
        _stats = HealthStats(
          min: min,
          max: max,
          avg: points.isEmpty ? 0 : sum / points.length,
          latest: points.isNotEmpty ? points.last : null,
        );
        _isLoading = false;
      });

      _generateAiSummary();
    }
  }

  // --- WIDGETS ---
  Widget _buildSummaryCard(String title, String summary, IconData icon, Color iconColor) {
    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 16.0, top: 16.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: iconColor, size: 20), const SizedBox(width: 8), Text(title.toUpperCase(), style: _cardTitleStyle)]),
            const SizedBox(height: 12),
            MarkdownBody(data: summary, styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: const TextStyle(color: _primaryTextColor))),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentHeartRateCard() {
    final latestPoint = _stats.latest;
    final bpm = latestPoint != null ? (latestPoint.value as NumericHealthValue).numericValue.toStringAsFixed(0) : "--";
    final time = latestPoint != null ? DateFormat('MMM d, hh:mm a').format(latestPoint.dateFrom.toLocal()) : "--";

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Latest Heart Rate", style: _generalCardTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RichText(
                  text: TextSpan(
                    text: bpm,
                    style: _currentHrValueStyle,
                    children: const <TextSpan>[TextSpan(text: ' BPM', style: _currentHrUnitStyle)],
                  ),
                ),
                Text(time, style: _currentHrTimeStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: _summaryValueStyle),
        const SizedBox(height: 2),
        Text(label, style: _summaryLabelStyle),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    final segments = ["Day", "Week", "Month"];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(segments.length, (index) {
          bool isSelected = _selectedSegment == index;
          return ElevatedButton(
            onPressed: () {
              setState(() => _selectedSegment = index);
              _fetchDataForSegment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? _accentColorBlue : Colors.grey.shade200,
              foregroundColor: isSelected ? Colors.white : _secondaryTextColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: isSelected ? 2 : 0,
            ),
            child: Text(segments[index]),
          );
        }),
      ),
    );
  }

  // Updated method to create bar chart instead of line chart
  Widget _buildBarChart() {
    if (_dataPoints.isEmpty) {
      return const Center(child: Text("No data for selected period."));
    }

    bool isDayView = _selectedSegment == 0;

    List<BarChartGroupData> barGroups = [];

    if (isDayView) {
      // For day view, group data by hour
      Map<int, List<double>> hourlyData = {};

      for (var point in _dataPoints) {
        int hour = point.dateFrom.hour;
        double value = (point.value as NumericHealthValue).numericValue.toDouble();

        if (!hourlyData.containsKey(hour)) {
          hourlyData[hour] = [];
        }
        hourlyData[hour]!.add(value);
      }

      // Create bar groups for each hour with data
      for (int hour = 0; hour < 24; hour++) {
        double avgValue = 0;
        if (hourlyData.containsKey(hour) && hourlyData[hour]!.isNotEmpty) {
          avgValue = hourlyData[hour]!.reduce((a, b) => a + b) / hourlyData[hour]!.length;
        }

        barGroups.add(
          BarChartGroupData(
            x: hour,
            barRods: [
              BarChartRodData(
                toY: avgValue,
                color: _heartRateColor,
                width: 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // For week/month view, group by day
      Map<int, List<double>> dailyData = {};

      for (var point in _dataPoints) {
        int daysSinceStart = point.dateFrom.difference(_chartStartTime!).inDays;
        double value = (point.value as NumericHealthValue).numericValue.toDouble();

        if (!dailyData.containsKey(daysSinceStart)) {
          dailyData[daysSinceStart] = [];
        }
        dailyData[daysSinceStart]!.add(value);
      }

      dailyData.forEach((day, values) {
        double avgValue = values.reduce((a, b) => a + b) / values.length;
        barGroups.add(
          BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: avgValue,
                color: _heartRateColor,
                width: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          ),
        );
      });
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_stats.max ?? 120) + 20,
        minY: 0,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 24,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toInt().toString(),
                  style: _chartAxisLabelStyle,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: isDayView ? 6 : (_selectedSegment == 1 ? 1 : 5),
              getTitlesWidget: (value, meta) {
                if (isDayView) {
                  // Show time labels for day view
                  String text = '';
                  switch (value.toInt()) {
                    case 0: text = '00:00'; break;
                    case 6: text = '06:00'; break;
                    case 12: text = '12:00'; break;
                    case 18: text = '18:00'; break;
                    case 23: text = '00:00'; break;
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(text, style: _chartAxisLabelStyle),
                  );
                } else {
                  // Show date labels for week/month view
                  final date = _chartStartTime!.add(Duration(days: value.toInt()));
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat.Md().format(date),
                      style: _chartAxisLabelStyle,
                    ),
                  );
                }
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 24,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.withOpacity(0.3)),
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeartRateGraphCard() {
    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSegmentedControl(),
            const SizedBox(height: 16),
            SizedBox(
                height: 200,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBarChart()
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStatItem(_stats.max?.toStringAsFixed(0) ?? '--', "Maximum BPM"),
                _buildSummaryStatItem(_stats.min?.toStringAsFixed(0) ?? '--', "Minimum BPM"),
                _buildSummaryStatItem(_stats.avg?.toStringAsFixed(0) ?? '--', "Average BPM"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBgColor,
      appBar: AppBar(
        title: const Text('Heart Rate Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: _isLoading && _dataPoints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildCurrentHeartRateCard(),
          _buildHeartRateGraphCard(),
          _buildSummaryCard("AI HEART RATE SUMMARY", _aiSummary, Icons.auto_awesome, _aiSummaryIconColor),
        ],
      ),
    );
  }
}

// Make sure you have the HealthStats class defined somewhere in your code
class HealthStats {
  final double? min;
  final double? max;
  final double? avg;
  final HealthDataPoint? latest;

  HealthStats({this.min, this.max, this.avg, this.latest});
}