import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:glass_kit/glass_kit.dart'; // Corrected import for the glass effect

// --- Design System (Copied from home.dart for consistency) ---

class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color oxygenColor = Color(0xFF27AE60);
  static const Color postureColor = Color(0xFF2F80ED);
  static const Color stressColor = Color(0xFFF2C94C);
  static const Color profileColor = Color(0xFF5667FD);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );
  static final TextStyle cardTitle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
  );
  static final TextStyle metricValue = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );
  static final TextStyle metricUnit = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
  );
  static final TextStyle body = GoogleFonts.poppins(
    fontSize: 14,
    color: AppColors.primaryText.withOpacity(0.7),
  );
}


// --- Data Models (can be moved to a separate models file later) ---

class PostureStats {
  final double? minRulaScore;
  final double? maxRulaScore;
  final double? avgRulaScore;
  PostureStats({this.minRulaScore, this.maxRulaScore, this.avgRulaScore});
}

class StressStats {
  final double? minGsr;
  final double? maxGsr;
  final double? avgGsr;
  StressStats({this.minGsr, this.maxGsr, this.avgGsr});
}

class DailyHealthSummary {
  final HealthStats heartRateStats;
  final HealthStats spo2Stats;
  final PostureStats postureStats;
  final StressStats stressStats;

  DailyHealthSummary({
    required this.heartRateStats,
    required this.spo2Stats,
    required this.postureStats,
    required this.stressStats,
  });
}

// --- Main Widget ---

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final HealthService _healthService = HealthService();
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref('healthMonitor/data');

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DailyHealthSummary? _dailySummary;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchDataForDay(_selectedDay!);
  }

  // --- Data Fetching Logic (Retained) ---

  Future<void> _fetchDataForDay(DateTime day) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _dailySummary = null;
    });

    try {
      final postureAndStress = await _getPostureAndStressDataForDay(day);
      final heartRate = await _healthService.getStatsForToday(HealthDataType.HEART_RATE);
      final spo2 = await _healthService.getStatsForToday(HealthDataType.BLOOD_OXYGEN);

      if (mounted) {
        setState(() {
          _dailySummary = DailyHealthSummary(
            heartRateStats: heartRate,
            spo2Stats: spo2,
            postureStats: postureAndStress.item1,
            stressStats: postureAndStress.item2,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load data for this day.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Tuple2<PostureStats, StressStats>> _getPostureAndStressDataForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 1000;
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;

    final event = await _databaseReference
        .orderByKey()
        .startAt(startOfDay.toString())
        .endAt(endOfDay.toString())
        .once();

    if (!event.snapshot.exists) {
      return Tuple2(PostureStats(), StressStats());
    }

    final data = event.snapshot.value as Map<dynamic, dynamic>;
    final rulaScores = <double>[];
    final gsrValues = <double>[];

    data.forEach((key, value) {
      if (value['posture'] != null && value['posture']['rulaScore'] != null) {
        rulaScores.add((value['posture']['rulaScore'] as num).toDouble());
      }
      if (value['stress'] != null && value['stress']['gsrDeviation'] != null) {
        gsrValues.add((value['stress']['gsrDeviation'] as num).toDouble());
      }
    });

    return Tuple2(
      _calculatePostureStats(rulaScores),
      _calculateStressStats(gsrValues),
    );
  }

  PostureStats _calculatePostureStats(List<double> scores) {
    if (scores.isEmpty) return PostureStats();
    return PostureStats(
      minRulaScore: scores.reduce((a, b) => a < b ? a : b),
      maxRulaScore: scores.reduce((a, b) => a > b ? a : b),
      avgRulaScore: scores.reduce((a, b) => a + b) / scores.length,
    );
  }

  StressStats _calculateStressStats(List<double> values) {
    if (values.isEmpty) return StressStats();
    return StressStats(
      minGsr: values.reduce((a, b) => a < b ? a : b),
      maxGsr: values.reduce((a, b) => a > b ? a : b),
      avgGsr: values.reduce((a, b) => a + b) / values.length,
    );
  }

  // --- UI Build Method (Modernized) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Health Calendar', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
      ),
      body: Column(
        children: [
          _buildCalendar(),
          Expanded(
            child: _buildSummarySection(),
          ),
        ],
      ),
    );
  }

  // --- Modernized Widgets ---

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      // ** Using GlassContainer from glass_kit package **
      child: GlassContainer.clearGlass(
        height: 400, // Provide a height for the container
        borderRadius: BorderRadius.circular(20),
        borderColor: Colors.white.withOpacity(0.2),
        blur: 15,
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Add internal padding
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _fetchDataForDay(selectedDay);
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: AppTextStyles.cardTitle.copyWith(fontSize: 18),
              leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.primaryText),
              rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.primaryText),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: AppTextStyles.body,
              weekendTextStyle: AppTextStyles.body.copyWith(color: AppColors.primaryText.withOpacity(0.6)),
              todayDecoration: BoxDecoration(
                color: AppColors.profileColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.profileColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: AppTextStyles.body))
          : _dailySummary != null
          ? _buildSummaryCard(_dailySummary!)
          : Center(child: Text("No health data recorded for this day.", style: AppTextStyles.body)),
    );
  }

  Widget _buildSummaryCard(DailyHealthSummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      // ** Using GlassContainer from glass_kit package **
      child: GlassContainer.clearGlass(
        borderRadius: BorderRadius.circular(20),
        borderColor: Colors.white.withOpacity(0.2),
        blur: 15,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary for ${DateFormat.yMMMd().format(_selectedDay!)}',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryMetric(
                    icon: Icons.favorite,
                    color: AppColors.heartRateColor,
                    label: "Avg. Heart Rate",
                    value: summary.heartRateStats.avg?.toStringAsFixed(0) ?? 'N/A',
                    unit: "BPM",
                  ),
                  _buildSummaryMetric(
                    icon: Icons.bloodtype,
                    color: AppColors.oxygenColor,
                    label: "Avg. SpO2",
                    value: summary.spo2Stats.avg?.toStringAsFixed(0) ?? 'N/A',
                    unit: "%",
                  ),
                  _buildSummaryMetric(
                    icon: Icons.accessibility_new,
                    color: AppColors.postureColor,
                    label: "Avg. RULA Score",
                    value: summary.postureStats.avgRulaScore?.toStringAsFixed(1) ?? 'N/A',
                    unit: "",
                  ),
                  _buildSummaryMetric(
                    icon: Icons.bolt,
                    color: AppColors.stressColor,
                    label: "Avg. GSR Dev.",
                    value: summary.stressStats.avgGsr?.toStringAsFixed(0) ?? 'N/A',
                    unit: "",
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.secondaryInfo.copyWith(color: color)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RichText(
                  text: TextSpan(
                    text: value,
                    style: AppTextStyles.metricValue.copyWith(color: color, fontSize: 24),
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: AppTextStyles.metricUnit.copyWith(color: color, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A simple Tuple class for returning multiple values from a function.
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}
