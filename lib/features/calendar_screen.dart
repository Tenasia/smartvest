// smartvest/lib/features/home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartvest/config/app_routes.dart'; // Ensure AppRoutes is imported

// Style Constants
const Color _scaffoldBgColor = Color(0xFFF5F5F5);
const Color _dashboardContentBgColor = Colors.white;
const double _dashboardCornerRadius = 50.0;

const Color _cardBgColor = Colors.white;

const Color _primaryAppColor = Color(0xFF4A79FF);
const Color _primaryTextColor = Color(0xFF333333);
const Color _secondaryTextColor = Color(0xFF757575);
const Color _statusGoodColor = Color(0xFF27AE60);
const Color _statusAverageColor = Color(0xFF007AFF);
const Color _statusExcellentColor = Color(0xFF00A099);
const Color _statusLowColorGeneral = Color(0xFF56CCF2);

const Color _heartIconColor = Color(0xFFF25C54);
const Color _heartRateValueColor = Color(0xFF333333);
const Color _heartRateAverageTextColor = Color(0xFF666666);

const Color _hrvStatusVeryLowColor = Color(0xFFF25C54);
const Color _stressIconColor = Color(0xFFFFA000);
const Color _stressValueColor = Color(0xFF333333);

const Color _deviceBatteryGoodColor = Color(0xFF27AE60);
const Color _deviceTitleIconColor = _primaryAppColor;

final BorderRadius _cardBorderRadius = BorderRadius.circular(12.0);
const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
const double _cardElevation = 1.5;

const TextStyle _cardTitleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _secondaryTextColor);
const TextStyle _statValueStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _statLabelStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);
const TextStyle _mainValueLargeStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _mainValueSmallStyle = TextStyle(fontSize: 14, color: _primaryTextColor);
const TextStyle _subtleTextStyle = TextStyle(fontSize: 12, color: _secondaryTextColor);

const TextStyle _postureStatusLabelStyle = TextStyle(fontSize: 14, color: _secondaryTextColor);
const TextStyle _postureStatusValueStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _statusAverageColor);
const TextStyle _postureAngleLabelStyle = TextStyle(fontSize: 14, color: _secondaryTextColor);
const TextStyle _postureAngleValueStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _postureCircularPercentageStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _statusAverageColor);

const TextStyle _heartRateBPMStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _heartRateValueColor);
const TextStyle _heartRateUnitStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: _secondaryTextColor);
const TextStyle _heartRateAverageStyle = TextStyle(fontSize: 13, color: _heartRateAverageTextColor);
const TextStyle _chartAxisLabelStyle = TextStyle(fontSize: 10, color: _secondaryTextColor);

const TextStyle _hrvCardTitleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _hrvStatusTextStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: _hrvStatusVeryLowColor);
const TextStyle _hrvValueStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _hrvStatusVeryLowColor);
const TextStyle _hrvUnitStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: _hrvStatusVeryLowColor);
const TextStyle _hrvDescriptionStyle = TextStyle(fontSize: 12, color: _secondaryTextColor, height: 1.3);

const TextStyle _stressCardTitleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _stressValueStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _stressValueColor);
const TextStyle _stressDescriptionStyle = TextStyle(fontSize: 12, color: _secondaryTextColor, height: 1.3);

