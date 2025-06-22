import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

// --- Expanded Data Models to include Posture and Stress ---

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

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final HealthService _healthService = HealthService();
  final DatabaseReference _firebaseDbRef = FirebaseDatabase.instance.ref('healthMonitor/data');

  final Map<DateTime, DailyHealthSummary> _healthDataMap = {};

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DailyHealthSummary? _selectedDaySummary;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchDataForMonth(_focusedDay);
  }

  Future<void> _fetchDataForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // --- Fetch from both Health Connect and Firebase in parallel ---
    final results = await Future.wait([
      // Health Connect Data
      _healthService.getHealthData(firstDayOfMonth, lastDayOfMonth, HealthDataType.HEART_RATE),
      _healthService.getHealthData(firstDayOfMonth, lastDayOfMonth, HealthDataType.BLOOD_OXYGEN),

      // Firebase Data
      _firebaseDbRef
          .orderByChild('timestamp')
          .startAt(firstDayOfMonth.millisecondsSinceEpoch.toString())
          .endAt(lastDayOfMonth.millisecondsSinceEpoch.toString())
          .once(),
    ]);

    // --- Process Health Connect Data ---
    final heartRateData = results[0] as List<HealthDataPoint>;
    final spo2Data = results[1] as List<HealthDataPoint>;

    final Map<DateTime, List<HealthDataPoint>> dailyHrData = {};
    for (var p in heartRateData) {
      final day = DateTime.utc(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day);
      dailyHrData.putIfAbsent(day, () => []).add(p);
    }

    final Map<DateTime, List<HealthDataPoint>> dailySpo2Data = {};
    for (var p in spo2Data) {
      final day = DateTime.utc(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day);
      dailySpo2Data.putIfAbsent(day, () => []).add(p);
    }

    // --- Process Firebase Data ---
    final firebaseSnapshot = results[2] as DatabaseEvent;
    final Map<DateTime, List<Map<dynamic, dynamic>>> dailyFirebaseData = {};
    if (firebaseSnapshot.snapshot.value != null) {
      final firebaseData = firebaseSnapshot.snapshot.value as Map<dynamic, dynamic>;
      firebaseData.forEach((key, value) {
        final entry = value as Map<dynamic, dynamic>;
        final timestampStr = entry['timestamp']?.toString();
        if (timestampStr != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
          final day = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
          dailyFirebaseData.putIfAbsent(day, () => []).add(entry);
        }
      });
    }

    // --- Combine and Calculate All Stats ---
    final Set<DateTime> allDays = {...dailyHrData.keys, ...dailySpo2Data.keys, ...dailyFirebaseData.keys};
    for (var day in allDays) {
      _healthDataMap[day] = DailyHealthSummary(
        heartRateStats: _calculateHealthConnectStats(dailyHrData[day] ?? []),
        spo2Stats: _calculateHealthConnectStats(dailySpo2Data[day] ?? []),
        postureStats: _calculatePostureStats(dailyFirebaseData[day] ?? []),
        stressStats: _calculateStressStats(dailyFirebaseData[day] ?? []),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _updateSelectedDaySummary(_selectedDay!);
      });
    }
  }

  HealthStats _calculateHealthConnectStats(List<HealthDataPoint> points) {
    if (points.isEmpty) return HealthStats();
    double? min, max;
    double sum = 0;
    for (var p in points) {
      final value = (p.value as NumericHealthValue).numericValue.toDouble();
      sum += value;
      if (min == null || value < min) min = value;
      if (max == null || value > max) max = value;
    }
    return HealthStats(min: min, max: max, avg: sum / points.length);
  }

  PostureStats _calculatePostureStats(List<Map<dynamic, dynamic>> entries) {
    if (entries.isEmpty) return PostureStats();
    double? min, max;
    double sum = 0;
    for (var e in entries) {
      final value = e['posture']?['rulaScore']?.toDouble();
      if (value != null) {
        sum += value;
        if (min == null || value < min) min = value;
        if (max == null || value > max) max = value;
      }
    }
    return PostureStats(minRulaScore: min, maxRulaScore: max, avgRulaScore: sum / entries.length);
  }

  StressStats _calculateStressStats(List<Map<dynamic, dynamic>> entries) {
    if (entries.isEmpty) return StressStats();
    double? min, max;
    double sum = 0;
    for (var e in entries) {
      final value = e['stress']?['gsrReading']?.toDouble();
      if (value != null) {
        sum += value;
        if (min == null || value < min) min = value;
        if (max == null || value > max) max = value;
      }
    }
    return StressStats(minGsr: min, maxGsr: max, avgGsr: sum / entries.length);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      if (!mounted) return;
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _updateSelectedDaySummary(selectedDay);
    }
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
      appBar: AppBar(
        title: const Text('Daily Health Calendar'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
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
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1, bottom: 1,
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent[400]),
                      width: 7.0, height: 7.0,
                    ),
                  );
                }
                return null;
              },
            ),
            headerStyle: HeaderStyle(
              titleTextStyle: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              formatButtonTextStyle: const TextStyle().copyWith(color: Colors.white),
              formatButtonDecoration: BoxDecoration(
                color: Theme.of(context).primaryColorDark,
                borderRadius: BorderRadius.circular(20.0),
              ),
              formatButtonShowsNext: false,
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                shape: BoxShape.circle,
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
    final String formattedDate = DateFormat.yMMMMd().format(_selectedDay!);

    if (_selectedDaySummary != null) {
      return _buildSummaryCard(_selectedDaySummary!, formattedDate);
    } else {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              Text(
                  _isLoading ? "Loading data..." : "No health data recorded for this day.",
                  style: const TextStyle(fontSize: 16, color: Colors.grey)
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSummaryCard(DailyHealthSummary summary, String formattedDate) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Summary for: $formattedDate", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(height: 24, thickness: 1),

            _buildStatSection("Heart Rate (BPM)", Icons.favorite, [
              _buildStatRow("Average:", summary.heartRateStats.avg?.toStringAsFixed(0) ?? 'N/A'),
              _buildStatRow("Minimum:", summary.heartRateStats.min?.toStringAsFixed(0) ?? 'N/A'),
              _buildStatRow("Maximum:", summary.heartRateStats.max?.toStringAsFixed(0) ?? 'N/A'),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            _buildStatSection("Blood Oxygen (SpO2)", Icons.bloodtype, [
              _buildStatRow("Average:", "${summary.spo2Stats.avg?.toStringAsFixed(1) ?? 'N/A'}%"),
              _buildStatRow("Minimum:", "${summary.spo2Stats.min?.toStringAsFixed(1) ?? 'N/A'}%"),
              _buildStatRow("Maximum:", "${summary.spo2Stats.max?.toStringAsFixed(1) ?? 'N/A'}%"),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            _buildStatSection("Posture (RULA Score)", Icons.accessibility_new, [
              _buildStatRow("Average:", summary.postureStats.avgRulaScore?.toStringAsFixed(1) ?? 'N/A'),
              _buildStatRow("Worst Score:", summary.postureStats.maxRulaScore?.toStringAsFixed(0) ?? 'N/A'),
              _buildStatRow("Best Score:", summary.postureStats.minRulaScore?.toStringAsFixed(0) ?? 'N/A'),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            _buildStatSection("Stress (GSR)", Icons.bolt, [
              _buildStatRow("Average:", summary.stressStats.avgGsr?.toStringAsFixed(0) ?? 'N/A'),
              _buildStatRow("Minimum:", summary.stressStats.minGsr?.toStringAsFixed(0) ?? 'N/A'),
              _buildStatRow("Maximum:", summary.stressStats.maxGsr?.toStringAsFixed(0) ?? 'N/A'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSection(String title, IconData icon, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...rows,
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black54)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}