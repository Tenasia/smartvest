// lib/features/heart_rate/heart_rate_screen.dart
import 'package:flutter/material.dart';

// Style Constants for HeartRateScreen
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _accentColorBlue = Color(0xFF007AFF);
const Color _heartRateColor = Color(0xFFF25C54); // Main color for heart rate elements

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _generalCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _segmentButtonTextStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);
const TextStyle _summaryLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor); // For "Maximum", "Minimum", "Average"
const TextStyle _summaryValueStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor); // For "131"
const TextStyle _summaryUnitStyle = TextStyle(fontSize: 12, color: _secondaryTextColor); // For "Heart Rate" sub-label

// Styles for Card 1 (Current Heart Rate)
const TextStyle _currentHrValueStyle = TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _currentHrUnitStyle = TextStyle(fontSize: 16, color: _secondaryTextColor);
const TextStyle _currentHrTimeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Summary Card (Card 4)
const TextStyle _summaryModalTitleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _summaryModalTextStyle = TextStyle(fontSize: 15, color: _secondaryTextColor, height: 1.5);
const TextStyle _summaryViewAllStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _accentColorBlue);
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

class HeartRateScreen extends StatefulWidget {
  const HeartRateScreen({super.key});

  @override
  State<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends State<HeartRateScreen> {
  int _selectedSegment = 1; // Default to "Week" as per Figma

  // --- Card 1: Current Heart Rate ---
  Widget _buildCurrentHeartRateCard() {
    const String currentBpm = "150";
    const String currentTime = "00:00 am";

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), // Adjusted padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Heart Rate", style: _generalCardTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RichText(
                  text: TextSpan(
                    text: currentBpm,
                    style: _currentHrValueStyle,
                    children: <TextSpan>[
                      TextSpan(text: ' BPM', style: _currentHrUnitStyle),
                    ],
                  ),
                ),
                Text(currentTime, style: _currentHrTimeStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper for Card 2: Your Heart Rate Today item ---
  Widget _buildHeartRateTodayItem(String value, String label, String subLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: _summaryValueStyle),
        const SizedBox(height: 2),
        Text(label, style: _summaryLabelStyle),
        Text(subLabel, style: _summaryUnitStyle),
      ],
    );
  }

  // --- Card 2: Your Heart Rate Today ---
  Widget _buildYourHeartRateTodayCard() {
    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your Heart Rate Today", style: _generalCardTitleStyle),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeartRateTodayItem("131", "Maximum", "Heart Rate"),
                _buildHeartRateTodayItem("131", "Minimum", "Heart Rate"),
                _buildHeartRateTodayItem("131", "Average", "Heart Rate"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Segmented Control for Card 3 ---
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _segmentButton("Day", 0),
          _segmentButton("Week", 1),
          _segmentButton("Month", 2),
          _segmentButton("Year", 3),
        ],
      ),
    );
  }

  Widget _segmentButton(String text, int index) {
    bool isSelected = _selectedSegment == index;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedSegment = index;
          // TODO: Add logic to update chart data based on selection
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? _accentColorBlue : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : _secondaryTextColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: isSelected ? 2 : 0,
        textStyle: _segmentButtonTextStyle,
      ),
      child: Text(text),
    );
  }

  // --- Card 3: Heart Rate Graph Card ---
  Widget _buildHeartRateGraphCard() {
    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSegmentedControl(),
            const SizedBox(height: 16),
            Container( // Placeholder for Line Chart
                height: 200,
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300)
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0, top:8.0, bottom: 8.0, right: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [ // Y-axis labels (simplified)
                              Text("8,000", style: _chartAxisLabelStyle), // Example values from Figma
                              Text("4,000", style: _chartAxisLabelStyle),
                              Text("0", style: _chartAxisLabelStyle),
                            ],
                          ),
                        ),
                      ),
                      Padding( // X-axis labels
                        padding: const EdgeInsets.only(top: 4.0, left: 8, right: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun']
                              .map((label) => Text(label, style: _chartAxisLabelStyle))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                )
            ),
            const SizedBox(height: 20),
            // Summary Stats below graph
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeartRateTodayItem("180", "Maximum", "Heart Rate"),
                _buildHeartRateTodayItem("90", "Minimum", "Heart Rate"),
                _buildHeartRateTodayItem("131", "Average", "Heart Rate"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Card 4: Summary Card ---
  Widget _buildSummaryCard() {
    const String summaryText = "Lorem ipsum dolor sit amet consectetur. Dictumst vel at mauris enim maecenas aliquet. Sem turpis eleifend tristique enim mi tincidunt. Velit curabitur aenean leo faci...";

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Summary", style: _generalCardTitleStyle), // Using general title style
                TextButton(
                  onPressed: () {
                    _showSummaryModal(context);
                  },
                  child: const Text("View all", style: _summaryViewAllStyle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summaryText,
              style: _subtleTextStyle.copyWith(fontSize: 14, height: 1.5), // Using _subtleTextStyle
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSummaryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: scrollController,
                children: [
                  const Text("Full Heart Rate Summary", style: _summaryModalTitleStyle),
                  const SizedBox(height: 16),
                  const Text( // Sample detailed text
                    "Your heart rate today showed a peak of 150 BPM around 00:00 am. "
                        "Throughout the day, your maximum recorded heart rate was 180 BPM, typically during periods of activity, while the minimum was 90 BPM during rest. "
                        "Your average heart rate over the past 24 hours is 131 BPM. "
                        "The weekly trend indicates fluctuations consistent with your activity levels, with higher rates on active days (e.g., Tuesday) and lower rates on rest days.\n\n"
                        "Considerations:\n"
                        "- Monitor heart rate during intense activities to ensure it's within a safe range.\n"
                        "- Pay attention to resting heart rate trends over time, as they can indicate changes in fitness or stress levels.",
                    style: _summaryModalTextStyle,
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: _summaryViewAllStyle),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBgColor,
      appBar: AppBar(
        title: const Text('Heart Rate Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildCurrentHeartRateCard(),      // New Card 1
          _buildYourHeartRateTodayCard(),    // New Card 2
          _buildHeartRateGraphCard(),        // New Card 3
          _buildSummaryCard(),               // New Card 4
        ],
      ),
    );
  }
}
