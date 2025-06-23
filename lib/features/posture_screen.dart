import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:smartvest/core/services/gemini_service.dart';

// --- Caching for AI Summary ---
String _cachedPostureSummary = "Generating summary...";
DateTime? _lastPostureSummaryTimestamp;

// --- Style Constants ---
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _postureColor = Color(0xFF007AFF);
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

class PostureScreen extends StatefulWidget {
  const PostureScreen({super.key});

  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref('healthMonitor/data');
  StreamSubscription? _dataSubscription;

  bool _isLoading = true;
  String _aiSummary = _cachedPostureSummary;
  List<Map<dynamic, dynamic>> _postureDataList = [];

  double _maxScore = 0;
  double _minScore = 0;
  double _avgScore = 0;
  Map<dynamic, dynamic>? _latestPostureData;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    _dataSubscription = _databaseReference.limitToLast(100).onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dataMap = event.snapshot.value as Map<dynamic, dynamic>;
      final List<Map<dynamic, dynamic>> tempList = [];
      double sum = 0;
      double? min, max;

      dataMap.forEach((key, value) {
        final entry = value as Map<dynamic, dynamic>;
        final timestampStr = entry['timestamp']?.toString();
        if (timestampStr != null) {
          entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
          tempList.add(entry);
        }
      });

      tempList.sort((a, b) => a['parsedTimestamp'].compareTo(b['parsedTimestamp']));

      for (var entry in tempList) {
        final score = entry['posture']?['rulaScore']?.toDouble() ?? 0.0;
        sum += score;
        if (min == null || score < min) min = score;
        if (max == null || score > max) max = score;
      }

      if(mounted) {
        setState(() {
          _postureDataList = tempList;
          if (_postureDataList.isNotEmpty) {
            _latestPostureData = _postureDataList.last;
            _minScore = min ?? 0;
            _maxScore = max ?? 0;
            _avgScore = _postureDataList.isEmpty ? 0 : sum / _postureDataList.length;
          }
          _isLoading = false;
        });
      }
      _generateAiSummary();
    });
  }

  Future<void> _generateAiSummary() async {
    if (_lastPostureSummaryTimestamp != null &&
        DateTime.now().difference(_lastPostureSummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) setState(() => _aiSummary = _cachedPostureSummary);
      return;
    }

    if (_postureDataList.isEmpty || !mounted) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }

    if (mounted) setState(() { _aiSummary = "Generating new summary..."; });

    final dataSummaryString = _postureDataList.map((data) {
      final score = data['posture']?['rulaScore'] ?? '?';
      final time = DateFormat.Hm().format(data['parsedTimestamp']);
      return "Score $score at $time";
    }).join(', ');

    const analysisInstructions = """
        Based on the data (RULA scores from 1-7, where 1 is best and 7 is worst), provide:
        1. **Posture Status**: A one-sentence summary of the user's overall posture during this period.
        2. **Key Observations**: Mention any times of particularly good or poor posture. Note any patterns you see.
        3. **Actionable Recommendations**: Offer 2-3 simple, friendly tips to improve posture, like taking breaks or stretching.
      """;

    User? user = FirebaseAuth.instance.currentUser;
    int? userAge;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('birthday')) {
        final birthday = (doc.data()!['birthday'] as Timestamp).toDate();
        userAge = DateTime.now().year - birthday.year;
      }
    }

    final summary = await _geminiService.getSummaryFromRawString(
      metricName: "Posture (RULA Score)",
      dataSummary: dataSummaryString,
      userAge: userAge,
      analysisInstructions: analysisInstructions,
    );

    _cachedPostureSummary = summary;
    _lastPostureSummaryTimestamp = DateTime.now();

    if (mounted) setState(() => _aiSummary = summary);
  }

  Widget _buildCurrentPostureCard() {
    final posture = _latestPostureData?['posture'];
    final assessment = posture?['rulaAssessment'] ?? '--';
    final score = posture?['rulaScore']?.toString() ?? '--';
    final time = _latestPostureData != null
        ? DateFormat('MMM d, hh:mm a').format(_latestPostureData!['parsedTimestamp'])
        : '--';

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Latest Posture Reading", style: _generalCardTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        text: assessment,
                        style: _currentValueStyle,
                        children: <TextSpan>[
                          TextSpan(text: ' (Score: $score)', style: _currentUnitStyle)
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(time, style: _currentTimeStyle, textAlign: TextAlign.end),
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

  Widget _buildChart() {
    if (_postureDataList.isEmpty) {
      return const Center(child: Text("No posture data available."));
    }

    final spots = _postureDataList.map((data) {
      final score = data['posture']?['rulaScore']?.toDouble() ?? 0.0;
      final timestamp = (data['parsedTimestamp'] as DateTime).millisecondsSinceEpoch.toDouble();
      return FlSpot(timestamp, score);
    }).toList();

    final startTime = _postureDataList.first['parsedTimestamp'] as DateTime;
    final endTime = _postureDataList.last['parsedTimestamp'] as DateTime;

    return LineChart(
      LineChartData(
        minY: 1,
        maxY: 7,
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: endTime.millisecondsSinceEpoch.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _postureColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _postureColor.withOpacity(0.1)),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => SideTitleWidget(meta: meta, child: Text(val.toInt().toString(), style: _chartAxisLabelStyle)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch) / 4,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(meta: meta, child: Text(DateFormat.Hm().format(date), style: _chartAxisLabelStyle));
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
            SizedBox(height: 200, child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildChart()),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStatItem(_maxScore.toStringAsFixed(0), "Worst Score"),
                _buildSummaryStatItem(_minScore.toStringAsFixed(0), "Best Score"),
                _buildSummaryStatItem(_avgScore.toStringAsFixed(1), "Average Score"),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBgColor,
      appBar: AppBar(
        title: const Text('Posture Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: _isLoading && _postureDataList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildCurrentPostureCard(),
          _buildGraphCard(),
          _buildSummaryCard("AI Posture Summary", _aiSummary, Icons.auto_awesome, _aiSummaryIconColor),
        ],
      ),
    );
  }
}