// lib/features/smart_vest/smart_vest_screen.dart
import 'package:flutter/material.dart';
// import 'package:smartvest/config/app_routes.dart'; // If needed for other navigation

// Style Constants for SmartVestScreen
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _accentColorBlue = Color(0xFF007AFF); // For selected segment button
const Color _deviceTitleColor = Color(0xFF333333); // For "Smart Body Vest" title

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _generalCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _segmentButtonTextStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Card 1 (Battery Status)
const TextStyle _batteryStatusTitleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _primaryTextColor);
const TextStyle _batteryPercentageStyle = TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _batteryTimeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Card 2 (Usage Graph Card)
const TextStyle _usageGraphTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor); // Not explicitly in Figma, but good for card title
const TextStyle _usageTimeStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _usageLabelStyle = TextStyle(fontSize: 13, color: _secondaryTextColor); // "Daily average usage"
const TextStyle _usageDateRangeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Card 3 (Summary Card)
const TextStyle _summaryViewAllStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _accentColorBlue);
const TextStyle _summaryTextStyle = TextStyle(fontSize: 14, color: _secondaryTextColor, height: 1.5);
const TextStyle _modalTitleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _modalTextStyle = TextStyle(fontSize: 15, color: _secondaryTextColor, height: 1.5);


class SmartVestScreen extends StatefulWidget {
  const SmartVestScreen({super.key});

  @override
  State<SmartVestScreen> createState() => _SmartVestScreenState();
}

class _SmartVestScreenState extends State<SmartVestScreen> {
  int _selectedSegment = 1; // Default to "Week" as per Figma

  // --- Card 1: Battery Status ---
  Widget _buildBatteryStatusCard() {
    const String batteryPercentage = "99";
    const String lastChargedTime = "00:00 am"; // Example time

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
            const Text("Battery Status", style: _batteryStatusTitleStyle),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                RichText(
                  text: TextSpan(
                    text: batteryPercentage,
                    style: _batteryPercentageStyle,
                    children: <TextSpan>[
                      TextSpan(text: ' %', style: _currentStressUnitStyle.copyWith(fontSize: 18)), // Reusing style, adjust if needed
                    ],
                  ),
                ),
                Text(lastChargedTime, style: _batteryTimeStyle),
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

  // --- Card 2: Daily Average Usage Graph Card ---
  Widget _buildUsageGraphCard() {
    const String dateRange = "17.02 - 23.02";
    const String averageUsageTime = "6h 18m";

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end, // Align items to bottom
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(averageUsageTime, style: _usageTimeStyle),
                    const SizedBox(height: 2),
                    const Text("Daily average usage", style: _usageLabelStyle),
                  ],
                ),
                // Dropdown for date range (simplified as text for now)
                Row(
                  children: [
                    Text(dateRange, style: _usageDateRangeStyle),
                    Icon(Icons.arrow_drop_down, color: _secondaryTextColor, size: 20),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            // Placeholder for Bar Chart
            Container(
              height: 180,
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
              ),
              child: const Center(child: Text("Usage Bar Chart Placeholder\n(Mon-Sun data with usage hours)", textAlign: TextAlign.center ,style: _subtleTextStyle)),
            ),
            const SizedBox(height: 8),
            // X-axis labels for days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((label) => Text(label, style: _chartAxisLabelStyle))
                  .toList(),
            ),
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
                  const Text("Smart Vest Usage Summary", style: _modalTitleStyle),
                  const SizedBox(height: 16),
                  const Text(
                    "Your Smart Vest battery is currently at 99%, last charged at 00:00 am. "
                        "This week, your daily average usage of the Smart Vest has been 6 hours and 18 minutes. "
                        "The usage pattern shows consistent wear during weekdays, with peak usage on Thursday and Friday. Weekend usage is slightly lower. \n\n"
                        "Monitoring your usage helps in understanding how consistently you are benefiting from the Smart Vest's posture correction and health tracking features. "
                        "Ensure the device is charged regularly to maintain optimal performance and continuous data collection.",
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
        leading: IconButton( // Added back button
          icon: const Icon(Icons.arrow_back, color: _primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: _deviceTitleColor, size: 24), // Placeholder vest icon
            SizedBox(width: 8),
            Text('Smart Body Vest', style: TextStyle(color: _deviceTitleColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: _screenBgColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildBatteryStatusCard(),
          _buildUsageGraphCard(),
          _buildSummaryCard(),
        ],
      ),
    );
  }
}

// Placeholder for styles that might be used if not defined above
const TextStyle _currentStressUnitStyle = TextStyle(fontSize: 16, color: _secondaryTextColor);
