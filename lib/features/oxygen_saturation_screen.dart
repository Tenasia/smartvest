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

// (Caching and Style constants remain the same)
String _cachedSpo2Summary = "Generating summary...";
DateTime? _lastSpo2SummaryTimestamp;
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _accentColorBlue = Color(0xFF007AFF);
const Color _oxygenColor = Color(0xFF27AE60);
const Color _aiSummaryIconColor = Color(0xFF9B59B6);
final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;
const TextStyle _generalCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _summaryLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _summaryValueStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _currentValueStyle = TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _currentUnitStyle = TextStyle(fontSize: 16, color: _secondaryTextColor);
const TextStyle _currentTimeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);
const TextStyle _cardTitleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _secondaryTextColor);


class OxygenSaturationScreen extends StatefulWidget {
  const OxygenSaturationScreen({super.key});

  @override
  State<OxygenSaturationScreen> createState() => _OxygenSaturationScreenState();
}

class _OxygenSaturationScreenState extends State<OxygenSaturationScreen> {
  final HealthService _healthService = HealthService();
  final GeminiService _geminiService = GeminiService();
  int _selectedSegment = 0;
  bool _isLoading = true;

  List<HealthDataPoint> _dataPoints = [];
  HealthStats _stats = HealthStats();
  String _aiSummary = _cachedSpo2Summary;
  DateTime? _chartStartTime;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _fetchDataForSegment();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if(mounted) {
        _fetchDataForSegment();
      }
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

    final points = await _healthService.getHealthData(startTime, now, HealthDataType.BLOOD_OXYGEN);

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
  }

  // --- vvv MODIFIED THIS FUNCTION vvv ---
  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastSpo2SummaryTimestamp != null &&
        DateTime.now().difference(_lastSpo2SummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) {
        setState(() => _aiSummary = _cachedSpo2Summary);
      }
      return;
    }

    if (_dataPoints.isEmpty) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }

    if (mounted) setState(() => _aiSummary = "Generating new summary...");

    // Determine the time period description based on the selected filter
    String timePeriodDescription;
    switch (_selectedSegment) {
      case 0:
        timePeriodDescription = "last 24 hours";
        break;
      case 1:
        timePeriodDescription = "last 7 days";
        break;
      case 2:
        timePeriodDescription = "last 30 days";
        break;
      default:
        timePeriodDescription = "selected period";
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

    // Pass the new description to the Gemini service
    final summary = await _geminiService.getHealthSummary(
      "Blood Oxygen (SpO2)",
      _dataPoints,
      userAge,
      timePeriodDescription, // Pass the dynamic description
    );

    _cachedSpo2Summary = summary;
    _lastSpo2SummaryTimestamp = DateTime.now();

    if (mounted) setState(() => _aiSummary = summary);
  }

  double _calculateTitleInterval(DateTime start, DateTime end) {
    switch (_selectedSegment) {
      case 0: return const Duration(hours: 4).inMilliseconds.toDouble();
      case 1: return const Duration(days: 1).inMilliseconds.toDouble();
      case 2: return const Duration(days: 5).inMilliseconds.toDouble();
      default: return const Duration(days: 1).inMilliseconds.toDouble();
    }
  }

  // --- vvv MODIFIED THIS WIDGET vvv ---
  Widget _buildSummaryCard(String title, String summary, IconData icon, Color iconColor) {
    // Assuming these constants are defined elsewhere in your class
    const _cardElevation = 1.5;
    final _cardBorderRadius = BorderRadius.circular(12.0);
    const _cardBgColor = Colors.white;
    const _cardPadding = EdgeInsets.all(16.0);
    const _secondaryTextColor = Color(0xFF757575);
    const _primaryTextColor = Color(0xFF333333);
    const _cardTitleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _secondaryTextColor);

    // This function needs to be accessible from where you call this widget.
    // This is a placeholder for the actual function call.
    void _generateAiSummary({bool forceRefresh = false}) {}

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
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                // --- vvv THE FIX IS HERE vvv ---
                Expanded(
                  // 1. Use Expanded to make the Text widget fill all available horizontal space.
                  child: Text(
                    title.toUpperCase(),
                    style: _cardTitleStyle,
                    // 2. Add overflow handling for very long titles to prevent them from wrapping
                    //    and instead show an ellipsis (...).
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // 3. The Spacer is no longer needed because Expanded handles the spacing.
                SizedBox(
                  height: 36,
                  width: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.refresh, size: 20, color: _secondaryTextColor),
                    onPressed: () => _generateAiSummary(forceRefresh: true),
                    tooltip: 'Refresh Summary',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownBody(
              data: summary,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(color: _primaryTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSpo2Card() {
    final latestPoint = _stats.latest;
    final spo2 = latestPoint != null ? (latestPoint.value as NumericHealthValue).numericValue.toStringAsFixed(0) : "--";
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
            const Text("Latest SpO2 Reading", style: _generalCardTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RichText(
                  text: TextSpan(
                    text: spo2,
                    style: _currentValueStyle,
                    children: const <TextSpan>[TextSpan(text: ' %', style: _currentUnitStyle)],
                  ),
                ),
                Text(time, style: _currentTimeStyle),
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

  Widget _buildChart(DateTime startTime) {
    if (_dataPoints.isEmpty) {
      return const Center(child: Text("No data for selected period."));
    }

    final spots = _dataPoints.map((point) {
      final value = (point.value as NumericHealthValue).numericValue.toDouble();
      final xValue = point.dateFrom.millisecondsSinceEpoch.toDouble();
      return FlSpot(xValue, value);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 85,
        maxY: 100,
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: DateTime.now().millisecondsSinceEpoch.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _oxygenColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _oxygenColor.withOpacity(0.1)),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => SideTitleWidget(meta: meta, child: Text(value.toInt().toString(), style: _chartAxisLabelStyle)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _calculateTitleInterval(startTime, DateTime.now()),
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                String text = (_selectedSegment == 0) ? DateFormat.Hm().format(date) : DateFormat.Md().format(date);
                return SideTitleWidget(meta: meta, child: Text(text, style: _chartAxisLabelStyle));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  Widget _buildGraphCard() {
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
            SizedBox(height: 200, child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildChart(_chartStartTime!)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStatItem(_stats.max?.toStringAsFixed(0) ?? '--', "Maximum SpO2"),
                _buildSummaryStatItem(_stats.min?.toStringAsFixed(0) ?? '--', "Minimum SpO2"),
                _buildSummaryStatItem(_stats.avg?.toStringAsFixed(0) ?? '--', "Average SpO2"),
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
        title: const Text('Blood Oxygen Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: _isLoading && _dataPoints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildCurrentSpo2Card(),
          _buildGraphCard(),
          _buildSummaryCard("AI BLOOD OXYGEN SUMMARY", _aiSummary, Icons.auto_awesome, _aiSummaryIconColor),
        ],
      ),
    );
  }
}