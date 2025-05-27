// lib/features/posture/posture_screen.dart
import 'package:flutter/material.dart';

// Define colors and styles needed for this screen
const Color _screenBgColor = Color(0xFFF5F5F5);
const Color _cardBgColor = Colors.white;
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _accentColorBlue = Color(0xFF007AFF);
const Color _accentColorOrange = Color(0xFFFFA000);
const Color _accentColorGreen = Color(0xFF27AE60);
const Color _accentColorRed = Color(0xFFF25C54); // For "Worst" angle
const Color _accentColorYellow = Color(0xFFFFD60A); // For "Average" angle in the new design

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);

const double _cardElevation = 1.5;

const TextStyle _screenTitleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _cardGeneralTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);

// Styles for Card 1 (Posture Overview)
const TextStyle _overviewLabelStyle = TextStyle(fontSize: 13, color: _secondaryTextColor);
const TextStyle _overviewValueStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _accentColorBlue);
const TextStyle _overviewTimeStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _overviewStatusValueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _accentColorBlue);
const TextStyle _overviewAngleValueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryTextColor);

// Styles for Card 2 & 5 (Circular Progress Items)
const TextStyle _circularProgressValueStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
const TextStyle _circularProgressLabelStyle = TextStyle(fontSize: 13, color: _secondaryTextColor);
const TextStyle _circularProgressSubLabelStyle = TextStyle(fontSize: 11, color: _secondaryTextColor);

// Styles for Card 3 (Graph Card)
const TextStyle _segmentButtonTextStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);
const TextStyle _summaryLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _summaryValueStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

// Styles for Card 4 (Summary Card)
const TextStyle _summaryCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _summaryViewAllStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _accentColorBlue);
const TextStyle _summaryTextStyle = TextStyle(fontSize: 14, color: _secondaryTextColor, height: 1.5);
const TextStyle _modalTitleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _modalTextStyle = TextStyle(fontSize: 15, color: _secondaryTextColor, height: 1.5);


class PostureScreen extends StatefulWidget {
  const PostureScreen({super.key});

  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  int _selectedSegment = 0;

  // --- Helper for Card 1: Posture Overview ---
  Widget _buildPostureOverviewCard() {
    const String postureIndexValue = "68%";
    const String postureTime = "00:00 am";
    const String postureStatus = "Average";
    const String postureAngle = "0°";

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
            const Text("Posture", style: _cardGeneralTitleStyle),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Posture Index", style: _overviewLabelStyle),
                      const SizedBox(height: 4),
                      Text(postureIndexValue, style: _overviewValueStyle),
                      const SizedBox(height: 4),
                      Text(postureTime, style: _overviewTimeStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Posture Status", style: _overviewLabelStyle),
                      const SizedBox(height: 4),
                      Text(postureStatus, style: _overviewStatusValueStyle),
                      const SizedBox(height: 12),
                      const Text("Posture Angle", style: _overviewLabelStyle),
                      const SizedBox(height: 4),
                      Text(postureAngle, style: _overviewAngleValueStyle),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper for Card 2 & 5: Circular Progress Item ---
  Widget _buildCircularItem(String value, String label, String subLabel, Color progressColor, {double progress = 0.68}) {
    return Column(
      children: [
        SizedBox(
          height: 90,
          width: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 90,
                width: 90,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Text(
                value,
                style: _circularProgressValueStyle.copyWith(color: progressColor, fontSize: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: _circularProgressLabelStyle),
        Text(subLabel, style: _circularProgressSubLabelStyle),
      ],
    );
  }

  // --- Helper for Card 2: Your Posture Index Today ---
  Widget _buildYourPostureIndexTodayCard() {
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
            const Text(
              "Your Posture Index Today",
              style: _cardGeneralTitleStyle,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularItem("68%", "Best", "Posture Index", _accentColorBlue),
                _buildCircularItem("68%", "Worst", "Posture Index", _accentColorOrange),
                _buildCircularItem("68%", "Average", "Posture Index", _accentColorGreen),
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

  // --- Helper for Card 3: Summary Item Below Graph ---
  Widget _buildPostureIndexSummaryItem(String value, String label, String subLabel, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: _summaryValueStyle.copyWith(color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: _summaryLabelStyle),
        Text(subLabel, style: _subtleTextStyle.copyWith(fontSize: 10)),
      ],
    );
  }

  // --- Card 3: Posture Graph Card ---
  Widget _buildPostureGraphCard() {
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
            Container(
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
                            children: [
                              Text("100", style: _chartAxisLabelStyle),
                              Text("50", style: _chartAxisLabelStyle),
                              Text("0", style: _chartAxisLabelStyle),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 16, right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00']
                              .map((label) => Text(label, style: _chartAxisLabelStyle))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                )
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPostureIndexSummaryItem("68%", "Best", "Posture Index", _accentColorBlue), // Note: Figma shows angle here, but label is Index
                _buildPostureIndexSummaryItem("68%", "Worst", "Posture Index", _accentColorOrange),
                _buildPostureIndexSummaryItem("68%", "Average", "Posture Index", _accentColorGreen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Card 4: Summary Card (NEW) ---
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
                const Text("Summary", style: _summaryCardTitleStyle),
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
              maxLines: 3, // Show a snippet
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
      isScrollControlled: true, // Important for longer content
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, // Start at 60% of screen height
          minChildSize: 0.3,    // Min at 30%
          maxChildSize: 0.9,    // Max at 90%
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: ListView( // Use ListView for potentially long summary
                controller: scrollController,
                children: [
                  Text("Full Posture Summary", style: _modalTitleStyle),
                  const SizedBox(height: 16),
                  Text(
                    "Today, your overall posture index was 68%, which is considered average. "
                        "Your best posture was maintained around 2:00 PM, reaching an index of 85% with an angle of 2°. "
                        "However, there were periods, notably around 10:00 AM and 4:00 PM, where your posture index dropped to 45% (worst) with an angle of 15°, indicating significant slouching. "
                        "This typically occurred during prolonged sitting. \n\n"
                        "Recommendations:\n"
                        "- Take short breaks every 30-60 minutes to stand and stretch.\n"
                        "- Be mindful of your back support when sitting.\n"
                        "- Consider ergonomic adjustments to your workspace.\n\n"
                        "Focus on maintaining an upright position, especially during tasks that require concentration. Your average posture angle today was 5°, which is good, but consistency is key to avoiding strain.",
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


  // --- Card 5: Your Posture Angle Today (Adjusted Colors) ---
  Widget _buildYourPostureAngleTodayCard() {
    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Posture Angle Today",
              style: _cardGeneralTitleStyle,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularItem("68°", "Best", "Posture Angle", _accentColorGreen), // Green for Best
                _buildCircularItem("68°", "Worst", "Posture Angle", _accentColorRed),   // Red for Worst
                _buildCircularItem("68°", "Average", "Posture Angle", _accentColorYellow),// Yellow for Average
              ],
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBgColor,
      appBar: AppBar(
        title: const Text('Posture Details', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _screenBgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildPostureOverviewCard(),
          _buildYourPostureIndexTodayCard(),
          _buildPostureGraphCard(),
          _buildYourPostureAngleTodayCard(), // Adjusted Posture Angle Card
          _buildSummaryCard(), // New Summary Card Added
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Data is for informational purposes only. Not for clinical use.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
