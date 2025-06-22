import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:smartvest/core/services/health_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// A new data class to hold the summarized stats for a single day.
class DailyHealthSummary {
  final HealthStats heartRateStats;
  final HealthStats spo2Stats;

  DailyHealthSummary({required this.heartRateStats, required this.spo2Stats});
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final HealthService _healthService = HealthService();

  // Holds the fetched and processed data for each day.
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
    // Fetch data for the initial month when the screen loads.
    _fetchDataForMonth(_focusedDay);
  }

  /// Fetches all heart rate and SpO2 data for the entire month of the given day,
  /// processes it, and stores it in the `_healthDataMap`.
  Future<void> _fetchDataForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // Fetch both data types in parallel for efficiency.
    final List<List<HealthDataPoint>> results = await Future.wait([
      _healthService.getHealthData(firstDayOfMonth, lastDayOfMonth, HealthDataType.HEART_RATE),
      _healthService.getHealthData(firstDayOfMonth, lastDayOfMonth, HealthDataType.BLOOD_OXYGEN),
    ]);

    final heartRateData = results[0];
    final spo2Data = results[1];

    // Group data by day.
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

    // Process each day's data into a summary.
    final Set<DateTime> allDays = {...dailyHrData.keys, ...dailySpo2Data.keys};
    for (var day in allDays) {
      _healthDataMap[day] = DailyHealthSummary(
        heartRateStats: _calculateStats(dailyHrData[day] ?? []),
        spo2Stats: _calculateStats(dailySpo2Data[day] ?? []),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        // After fetching, update the summary for the currently selected day.
        _updateSelectedDaySummary(_selectedDay!);
      });
    }
  }

  /// Helper function to calculate stats from a list of data points.
  HealthStats _calculateStats(List<HealthDataPoint> points) {
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

  /// Updates the summary display based on the data in our map.
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
              // Fetch data for the new month if we haven't already.
              _fetchDataForMonth(focusedDay);
            },
            // Load events (markers) for days that have data in our map.
            eventLoader: (day) {
              final normalizedDay = DateTime.utc(day.year, day.month, day.day);
              if (_healthDataMap.containsKey(normalizedDay)) {
                return ['data_available'];
              }
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

            // Heart Rate Section
            const Text("Heart Rate (BPM)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildStatRow(Icons.favorite, "Average:", summary.heartRateStats.avg?.toStringAsFixed(0) ?? 'N/A'),
            _buildStatRow(Icons.arrow_downward, "Minimum:", summary.heartRateStats.min?.toStringAsFixed(0) ?? 'N/A'),
            _buildStatRow(Icons.arrow_upward, "Maximum:", summary.heartRateStats.max?.toStringAsFixed(0) ?? 'N/A'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // SpO2 Section
            const Text("Blood Oxygen (SpO2)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildStatRow(Icons.bloodtype, "Average:", "${summary.spo2Stats.avg?.toStringAsFixed(0) ?? 'N/A'}%"),
            _buildStatRow(Icons.arrow_downward, "Minimum:", "${summary.spo2Stats.min?.toStringAsFixed(0) ?? 'N/A'}%"),
            _buildStatRow(Icons.arrow_upward, "Maximum:", "${summary.spo2Stats.max?.toStringAsFixed(0) ?? 'N/A'}%"),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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