const TextStyle _deviceCardTitleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor);
const TextStyle _deviceStatusLabelStyle = TextStyle(fontSize: 13, color: _secondaryTextColor);
const TextStyle _deviceBatteryPercentageStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryTextColor);


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    _user = _auth.currentUser;
    if (_user != null) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _firestore.collection('users').doc(_user!.uid).get();
        if (mounted && snapshot.exists) {
          setState(() { _userData = snapshot.data(); });
        }
      } catch (e) {
        print("Error fetching user data: $e");
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    } else {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  int? _calculateAge(Timestamp? birthdayTimestamp) {
    if (birthdayTimestamp == null) return null;
    DateTime birthday = birthdayTimestamp.toDate();
    DateTime today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  Widget _buildInfoStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: _statValueStyle, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: _statLabelStyle, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildUserDetailsCard() {
    final String firstName = _userData?['firstName'] ?? 'User';
    final String location = "Manila, Philippines";
    String? photoUrl = _userData?['photoURL'] ?? _user?.photoURL;
    photoUrl = (photoUrl == null || photoUrl.isEmpty) ? "https://via.placeholder.com/100/${_primaryAppColor.value.toRadixString(16).substring(2)}/FFFFFF?Text=${firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U'}" : photoUrl;


    final Timestamp? birthdayTimestamp = _userData?['birthday'] as Timestamp?;
    final int? age = _calculateAge(birthdayTimestamp);
    final int? heightCm = _userData?['heightCm'] as int?;
    final double? weightKg = _userData?['weightKg'] as double?;

    return Card(
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
      color: _cardBgColor,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, $firstName!",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: NetworkImage(photoUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    print("Error loading profile image: $exception");
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoStatItem(age != null ? age.toString() : '--', 'Age'),
                _buildInfoStatItem(heightCm != null ? '${heightCm}cm' : '--', 'Height'),
                _buildInfoStatItem(weightKg != null ? '${weightKg.toStringAsFixed(0)}kg' : '--', 'Weight'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTemplate({
    required IconData icon,
    required String title,
    required Widget content,
    Color titleIconColor = _primaryAppColor,
    TextStyle titleStyle = _cardTitleStyle,
  }) {
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
            Row(
              children: [
                Icon(icon, color: titleIconColor, size: 20),
                const SizedBox(width: 8),
                Text(title.toUpperCase(), style: titleStyle),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildPostureCard() {
    const String postureStatus = "Average";
    const double postureValue = 0.68;
    const String posturePercentageText = "68%";
    const String postureAngle = "0°";

    final postureContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 100,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  value: postureValue,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(_statusAverageColor),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.accessibility_new_rounded,
                    color: _statusAverageColor,
                    size: 36,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    posturePercentageText,
                    style: _postureCircularPercentageStyle,
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Posture Status', style: _postureStatusLabelStyle),
              const SizedBox(height: 2),
              Text(postureStatus, style: _postureStatusValueStyle),
              const SizedBox(height: 12),
              const Text('Posture Angle', style: _postureAngleLabelStyle),
              const SizedBox(height: 2),
              Text(postureAngle, style: _postureAngleValueStyle),
            ],
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () {
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.postureScreen);
        }
      },
      borderRadius: _cardBorderRadius,
      child: _buildCardTemplate(
        icon: Icons.accessibility_new_rounded,
        title: 'POSTURE',
        titleIconColor: _statusAverageColor,
        content: postureContent,
      ),
    );
  }

  Widget _buildHeartRateCard() {
    const String currentBpm = "150";
    const String averageBpm = "90";

    final heartRateContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, color: _heartIconColor, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: currentBpm,
                      style: _heartRateBPMStyle,
                      children: <TextSpan>[
                        TextSpan(text: ' BPM', style: _heartRateUnitStyle.copyWith(color: _secondaryTextColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.red,
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
            text: TextSpan(
                text: 'Average Heart Rate in 24 Hours: ',
                style: _heartRateAverageStyle,
                children: <TextSpan>[
                  TextSpan(text: averageBpm, style: _heartRateAverageStyle.copyWith(fontWeight: FontWeight.bold, color: _primaryTextColor)),
                  TextSpan(text: ' BPM', style: _heartRateAverageStyle),
                ])),
        const SizedBox(height: 16),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Text('Line Chart Placeholder', style: _subtleTextStyle)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['00', '04', '08', '12', '16', '20', '24']
              .map((label) => Text(label, style: _chartAxisLabelStyle))
              .toList(),
        ),
      ],
    );

    return InkWell(
      onTap: () {
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.heartRateScreen);
        }
      },
      borderRadius: _cardBorderRadius,
      child: _buildCardTemplate(
        icon: Icons.monitor_heart_outlined,
        title: 'HEART RATE',
        titleIconColor: _heartIconColor,
        content: heartRateContent,
      ),
    );
  }

  Widget _buildHrvCard() {
    const String hrvStatus = "Very Low";
    const String hrvValue = "35";
    const String hrvDescription = "High stress detected! Take deep breaths and rest.";

    return Expanded(
      child: Card(
        elevation: _cardElevation,
        shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        color: _cardBgColor,
        child: Padding(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("HRV", style: _hrvCardTitleStyle),
              const SizedBox(height: 4),
              Text(hrvStatus, style: _hrvStatusTextStyle),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  text: hrvValue,
                  style: _hrvValueStyle,
                  children: <TextSpan>[
                    TextSpan(text: 'ms', style: _hrvUnitStyle),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.red],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  hrvDescription,
                  style: _hrvDescriptionStyle,
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStressLevelCard() {
    const String stressPercentage = "99%";
    const double stressProgressValue = 0.99;
    const String stressDescription = "You're under high stress. Try deep breathing or a quick stretch to reset.";

    final homeStressContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_very_dissatisfied_rounded, color: _stressIconColor, size: 36),
            const SizedBox(width: 8),
            Text(stressPercentage, style: _stressValueStyle),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stressProgressValue,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(_stressIconColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: Text(
            stressDescription,
            style: _stressDescriptionStyle,
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ),
      ],
    );

    return Expanded(
      child: Material(
        color: _cardBgColor,
        borderRadius: _cardBorderRadius,
        elevation: _cardElevation,
        child: InkWell(
          onTap: () {
            if (mounted) {
              Navigator.pushNamed(context, AppRoutes.stressLevelScreen);
            }
          },
          borderRadius: _cardBorderRadius,
          child: Padding(
              padding: _cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Stress Level", style: _stressCardTitleStyle),
                  const SizedBox(height: 12),
                  homeStressContent,
                ],
              )
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    const String batteryPercentage = "99%";
    const double batteryLevel = 0.99;

    Widget vestIconPlaceholder = Icon(
      Icons.shield_outlined,
      size: 40,
      color: _deviceTitleIconColor,
    );

    final deviceCardContent = Row(
      children: [
        vestIconPlaceholder,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Vest Connected',
                style: _statValueStyle.copyWith(fontSize: 16, color: _statusGoodColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Battery: $batteryPercentage',
                style: _subtleTextStyle,
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: _secondaryTextColor.withOpacity(0.7)),
      ],
    );

    return InkWell(
      onTap: () {
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.smartVestScreen);
        }
      },
      borderRadius: _cardBorderRadius,
      child: Card(
        elevation: _cardElevation,
        shape: RoundedRectangleBorder(borderRadius: _cardBorderRadius),
        color: _cardBgColor,
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Padding(
          padding: _cardPadding,
          // The _buildCardTemplate includes a title row, which is not what the
          // new Device Card design on home screen has.
          // So, we directly use the deviceCardContent.
          // If a title bar was needed like other cards, _buildCardTemplate would be used.
          child: deviceCardContent,
        ),
      ),
    );
  }


  Widget _buildConnectDeviceNotice(String message) {
    final noticeContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: _secondaryTextColor),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.bluetooth_searching_rounded),
          label: const Text('Connect Device'),
          onPressed: () {
            if(mounted) Navigator.pushNamed(context, AppRoutes.searchAndConnect);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryAppColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );

    return _buildCardTemplate(
      icon: Icons.bluetooth_disabled_rounded,
      title: 'DEVICE NOT CONNECTED',
      titleIconColor: _secondaryTextColor,
      content: noticeContent,
      titleStyle: _cardTitleStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDeviceConnected = true;

    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : 'Welcome, ${_userData?['firstName'] ?? _user?.displayName?.split(' ').first ?? 'User'}'),
        backgroundColor: _scaffoldBgColor,
        elevation: 0,
        foregroundColor: _primaryTextColor,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryAppColor))
          : RefreshIndicator(
        onRefresh: _fetchUserData,
        color: _primaryAppColor,
        child: Container(
          margin: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: _dashboardContentBgColor,
            borderRadius: BorderRadius.circular(_dashboardCornerRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserDetailsCard(),
                if (hasDeviceConnected) ...[
                  _buildPostureCard(),
                  _buildHeartRateCard(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHrvCard(),
                        const SizedBox(width: 16),
                        _buildStressLevelCard(), // Now Clickable
                      ],
                    ),
                  ),
                  _buildDeviceCard(),
                ] else ...[
                  _buildConnectDeviceNotice('Connect your device to start viewing your health data.'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
