import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color profileColor = Color(0xFF5667FD);
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

class HealthStats {
  final double? min;
  final double? max;
  final double? avg;
  final FlSpot? latest;

  HealthStats({this.min, this.max, this.avg, this.latest});
}

class OxygenSaturationScreen extends StatefulWidget {
  final List<FlSpot> hourlyData;

  const OxygenSaturationScreen({super.key, required this.hourlyData});

  @override
  State<OxygenSaturationScreen> createState() => _OxygenSaturationScreenState();
}

class _OxygenSaturationScreenState extends State<OxygenSaturationScreen> {
  final GeminiService _geminiService = GeminiService();
  final Random _random = Random();

  int _selectedSegment = 0;
  bool _isLoading = false;

  List<FlSpot> _currentData = [];
  HealthStats _stats = HealthStats();
  String _aiSummary = "Select a time range to view your summary.";

  @override
  void initState() {
    super.initState();
    _updateDataForSegment(0, initialLoad: true);
  }

  void _updateDataForSegment(int index, {bool initialLoad = false}) {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedSegment = index;
    });

    Timer(const Duration(milliseconds: 300), () {
      List<FlSpot> newData;
      Duration duration;

      switch (index) {
        case 0: // 1 Hour
          newData = List.from(widget.hourlyData);
          duration = const Duration(hours: 1);
          break;
        case 1: // Day
          duration = const Duration(days: 1);
          newData = _generateSimulatedData(duration, points: 96, baseValue: 98, variation: 2);
          break;
        case 2: // Week
          duration = const Duration(days: 7);
          newData = _generateSimulatedData(duration, points: 168, baseValue: 98, variation: 2);
          break;
        case 3: // Month
          duration = const Duration(days: 30);
          newData = _generateSimulatedData(duration, points: 240, baseValue: 98, variation: 2);
          break;
        default:
          newData = [];
          duration = const Duration(hours: 1);
      }

      if (mounted) {
        setState(() {
          _currentData = newData;
          _stats = _calculateStats(newData);
          _isLoading = false;
        });
        _generateAiSummary(forceRefresh: initialLoad);
      }
    });
  }

  List<FlSpot> _generateSimulatedData(Duration duration, {required int points, required double baseValue, required double variation}) {
    final now = DateTime.now();
    final startTime = now.subtract(duration);
    final timeStep = duration.inMilliseconds / points;

    return List.generate(points, (i) {
      final timestamp = startTime.add(Duration(milliseconds: (timeStep * i).toInt()));
      final value = baseValue + (_random.nextDouble() - 0.5) * variation;
      return FlSpot(timestamp.millisecondsSinceEpoch.toDouble(), value.clamp(95, 100));
    });
  }

  HealthStats _calculateStats(List<FlSpot> data) {
    if (data.isEmpty) return HealthStats();

    double min = data.first.y, max = data.first.y, sum = 0;
    for (var spot in data) {
      sum += spot.y;
      if (spot.y < min) min = spot.y;
      if (spot.y > max) max = spot.y;
    }
    return HealthStats(
      min: min,
      max: max,
      avg: sum / data.length,
      latest: data.last,
    );
  }

  Future<void> _generateAiSummary({bool forceRefresh = false}) async {
    if (_currentData.isEmpty) {
      if (mounted) setState(() => _aiSummary = "Not enough data for a summary.");
      return;
    }
    if (mounted) setState(() { _aiSummary = "Analyzing your blood oxygen data..."; });

    final dataSummaryString = _currentData.map((spot) {
      final time = DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()));
      return "${spot.y.toInt()}% at $time";
    }).take(50).join(', ');

    const analysisInstructions = """Based on the blood oxygen saturation data (normal: 95-100%), provide:
        1. **Oxygen Status**: Overall assessment of oxygen saturation levels.
        2. **Key Observations**: Notable patterns or concerning readings.
        3. **Health Recommendations**: 2-3 actionable tips for respiratory health.""";

    try {
      final summary = await _geminiService.getSummaryFromRawString(
        metricName: "Blood Oxygen (SpO2)",
        dataSummary: dataSummaryString,
        analysisInstructions: analysisInstructions, userAge: null,
      );
      if (mounted) setState(() => _aiSummary = summary);
    } catch (e) {
      if(mounted) setState(() => _aiSummary = "Sorry, I couldn't generate a summary right now.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Blood Oxygen', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: <Widget>[
          const SizedBox(height: 16),
          _buildCurrentSpo2Card(),
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

  Widget _buildCurrentSpo2Card() {
    final latestPoint = _stats.latest;
    final spo2 = latestPoint != null ? latestPoint.y.toStringAsFixed(0) : "--";
    final time = latestPoint != null ? DateFormat('MMM d, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(latestPoint.x.toInt()).toLocal()) : "No recent data";

    return _buildInfoCard(
      title: "Latest Reading",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              text: spo2,
              style: AppTextStyles.metricValue.copyWith(color: AppColors.oxygenColor, fontSize: 28),
              children: [TextSpan(text: ' %', style: AppTextStyles.metricUnit)],
            ),
          ),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.oxygenColor))
                : _currentData.isEmpty
                ? Center(child: Text("No data for this period.", style: AppTextStyles.secondaryInfo))
                : _buildChart(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStatItem('${_stats.max?.toStringAsFixed(0) ?? '--'}%', "Maximum"),
              _buildSummaryStatItem('${_stats.avg?.toStringAsFixed(0) ?? '--'}%', "Average"),
              _buildSummaryStatItem('${_stats.min?.toStringAsFixed(0) ?? '--'}%', "Minimum"),
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
              if (!_aiSummary.contains("Analyzing"))
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.secondaryText),
                onPressed: () => _generateAiSummary(forceRefresh: true),
                tooltip: 'Refresh Summary',
              ),
            ],
          ),
          const Divider(height: 24),
          _aiSummary.contains("Analyzing")
              ? const Center(child: CircularProgressIndicator(color: AppColors.profileColor))
              : MarkdownBody(
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
    final segments = ["1H", "1D", "1W", "1M"];
    return Row(
      children: List.generate(segments.length, (index) {
        bool isSelected = _selectedSegment == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateDataForSegment(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.oxygenColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? AppColors.oxygenColor : AppColors.secondaryText.withOpacity(0.5))
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
      }).expand((widget) => [widget, const SizedBox(width: 8)]).toList()..removeLast(),
    );
  }

  Widget _buildSummaryStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.secondaryInfo),
      ],
    );
  }

  Widget _buildChart() {
    if (_currentData.isEmpty) return Container();

    return LineChart(
      LineChartData(
        minY: 90,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: _currentData,
            isCurved: true,
            color: AppColors.oxygenColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.oxygenColor.withOpacity(0.3), AppColors.oxygenColor.withOpacity(0.0)],
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
              reservedSize: 28,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(meta: meta, child: Text(value.toInt().toString(), style: AppTextStyles.secondaryInfo));              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _getBottomTitleInterval(),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta, // Pass the 'meta' object directly
                  child: Text(_getBottomTitle(value), style: AppTextStyles.secondaryInfo.copyWith(fontSize: 10)),
                );
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
                  '${spot.y.toStringAsFixed(1)}%',
                  AppTextStyles.buttonText.copyWith(color: Colors.white),
                  children: [
                    TextSpan(
                      text: DateFormat('MMM d, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt())),
                      style: AppTextStyles.secondaryInfo.copyWith(color: Colors.white, fontSize: 12),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _getBottomTitleInterval() {
    switch (_selectedSegment) {
      case 0: return const Duration(minutes: 15).inMilliseconds.toDouble();
      case 1: return const Duration(hours: 6).inMilliseconds.toDouble();
      case 2: return const Duration(days: 2).inMilliseconds.toDouble();
      case 3: return const Duration(days: 7).inMilliseconds.toDouble();
      default: return const Duration(hours: 1).inMilliseconds.toDouble();
    }
  }

  String _getBottomTitle(double value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    switch (_selectedSegment) {
      case 0: return DateFormat.Hm().format(date);
      case 1: return DateFormat.jm().format(date);
      case 2: return DateFormat.E().format(date);
      case 3: return DateFormat.Md().format(date);
      default: return '';
    }
  }
}