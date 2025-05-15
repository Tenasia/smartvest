// lib/features/stress_level/stress_level_screen.dart
import 'package:flutter/material.dart';
// import 'package:smartvest/config/app_routes.dart'; // If needed for other navigation

// Style Constants for StressLevelScreen
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _accentColorBlue = Color(0xFF007AFF); // For selected segment button

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _generalCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _segmentButtonTextStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Card 1 (Current Stress Level)
const TextStyle _currentStressValueStyle = TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _currentStressUnitStyle = TextStyle(fontSize: 16, color: _secondaryTextColor); // For "%"
const TextStyle _currentStressTimeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Card 2 (Graph Card)
const TextStyle _graphDateRangeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _graphAverageLabelStyle = TextStyle(fontSize: 14, color: _primaryTextColor);
const TextStyle _graphLegendLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);

// Styles for Card 3 (Summary Card)
const TextStyle _summaryViewAllStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _accentColorBlue);
const TextStyle _summaryTextStyle = TextStyle(fontSize: 14, color: _secondaryTextColor, height: 1.5);
const TextStyle _modalTitleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _modalTextStyle = TextStyle(fontSize: 15, color: _secondaryTextColor, height: 1.5);

// Colors for Bar Chart Legend
const Color _legendLowColor = Colors.green;
const Color _legendNormalColor = Colors.yellow; // Or a light orange
const Color _legendAverageColor = Colors.orange;
const Color _legendHighColor = Colors.red;


class StressLevelScreen extends StatefulWidget {
  const StressLevelScreen({super.key});

  @override
  State<StressLevelScreen> createState() => _StressLevelScreenState();
}

class _StressLevelScreenState extends State<StressLevelScreen> {
  int _selectedSegment = 1; // Default to "Week" as per Figma

  // --- Card 1: Current Stress Level ---
  Widget _buildCurrentStressLevelCard() {
    const String currentStressPercent = "99";
    const String currentTime = "00:00 am";

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Stress Level", style: _generalCardTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RichText(
                  text: TextSpan(
                    text: currentStressPercent,
                    style: _currentStressValueStyle,
                    children: <TextSpan>[
                      TextSpan(text: ' %', style: _currentStressUnitStyle),
                    ],
                  ),
                ),
                Text(currentTime, style: _currentStressTimeStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Segmented Control for Graph Card ---
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

  // --- Helper for Bar Chart Legend Item ---
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: _graphLegendLabelStyle),
      ],
    );
  }

  // --- Card 2: Stress Level Graph Card ---
  Widget _buildStressLevelGraphCard() {
    const String dateRange = "17.02 - 23.02"; // Dummy data
    const String averageStressLevelText = "32-35"; // Dummy data

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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(averageStressLevelText, style: _currentStressValueStyle.copyWith(fontSize: 24)), // Reusing style, adjust if needed
                Text(dateRange, style: _graphDateRangeStyle),
              ],
            ),
            const SizedBox(height: 2),
            const Text("Average level of stress", style: _subtleTextStyle),
            const SizedBox(height: 16),
            // Placeholder for Bar Chart
            Container(
              height: 180, // Adjusted height for bar chart
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
              ),
              child: const Center(child: Text("Bar Chart Placeholder", style: _subtleTextStyle)),
            ),
            const SizedBox(height: 8),
            // X-axis labels for days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((label) => Text(label, style: _chartAxisLabelStyle))
                  .toList(),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(_legendLowColor, "Low"),
                _buildLegendItem(_legendNormalColor, "Normal"),
                _buildLegendItem(_legendAverageColor, "Average"),
                _buildLegendItem(_legendHighColor, "High"),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- Card 3: Summary Card ---
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
                const Text("Summary", style: _generalCardTitleStyle),
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
              style: _summaryTextStyle,
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
                  const Text("Full Stress Level Summary", style: _modalTitleStyle),
                  const SizedBox(height: 16),
                  const Text(
                    "Your stress level today reached a peak of 99% around midnight, which is very high. "
                        "The weekly average stress level is between 32-35, indicating a generally moderate stress baseline with significant peaks. "
                        "The bar chart shows daily fluctuations, with Wednesday and Saturday being particularly high-stress days. "
                        "It's important to identify triggers on these days.\n\n"
                        "Recommendations:\n"
                        "- Practice mindfulness or meditation, especially before bed or during anticipated stressful periods.\n"
                        "- Ensure adequate sleep, as lack of rest can significantly elevate stress.\n"
                        "- Consider light physical activity to help manage stress levels.\n\n"
                        "The legend indicates: Green (Low), Yellow (Normal), Orange (Average), Red (High). Aim to keep your daily stress within the Low to Normal ranges more consistently.",
                    style: _modalTextStyle,
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
        title: const Text('Stress Level Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildCurrentStressLevelCard(),    // Card 1 from Figma
          _buildStressLevelGraphCard(),      // Card 2 from Figma
          _buildSummaryCard(),               // Card 3 from Figma
        ],
      ),
    );
  }
}
