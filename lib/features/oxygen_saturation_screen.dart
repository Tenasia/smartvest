import 'package:flutter/material.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


// --- Style Constants ---
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
  int _selectedSegment = 0; // 0: Day, 1: Week, 2: Month
  bool _isLoading = true;

  List<HealthDataPoint> _dataPoints = [];
  HealthStats _stats = HealthStats();
  String _aiSummary = "Generating summary...";

  @override
  void initState() {
    super.initState();
    _fetchDataForSegment();
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

    if (mounted) {
      setState(() {
        _dataPoints = points;
        _stats = HealthStats(
          min: min,
          max: max,
          avg: points.isEmpty ? 0 : sum / points.length,
          latest: points.isNotEmpty ? points.last : null,
        );
      });

      User? user = FirebaseAuth.instance.currentUser;
      int? userAge;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('birthday')) {
          final birthday = (doc.data()!['birthday'] as Timestamp).toDate();
          userAge = DateTime.now().year - birthday.year;
        }
      }

      _geminiService.getHealthSummary("Blood Oxygen (SpO2)", _dataPoints, userAge).then((summary) {
        if(mounted) setState(() => _aiSummary = summary);
      });

      setState(() => _isLoading = false);
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
            Row(children: [Icon(icon, color: iconColor, size: 20), const SizedBox(width: 8), Text(title, style: _cardTitleStyle)]),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : MarkdownBody(data: summary, styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: const TextStyle(color: _primaryTextColor))),
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

  Widget _buildChart() {
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
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
            String text = (_selectedSegment == 0) ? DateFormat.Hm().format(date) : DateFormat.Md().format(date);
            return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: _chartAxisLabelStyle));
          }, interval: (_dataPoints.last.dateFrom.millisecondsSinceEpoch - _dataPoints.first.dateFrom.millisecondsSinceEpoch) / 4)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            SizedBox(height: 200, child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildChart()),
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
