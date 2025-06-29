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
  static const Color stressColor = Color(0xFFF2C94C); // Consistent with Home Screen
  static const Color profileColor = Color(0xFF5667FD); // For AI/intellectual features
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
String _cachedStressSummary = "Generating summary...";
DateTime? _lastStressSummaryTimestamp;

class StressLevelScreen extends StatefulWidget {
  const StressLevelScreen({super.key});
  @override
  State<StressLevelScreen> createState() => _StressLevelScreenState();
}

class _StressLevelScreenState extends State<StressLevelScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
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
        final epochSeconds = entry['epochTime'] as int? ?? int.tryParse(key.toString());
        if (epochSeconds != null) {
          entry['parsedTimestamp'] = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
          tempList.add(entry);
        }
      });
      tempList.sort((a, b) => a['parsedTimestamp'].compareTo(b['parsedTimestamp']));
      final stressEntries = tempList.where((e) => e.containsKey('stress')).toList();
      for (var entry in stressEntries) {
        final gsr = entry['stress']?['gsrReading']?.toDouble() ?? 0.0;
        sum += gsr;
        if (min == null || gsr < min) min = gsr;
        if (max == null || gsr > max) max = gsr;
      }
      if(mounted) {
        setState(() {
          _stressDataList = tempList;
          if (stressEntries.isNotEmpty) {
            _latestStressData = stressEntries.last;
            _minGsr = min ?? 0;
            _maxGsr = max ?? 0;
            _avgGsr = stressEntries.isEmpty ? 0 : sum / stressEntries.length;
          }
          _isLoading = false;
        });
      }
      _generateAiSummary();
    });
  }

  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastStressSummaryTimestamp != null &&
        DateTime.now().difference(_lastStressSummaryTimestamp!) < const Duration(hours: 1)) {
      if (mounted) setState(() => _aiSummary = _cachedStressSummary);
      return;
    }
    final relevantData = _stressDataList.where((d) => d.containsKey('stress')).toList();
    if (relevantData.isEmpty || !mounted) {
      if (mounted) setState(() => _aiSummary = "Not enough data to generate a summary.");
      return;
    }
    if (mounted) setState(() { _aiSummary = "Generating new summary..."; });
    final dataSummaryString = relevantData.map((data) {
      final gsr = data['stress']?['gsrReading'] ?? '?';
      final level = data['stress']?['stressLevel'] ?? 'UNKNOWN';
      final time = DateFormat.Hm().format(data['parsedTimestamp']);
      return "GSR $gsr ($level) at $time";
    }).join(', ');
    const analysisInstructions = """Based on the Galvanic Skin Response (GSR) data, where higher values can indicate a stronger stress or emotional response, provide:
      1. **Stress Overview**: A one-sentence summary of the user's stress state during this period.
      2. **Key Observations**: Point out any significant peaks or valleys in GSR readings and what they might imply (e.g., "a spike around 2 PM could indicate a stressful event"). Mention the detected stress levels (e.g., RELAXED, MILD_STRESS).
      3. **Wellbeing Tips**: Offer 2-3 simple, friendly tips for managing stress, such as deep breathing exercises, taking a short walk, or listening to calm music.""";
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

  // --- MODERNIZED UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Stress Level', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        centerTitle: false,
      ),
      body: _isLoading && _stressDataList.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryText))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: <Widget>[
          const SizedBox(height: 16),
          _buildCurrentStressCard(),
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

  Widget _buildCurrentStressCard() {
    final stress = _latestStressData?['stress'];
    final level = stress?['stressLevel']?.replaceAll('_', ' ') ?? 'No recent data';
    final gsr = stress?['gsrReading']?.toString() ?? '--';
    final time = _latestStressData != null
        ? DateFormat('MMM d, hh:mm a').format(_latestStressData!['parsedTimestamp'])
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
                  text: level,
                  style: AppTextStyles.metricValue.copyWith(color: AppColors.stressColor, fontSize: 28),
                  children: [TextSpan(text: ' (GSR: $gsr)', style: AppTextStyles.metricUnit)],
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
      title: "Live Stress Trend (GSR)",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.stressColor))
                : _stressDataList.where((d) => d.containsKey('stress')).isEmpty
                ? Center(child: Text("No stress data available.", style: AppTextStyles.secondaryInfo))
                : _buildChart(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem(_maxGsr.toStringAsFixed(0), "Max GSR"),
              _buildSummaryStatItem(_avgGsr.toStringAsFixed(1), "Average GSR"),
              _buildSummaryStatItem(_minGsr.toStringAsFixed(0), "Min GSR"),
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
    final chartData = _stressDataList.where((d) => d.containsKey('stress')).toList();
    if (chartData.isEmpty) return Container();

    final spots = chartData.map((data) {
      final gsr = data['stress']?['gsrReading']?.toDouble() ?? 0.0;
      final timestamp = (data['parsedTimestamp'] as DateTime).millisecondsSinceEpoch.toDouble();
      return FlSpot(timestamp, gsr);
    }).toList();

    final startTime = chartData.first['parsedTimestamp'] as DateTime;
    final endTime = chartData.last['parsedTimestamp'] as DateTime;

    return LineChart(
      LineChartData(
        minX: startTime.millisecondsSinceEpoch.toDouble(),
        maxX: endTime.millisecondsSinceEpoch.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.stressColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.stressColor.withOpacity(0.3), AppColors.stressColor.withOpacity(0.0)],
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
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return Container();
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
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.secondaryText.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'GSR: ${spot.y.toStringAsFixed(1)}\n',
                  const TextStyle(color: AppColors.stressColor, fontWeight: FontWeight.bold),
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