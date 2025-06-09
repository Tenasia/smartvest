import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // For date formatting

// Mock data structures (assuming these are defined as in the previous version)
class DailySummary {
  final double avgHeartRate;
  final String avgStressLevel;
  final double avgPostureScore; // 0.0 to 1.0
  final int sleepDurationHours; // in hours

  DailySummary({
    required this.avgHeartRate,
    required this.avgStressLevel,
    required this.avgPostureScore,
    required this.sleepDurationHours,
  });
}

class DeviationDetails {
  final String heartRateDetails;
  final String stressDetails;
  final String postureDetails;
  final String sleepDetails;

  DeviationDetails({
    required this.heartRateDetails,
    required this.stressDetails,
    required this.postureDetails,
    required this.sleepDetails,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month; // Default format
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _dayForDetails;

  // Mock data (same as your previous version)
  final Map<DateTime, DailySummary> _mockSummaries = {
    DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day - 2): DailySummary(
      avgHeartRate: 75.0, avgStressLevel: "Low", avgPostureScore: 0.85, sleepDurationHours: 7,
    ),
    DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1): DailySummary(
      avgHeartRate: 82.0, avgStressLevel: "Moderate", avgPostureScore: 0.70, sleepDurationHours: 6,
    ),
    DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day): DailySummary(
      avgHeartRate: 78.0, avgStressLevel: "Low", avgPostureScore: 0.90, sleepDurationHours: 8,
    ),
  };

  final Map<DateTime, DeviationDetails> _mockDeviations = {
    DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day - 2): DeviationDetails(
        heartRateDetails: "Peak at 110bpm during morning walk. Min 60bpm during sleep.",
        stressDetails: "One high stress event detected around 3 PM.",
        postureDetails: "Maintained good posture 85% of the time. 5 slouching alerts.",
        sleepDetails: "Deep sleep: 3 hours, Light sleep: 4 hours. Woke up once."
    ),
    DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1): DeviationDetails(
        heartRateDetails: "Slightly elevated average. Max 120bpm during a stressful meeting.",
        stressDetails: "Moderate stress levels throughout the afternoon. 3 stress spikes.",
        postureDetails: "Posture score dropped to 70%. 12 slouching alerts, mainly in the evening.",
        sleepDetails: "Interrupted sleep. Deep sleep: 2 hours."
    ),
    DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day): DeviationDetails(
        heartRateDetails: "Stable heart rate. Range: 65bpm - 100bpm.",
        stressDetails: "Minimal stress. GSR levels remained stable.",
        postureDetails: "Excellent posture (90%). Only 2 minor slouching alerts.",
        sleepDetails: "Good quality sleep. Deep sleep: 4 hours."
    ),
  };

  DailySummary? _selectedDaySummary;
  DeviationDetails? _selectedDayDeviationDetails;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDataForSelectedDay(_selectedDay!);
  }

  void _loadDataForSelectedDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    if (!mounted) return;
    setState(() {
      _selectedDaySummary = _mockSummaries[normalizedDay];
      if (_dayForDetails == normalizedDay) {
        _selectedDayDeviationDetails = _mockDeviations[normalizedDay];
      } else {
        _selectedDayDeviationDetails = null;
      }
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      if (!mounted) return;
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _dayForDetails = null;
        _selectedDayDeviationDetails = null;
      });
      _loadDataForSelectedDay(selectedDay);
    } else {
      if (!mounted) return;
      setState(() {
        if (_dayForDetails == selectedDay) {
          _dayForDetails = null;
          _selectedDayDeviationDetails = null;
        } else {
          _dayForDetails = selectedDay;
          final normalizedDay = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
          _selectedDayDeviationDetails = _mockDeviations[normalizedDay];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Health Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 Weeks',
              CalendarFormat.week: 'Week',
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                if (!mounted) return;
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              if (!mounted) return;
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            headerStyle: HeaderStyle(
              titleTextStyle: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              formatButtonTextStyle: const TextStyle().copyWith(color: Colors.white),
              formatButtonDecoration: BoxDecoration(
                color: Theme.of(context).primaryColorDark,
                borderRadius: BorderRadius.circular(20.0),
              ),
              // THIS IS THE KEY CHANGE: The button will now show the CURRENT format.
              // When tapped, it still cycles to the next available format.
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
            eventLoader: (day) {
              final normalizedDay = DateTime.utc(day.year, day.month, day.day);
              if (_mockSummaries.containsKey(normalizedDay)) {
                return ['summary_available'];
              }
              return [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: _buildEventsMarker(day, events),
                  );
                }
                return null;
              },
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

  Widget _buildEventsMarker(DateTime day, List events) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orangeAccent[400],
      ),
      width: 7.0,
      height: 7.0,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
    );
  }

  Widget _buildSelectedDayData() {
    if (_selectedDay == null) {
      return const Center(child: Text("Select a day to see details."));
    }
    final String formattedDate = DateFormat.yMMMMd().format(_selectedDay!);

    if (_dayForDetails != null && _selectedDayDeviationDetails != null) {
      return _buildDeviationDetailsCard(_selectedDayDeviationDetails!, formattedDate);
    }
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
              const Text("Not enough data to summarize for this day.", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSummaryCard(DailySummary summary, String formattedDate) {
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
            _buildStatRow(Icons.favorite, "Avg. Heart Rate:", "${summary.avgHeartRate.toStringAsFixed(0)} bpm"),
            _buildStatRow(Icons.sentiment_satisfied, "Avg. Stress Level:", summary.avgStressLevel),
            _buildStatRow(Icons.accessibility_new, "Avg. Posture Score:", "${(summary.avgPostureScore * 100).toStringAsFixed(0)}%"),
            _buildStatRow(Icons.bedtime, "Sleep Duration:", "${summary.sleepDurationHours} hours"),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _dayForDetails = _selectedDay;
                    final normalizedDay = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
                    _selectedDayDeviationDetails = _mockDeviations[normalizedDay];
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text("View Deviation Details", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDeviationDetailsCard(DeviationDetails details, String formattedDate) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Deviation Details for: $formattedDate", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent)),
            const Divider(height: 24, thickness: 1),
            _buildDetailItem("Heart Rate Deviations:", details.heartRateDetails),
            _buildDetailItem("Stress Event Details:", details.stressDetails),
            _buildDetailItem("Posture Correction Log:", details.postureDetails),
            _buildDetailItem("Sleep Pattern Notes:", details.sleepDetails),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _dayForDetails = null;
                    _selectedDayDeviationDetails = null;
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                child: const Text("Back to Summary", style: TextStyle(color: Colors.white)),
              ),
            )
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
          Text("$label ", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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

  Widget _buildDetailItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4)),
        ],
      ),
    );
  }
}