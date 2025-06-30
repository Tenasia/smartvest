import 'package:flutter/material.dart';
import 'package:smartvest/core/services/gemini_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- DESIGN SYSTEM ---
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
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle metricValue = GoogleFonts.poppins(
      fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle metricUnit = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.secondaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.primaryText);
}

// --- DATA MODELS ---
class FirebaseHealthStats {
  final double? min;
  final double? max;
  final double? avg;

  FirebaseHealthStats({this.min, this.max, this.avg});
}

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
  final FirebaseHealthStats heartRateStats;
  final FirebaseHealthStats spo2Stats;
  final PostureStats postureStats;
  final StressStats stressStats;

  DailyHealthSummary({
    required this.heartRateStats,
    required this.spo2Stats,
    required this.postureStats,
    required this.stressStats,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseReference _firebaseDbRef = FirebaseDatabase.instance.ref();
  final GeminiService _geminiService = GeminiService();

  final Map<DateTime, DailyHealthSummary> _healthDataMap = {};
  final Map<DateTime, String> _summaryCache = {};

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DailyHealthSummary? _selectedDaySummary;
  bool _isLoading = false;

  String? _selectedDayAiSummary;
  bool _isGeneratingSummary = false;

  @override
  void initState() {
    super.initState();
    // Start at June 2025 where the data is located
    _focusedDay = DateTime(2025, 6, 30);
    _selectedDay = _focusedDay;
    _fetchDataForMonth(_focusedDay);
  }

  Future<void> _generateDailySummary({bool forceRefresh = false}) async {
    if (_isGeneratingSummary || _selectedDaySummary == null) return;

    final day = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

    if (_summaryCache.containsKey(day) && !forceRefresh) {
      setState(() => _selectedDayAiSummary = _summaryCache[day]);
      return;
    }

    setState(() {
      _isGeneratingSummary = true;
      _selectedDayAiSummary = "Analyzing this day's data...";
    });

    try {
      final summary = _selectedDaySummary!;
      final promptData = StringBuffer();
      promptData.writeln("Analyze the health data for this specific day: ${DateFormat.yMMMMd().format(day)}.");
      promptData.writeln("- Heart Rate: Avg ${summary.heartRateStats.avg?.toStringAsFixed(0) ?? 'N/A'} BPM, Range ${summary.heartRateStats.min?.toStringAsFixed(0) ?? 'N/A'}-${summary.heartRateStats.max?.toStringAsFixed(0) ?? 'N/A'}.");
      promptData.writeln("- Blood Oxygen: Avg ${summary.spo2Stats.avg?.toStringAsFixed(1) ?? 'N/A'}%, Range ${summary.spo2Stats.min?.toStringAsFixed(1) ?? 'N/A'}-${summary.spo2Stats.max?.toStringAsFixed(1) ?? 'N/A'}.");
      promptData.writeln("- Posture Score (RULA): Avg ${summary.postureStats.avgRulaScore?.toStringAsFixed(1) ?? 'N/A'}, Best ${summary.postureStats.minRulaScore?.toStringAsFixed(0) ?? 'N/A'}, Worst ${summary.postureStats.maxRulaScore?.toStringAsFixed(0) ?? 'N/A'}.");
      promptData.writeln("- Stress (GSR): Avg ${summary.stressStats.avgGsr?.toStringAsFixed(0) ?? 'N/A'}, Range ${summary.stressStats.minGsr?.toStringAsFixed(0) ?? 'N/A'}-${summary.stressStats.maxGsr?.toStringAsFixed(0) ?? 'N/A'}.");
      promptData.writeln("\nProvide a concise summary focusing on any notable data points or potential correlations for this day. Offer one actionable tip. Use simple markdown.");

      final result = await _geminiService.getGlobalSummary(promptData.toString());
      if (mounted) {
        setState(() {
          _selectedDayAiSummary = result;
          _summaryCache[day] = result;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _selectedDayAiSummary = "Sorry, an error occurred while generating the summary.");
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      if (!mounted) return;
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedDayAiSummary = null;
        _isGeneratingSummary = false;
      });
      _updateSelectedDaySummary(selectedDay);
    }
  }

  Future<void> _fetchDataForMonth(DateTime month) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted || user == null) return;

    setState(() { _isLoading = true; });

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    print('Fetching data for month: ${DateFormat.yMMM().format(month)}');
    print('Date range: ${firstDayOfMonth.millisecondsSinceEpoch ~/ 1000} to ${lastDayOfMonth.millisecondsSinceEpoch ~/ 1000}');

    try {
      // First, let's get ALL data without filtering to see what's available
      final snapshot = await _firebaseDbRef
          .child('users/${user.uid}/healthData')
          .get();

      final Map<DateTime, List<Map<dynamic, dynamic>>> dailyFirebaseData = {};

      if (snapshot.exists) {
        final firebaseData = snapshot.value as Map<dynamic, dynamic>;
        print('Found ${firebaseData.length} total entries');

        firebaseData.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          // Try both field name variations for compatibility
          final epochTime = entry['epoch_time'] as int? ?? entry['epochTime'] as int?;
          if (epochTime != null) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(epochTime * 1000);
            final day = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);

            print('Entry: $key, epoch: $epochTime, date: ${DateFormat.yMMMd().format(timestamp)}');

            // Only include data for the current month we're viewing
            if (timestamp.year == month.year && timestamp.month == month.month) {
              dailyFirebaseData.putIfAbsent(day, () => []).add(entry);
              print('Added entry for ${DateFormat.yMMMd().format(day)}');
            }
          }
        });
      } else {
        print('No data found in snapshot');
      }

      print('Processed ${dailyFirebaseData.length} days of data for ${DateFormat.yMMM().format(month)}');
      dailyFirebaseData.forEach((day, entries) {
        print('Day: ${DateFormat.yMMMd().format(day)}, entries: ${entries.length}');
      });

      // Clear existing data for this month and add new data
      _healthDataMap.removeWhere((key, value) =>
      key.year == month.year && key.month == month.month);

      final Set<DateTime> allDays = dailyFirebaseData.keys.toSet();
      for (var day in allDays) {
        _healthDataMap[day] = DailyHealthSummary(
          heartRateStats: _calculateVitalStats(dailyFirebaseData[day] ?? [], 'heart_rate'),
          spo2Stats: _calculateVitalStats(dailyFirebaseData[day] ?? [], 'oxygen_saturation'),
          postureStats: _calculatePostureStats(dailyFirebaseData[day] ?? []),
          stressStats: _calculateStressStats(dailyFirebaseData[day] ?? []),
        );
        print('Created summary for ${DateFormat.yMMMd().format(day)}');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _updateSelectedDaySummary(_selectedDay!);
        });
        print('Updated UI with ${_healthDataMap.length} total days of data');
      }
    } catch (e) {
      print('Error fetching calendar data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  FirebaseHealthStats _calculateVitalStats(List<Map<dynamic, dynamic>> entries, String vitalType) {
    if (entries.isEmpty) return FirebaseHealthStats();
    double? min, max;
    double sum = 0;
    int count = 0;
    for (var e in entries) {
      final value = e['vitals']?[vitalType]?.toDouble();
      if (value != null && value > 0) {
        sum += value;
        count++;
        if (min == null || value < min) min = value;
        if (max == null || value > max) max = value;
      }
    }
    return count > 0 ? FirebaseHealthStats(min: min, max: max, avg: sum / count) : FirebaseHealthStats();
  }

  PostureStats _calculatePostureStats(List<Map<dynamic, dynamic>> entries) {
    if (entries.isEmpty) return PostureStats();
    double? min, max;
    double sum = 0;
    int count = 0;
    for (var e in entries) {
      final value = e['posture']?['rula_score']?.toDouble();
      if (value != null && value > 0) {
        sum += value;
        count++;
        if (min == null || value < min) min = value;
        if (max == null || value > max) max = value;
      }
    }
    return count > 0 ? PostureStats(minRulaScore: min, maxRulaScore: max, avgRulaScore: sum / count) : PostureStats();
  }

  StressStats _calculateStressStats(List<Map<dynamic, dynamic>> entries) {
    if (entries.isEmpty) return StressStats();
    double? min, max;
    double sum = 0;
    int count = 0;
    for (var e in entries) {
      final value = e['stress']?['gsr_reading']?.toDouble();
      if (value != null && value >= 0) { // Changed from > 0 to >= 0 to include 0 values
        sum += value;
        count++;
        if (min == null || value < min) min = value;
        if (max == null || value > max) max = value;
      }
    }
    return count > 0 ? StressStats(minGsr: min, maxGsr: max, avgGsr: sum / count) : StressStats();
  }

  void _updateSelectedDaySummary(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    setState(() {
      _selectedDaySummary = _healthDataMap[normalizedDay];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text('Health Calendar', style: AppTextStyles.heading),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryText))),
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchDataForMonth(focusedDay);
              },
              eventLoader: (day) {
                final normalizedDay = DateTime.utc(day.year, day.month, day.day);
                if (_healthDataMap.containsKey(normalizedDay)) return ['data_available'];
                return [];
              },
              headerStyle: HeaderStyle(
                titleCentered: true,
                titleTextStyle: AppTextStyles.cardTitle,
                formatButtonVisible: false,
                leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.primaryText),
                rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.primaryText),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: AppTextStyles.bodyText.copyWith(color: AppColors.primaryText),
                weekendTextStyle: AppTextStyles.bodyText.copyWith(color: AppColors.profileColor),
                outsideTextStyle: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText.withOpacity(0.5)),
                selectedDecoration: const BoxDecoration(color: AppColors.profileColor, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: AppColors.profileColor.withOpacity(0.3), shape: BoxShape.circle),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      right: 5, bottom: 5,
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.heartRateColor),
                        width: 6.0, height: 6.0,
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildSelectedDayData(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayData() {
    if (_selectedDay == null) {
      return const Center(child: Text("Select a day to see details."));
    }

    Widget content;
    if (_selectedDaySummary != null) {
      content = _buildSummaryCard(_selectedDaySummary!);
    } else {
      content = Column(
        children: [
          Icon(Icons.notes_rounded, size: 40, color: AppColors.secondaryText.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _isLoading ? "Loading data..." : "No health data recorded for this day.",
            style: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMMd().format(_selectedDay!), style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
            const Divider(height: 24, thickness: 1, color: AppColors.background),
            content,
          ],
        )
    );
  }

  Widget _buildSummaryCard(DailyHealthSummary summary) {
    return Column(
      children: [
        _buildMetricDetailRow(
            icon: Icons.favorite_rounded, color: AppColors.heartRateColor, label: "Heart Rate",
            stats: { "Avg": summary.heartRateStats.avg?.toStringAsFixed(0) ?? "--", "Min": summary.heartRateStats.min?.toStringAsFixed(0) ?? "--", "Max": summary.heartRateStats.max?.toStringAsFixed(0) ?? "--" },
            unit: "BPM"
        ),
        const Divider(height: 32),
        _buildMetricDetailRow(
            icon: Icons.bloodtype_rounded, color: AppColors.oxygenColor, label: "Blood Oxygen",
            stats: { "Avg": summary.spo2Stats.avg?.toStringAsFixed(1) ?? "--", "Min": summary.spo2Stats.min?.toStringAsFixed(1) ?? "--", "Max": summary.spo2Stats.max?.toStringAsFixed(1) ?? "--" },
            unit: "%"
        ),
        const Divider(height: 32),
        _buildMetricDetailRow(
          icon: Icons.accessibility_new_rounded, color: AppColors.postureColor, label: "Posture Score",
          stats: { "Avg": summary.postureStats.avgRulaScore?.toStringAsFixed(1) ?? "--", "Best": summary.postureStats.minRulaScore?.toStringAsFixed(0) ?? "--", "Worst": summary.postureStats.maxRulaScore?.toStringAsFixed(0) ?? "--" },
        ),
        const Divider(height: 32),
        _buildMetricDetailRow(
          icon: Icons.bolt_rounded, color: AppColors.stressColor, label: "Stress (GSR)",
          stats: { "Avg": summary.stressStats.avgGsr?.toStringAsFixed(0) ?? "--", "Min": summary.stressStats.minGsr?.toStringAsFixed(0) ?? "--", "Max": summary.stressStats.maxGsr?.toStringAsFixed(0) ?? "--" },
        ),
        const Divider(height: 32, thickness: 1, color: AppColors.background),
        _buildAiAnalysisSection(),
      ],
    );
  }

  Widget _buildAiAnalysisSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.profileColor, size: 24),
          const SizedBox(width: 16),
          Text("Daily AI Analysis", style: AppTextStyles.bodyText.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryText, fontSize: 16)),
        ],
      ),
      onExpansionChanged: (isExpanded) {
        if (isExpanded && _selectedDayAiSummary == null) {
          _generateDailySummary();
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _isGeneratingSummary
              ? const Center(child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: AppColors.profileColor),
          ))
              : MarkdownBody(
            data: _selectedDayAiSummary ?? "Expand to generate your analysis for this day.",
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText, fontSize: 14, height: 1.5),
              listBullet: AppTextStyles.bodyText.copyWith(color: AppColors.secondaryText, fontSize: 14, height: 1.5),
              h1: AppTextStyles.cardTitle,
              h2: AppTextStyles.cardTitle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDetailRow({
    required IconData icon,
    required Color color,
    required String label,
    required Map<String, String> stats,
    String? unit
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.cardTitle),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: stats.entries.map((entry) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: AppTextStyles.secondaryInfo),
                          RichText(
                            text: TextSpan(
                                text: entry.value,
                                style: AppTextStyles.bodyText.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.bold),
                                children: [
                                  if (unit != null)
                                    TextSpan(text: ' $unit', style: AppTextStyles.metricUnit.copyWith(fontSize: 12))
                                ]
                            ),
                          )
                        ],
                      )
                  ).toList(),
                )
              ],
            )
        )
      ],
    );
  }
}
