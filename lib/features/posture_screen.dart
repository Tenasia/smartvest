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

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color profileColor = Color(0xFF5667FD); // For AI/intellectual features
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
}
// --- END OF DESIGN SYSTEM ---


// --- Caching Logic (Unchanged) ---
String _cachedPostureSummary = "Generating summary...";
DateTime? _lastPostureSummaryTimestamp;

class PostureScreen extends StatefulWidget {
  const PostureScreen({super.key});
  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
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
        final epochSeconds = entry['epochTime'] as int? ?? int.tryParse(key.toString());
        if (epochSeconds != null) {
          entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
          tempList.add(entry);
        }
      });
      tempList.sort((a, b) => a['parsedTimestamp'].compareTo(b['parsedTimestamp']));
      final postureEntries = tempList.where((e) => e.containsKey('posture') && e['posture'] != null).toList();
      for (var entry in postureEntries) {
        final score = entry['posture']?['rulaScore']?.toDouble() ?? 0.0;
        sum += score;
        if (min == null || score < min) min = score;
        if (max == null || score > max) max = score;
      }
      if(mounted) {
        setState(() {
          _postureDataList = tempList;
          if (postureEntries.isNotEmpty) {
            _latestPostureData = postureEntries.last;
            _minScore = min ?? 0;
            _maxScore = max ?? 0;
            _avgScore = postureEntries.isEmpty ? 0 : sum / postureEntries.length;
          }
          _isLoading = false;
        });
      }
      _generateAiSummary();
    });
  }

  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastPostureSummaryTimestamp != null &&
        DateTime.now().difference(_lastPostureSummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) setState(() => _aiSummary = _cachedPostureSummary);
      return;
    }
    final relevantData = _postureDataList.where((d) => d.containsKey('posture')).toList();
    if (relevantData.isEmpty || !mounted) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }
    if (mounted) setState(() { _aiSummary = "Generating new summary..."; });
    final dataSummaryString = relevantData.map((data) {
      final score = data['posture']?['rulaScore'] ?? '?';
      final time = DateFormat.Hm().format(data['parsedTimestamp']);
      return "Score $score at $time";
    }).join(', ');
    const analysisInstructions = """Based on the data (RULA scores from 1-7, where 1 is best and 7 is worst), provide:
      1. **Posture Status**: A one-sentence summary of the user's overall posture during this period.
      2. **Key Observations**: Mention any times of particularly good or poor posture. Note any patterns you see.
      3. **Actionable Recommendations**: Offer 2-3 simple, friendly tips to improve posture, like taking breaks or stretching.""";
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

  // --- MODERNIZED UI BUILD METHOD ---
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
      body: _isLoading && _postureDataList.isEmpty
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

  // --- MODERNIZED UI WIDGETS ---

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
    final posture = _latestPostureData?['posture'];
    final assessment = posture?['rulaAssessment']?.replaceAll('_', ' ') ?? 'No recent data';
    final score = posture?['rulaScore']?.toString() ?? '--';
    final time = _latestPostureData != null
        ? DateFormat('MMM d, hh:mm a').format(_latestPostureData!['parsedTimestamp'])
        : '--';

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
      title: "Live Posture Trend",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.postureColor))
                : _postureDataList.where((d) => d.containsKey('posture')).isEmpty
                ? Center(child: Text("No posture data available.", style: AppTextStyles.secondaryInfo))
                : _buildChart(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem(_maxScore.toStringAsFixed(0), "Worst"),
              _buildSummaryStatItem(_avgScore.toStringAsFixed(1), "Average"),
              _buildSummaryStatItem(_minScore.toStringAsFixed(0), "Best"),
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
    final chartData = _postureDataList.where((d) => d.containsKey('posture')).toList();
    if (chartData.isEmpty) return Container();

    final spots = chartData.map((data) {
      final score = data['posture']?['rulaScore']?.toDouble() ?? 0.0;
      final timestamp = (data['parsedTimestamp'] as DateTime).millisecondsSinceEpoch.toDouble();
      return FlSpot(timestamp, score);
    }).toList();

    final startTime = chartData.first['parsedTimestamp'] as DateTime;
    final endTime = chartData.last['parsedTimestamp'] as DateTime;

    return LineChart(
      LineChartData(
        minY: 1, maxY: 7,
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: endTime.millisecondsSinceEpoch.toDouble(),
        // --- ADDING COLOR ZONES FOR CONTEXT ---

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
              interval: (endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch) / 3,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(meta: meta, child: Text(DateFormat.Hm().format(date), style: AppTextStyles.secondaryInfo));
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