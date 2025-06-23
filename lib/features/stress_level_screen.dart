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
String _cachedStressSummary = "Generating summary...";
DateTime? _lastStressSummaryTimestamp;

// --- Style Constants ---
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _stressColor = Color(0xFFFFA000);
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

class StressLevelScreen extends StatefulWidget {
  const StressLevelScreen({super.key});

  @override
  State<StressLevelScreen> createState() => _StressLevelScreenState();
}

class _StressLevelScreenState extends State<StressLevelScreen> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref('healthMonitor/data');
  StreamSubscription? _dataSubscription;

  bool _isLoading = true;
  String _aiSummary = _cachedStressSummary;
  List<Map<dynamic, dynamic>> _stressDataList = [];

  double _maxGsr = 0;
  double _minGsr = 0;
  double _avgGsr = 0;
  Map<dynamic, dynamic>? _latestStressData;

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
        final gsr = entry['stress']?['gsrReading']?.toDouble() ?? 0.0;
        sum += gsr;
        if (min == null || gsr < min) min = gsr;
        if (max == null || gsr > max) max = gsr;
      }

      if(mounted) {
        setState(() {
          _stressDataList = tempList;
          if (_stressDataList.isNotEmpty) {
            _latestStressData = _stressDataList.last;
            _minGsr = min ?? 0;
            _maxGsr = max ?? 0;
            _avgGsr = _stressDataList.isEmpty ? 0 : sum / _stressDataList.length;
          }
          _isLoading = false;
        });
      }

      _generateAiSummary();
    });
  }

  Future<void> _generateAiSummary() async {
    if (_lastStressSummaryTimestamp != null &&
        DateTime.now().difference(_lastStressSummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) setState(() => _aiSummary = _cachedStressSummary);
      return;
    }

    if (_stressDataList.isEmpty || !mounted) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }

    if (mounted) setState(() { _aiSummary = "Generating new summary..."; });

    final dataSummaryString = _stressDataList.map((data) {
      final gsr = data['stress']?['gsrReading'] ?? '?';
      final level = data['stress']?['stressLevel'] ?? 'UNKNOWN';
      final time = DateFormat.Hm().format(data['parsedTimestamp']);
      return "GSR $gsr ($level) at $time";
    }).join(', ');

    const analysisInstructions = """
        Based on the Galvanic Skin Response (GSR) data, where higher values can indicate a stronger stress or emotional response, provide:
        1. **Stress Overview**: A one-sentence summary of the user's stress state during this period.
        2. **Key Observations**: Point out any significant peaks or valleys in GSR readings and what they might imply (e.g., "a spike around 2 PM could indicate a stressful event"). Mention the detected stress levels (e.g., RELAXED, MILD_STRESS).
        3. **Wellbeing Tips**: Offer 2-3 simple, friendly tips for managing stress, such as deep breathing exercises, taking a short walk, or listening to calm music.
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
      metricName: "Stress (GSR Reading)",
      dataSummary: dataSummaryString,
      userAge: userAge,
      analysisInstructions: analysisInstructions,
    );

    _cachedStressSummary = summary;
    _lastStressSummaryTimestamp = DateTime.now();

    if (mounted) setState(() => _aiSummary = summary);
  }

  Widget _buildCurrentStressCard() {
    final stress = _latestStressData?['stress'];
    final level = stress?['stressLevel']?.replaceAll('_', ' ') ?? '--';
    final gsr = stress?['gsrReading']?.toString() ?? '--';
    final time = _latestStressData != null
        ? DateFormat('MMM d, hh:mm a').format(_latestStressData!['parsedTimestamp'])
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
            const Text("Latest Stress Reading", style: _generalCardTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      text: level,
                      style: _currentValueStyle,
                      children: <TextSpan>[TextSpan(text: ' (GSR: $gsr)', style: _currentUnitStyle)],
                    ),
                    softWrap: true,
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

  Widget _buildChart() {
    if (_stressDataList.isEmpty) {
      return const Center(child: Text("No stress data available."));
    }

    final spots = _stressDataList.map((data) {
      final gsr = data['stress']?['gsrReading']?.toDouble() ?? 0.0;
      final timestamp = (data['parsedTimestamp'] as DateTime).millisecondsSinceEpoch.toDouble();
      return FlSpot(timestamp, gsr);
    }).toList();

    final startTime = _stressDataList.first['parsedTimestamp'] as DateTime;
    final endTime = _stressDataList.last['parsedTimestamp'] as DateTime;

    return LineChart(
      LineChartData(
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: endTime.millisecondsSinceEpoch.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _stressColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _stressColor.withOpacity(0.1)),
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
                _buildSummaryStatItem(_maxGsr.toStringAsFixed(0), "Max GSR"),
                _buildSummaryStatItem(_minGsr.toStringAsFixed(0), "Min GSR"),
                _buildSummaryStatItem(_avgGsr.toStringAsFixed(1), "Average GSR"),
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
        title: const Text('Stress Level Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: _isLoading && _stressDataList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildCurrentStressCard(),
          _buildGraphCard(),
          _buildSummaryCard("AI Stress Summary", _aiSummary, Icons.auto_awesome, _aiSummaryIconColor),
        ],
      ),
    );
  }
}