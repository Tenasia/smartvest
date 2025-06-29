import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartvest/config/app_routes.dart';

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color profileColor = Color(0xFF5667FD);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.normal,
      color: AppColors.secondaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static final TextStyle bodyText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryText);
}
// --- END OF DESIGN SYSTEM ---


class HeightAndWeightScreen extends StatefulWidget {
  const HeightAndWeightScreen({super.key});

  @override
  State<HeightAndWeightScreen> createState() => _HeightAndWeightScreenState();
}

class _HeightAndWeightScreenState extends State<HeightAndWeightScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
  bool _useMetric = true;
  int _selectedHeightCm = 175;
  double _selectedWeightKg = 65.0;
  bool _isLoading = false;

  final List<int> _heightCmOptions = List.generate(200, (i) => 100 + i); // 100cm to 299cm
  final List<int> _weightKgOptions = List.generate(1700, (i) => 30.0 + i * 0.1) as List<int>; // 30kg to 199.9kg
  final List<int> _heightInchOptions = List.generate(60, (i) => 40 + i); // 40in to 99in
  final List<int> _weightLbsOptions = List.generate(371, (i) => 60 + i); // 60lbs to 430lbs

  static const double cmToInch = 0.393701;
  static const double kgToLbs = 2.20462;

  FixedExtentScrollController? _heightPickerController;
  FixedExtentScrollController? _weightPickerController;

  int get _selectedHeightInch => (_selectedHeightCm * cmToInch).round();
  double get _selectedWeightLbs => _selectedWeightKg * kgToLbs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializePickerControllers());
  }

  @override
  void dispose() {
    _heightPickerController?.dispose();
    _weightPickerController?.dispose();
    super.dispose();
  }

  void _initializePickerControllers() {
    if(!mounted) return;
    _heightPickerController = FixedExtentScrollController(
      initialItem: _useMetric
          ? _heightCmOptions.indexOf(_selectedHeightCm)
          : _heightInchOptions.indexOf(_selectedHeightInch),
    );
    _weightPickerController = FixedExtentScrollController(
      initialItem: _useMetric
          ? _weightKgOptions.indexWhere((val) => (val - _selectedWeightKg).abs() < 0.05)
          : _weightLbsOptions.indexOf(_selectedWeightLbs.round()),
    );
    setState(() {});
  }

  void _toggleUnits(bool useMetric) {
    if (_useMetric == useMetric) return;
    setState(() {
      _useMetric = useMetric;
      _initializePickerControllers();
    });
  }

  Future<void> _onContinue() async {
    setState(() => _isLoading = true);
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'heightWeightCompleted': true,
          'profileCompleted': true,
          'heightCm': _selectedHeightCm,
          'weightKg': _selectedWeightKg,
        });
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.searchAndConnect);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save data: ${e.toString()}')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- MODERNIZED UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const LinearProgressIndicator(
              value: 4 / 4, // Final step
              backgroundColor: AppColors.background,
              color: AppColors.profileColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Height & Weight', style: AppTextStyles.heading),
                    const SizedBox(height: 8.0),
                    Text('This data helps improve the accuracy of your health insights.', style: AppTextStyles.secondaryInfo),
                    const SizedBox(height: 32.0),

                    _buildUnitToggle(),
                    const SizedBox(height: 24.0),

                    Expanded(
                      child: _buildPickerSection(),
                    ),

                    const SizedBox(height: 24.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.profileColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text('Finish Setup', style: AppTextStyles.buttonText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODERNIZED UI WIDGETS ---

  Widget _buildUnitToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryText.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildUnitButton("Metric (cm, kg)", true),
          _buildUnitButton("Imperial (in, lbs)", false),
        ],
      ),
    );
  }

  Widget _buildUnitButton(String text, bool isMetric) {
    final isSelected = _useMetric == isMetric;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleUnits(isMetric),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.profileColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              color: isSelected ? Colors.white : AppColors.secondaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerSection() {
    if (_heightPickerController == null || _weightPickerController == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.profileColor));
    }
    return Row(
      children: [
        _buildPickerColumn(
          controller: _heightPickerController!,
          options: _useMetric ? _heightCmOptions.map((e) => e.toString()).toList() : _heightInchOptions.map((e) => e.toString()).toList(),
          unit: _useMetric ? "cm" : "in",
          onChanged: (index) => setState(() {
            _selectedHeightCm = _useMetric ? _heightCmOptions[index] : (_heightInchOptions[index] / cmToInch).round();
          }),
        ),
        _buildPickerColumn(
          controller: _weightPickerController!,
          options: _useMetric ? _weightKgOptions.map((e) => e.toStringAsFixed(1)).toList() : _weightLbsOptions.map((e) => e.toString()).toList(),
          unit: _useMetric ? "kg" : "lbs",
          onChanged: (index) => setState(() {
            _selectedWeightKg = _useMetric ? _weightKgOptions[index].toDouble() : _weightLbsOptions[index] / kgToLbs;
          }),
        ),
      ],
    );
  }

  Widget _buildPickerColumn({
    required FixedExtentScrollController controller,
    required List<String> options,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              itemExtent: 40.0,
              scrollController: controller,
              onSelectedItemChanged: onChanged,
              useMagnifier: true,
              magnification: 1.1,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: AppColors.profileColor.withOpacity(0.1),
                capStartEdge: false,
                capEndEdge: false,
              ),
              children: options.map((opt) => Center(child: Text(opt, style: AppTextStyles.bodyText.copyWith(fontSize: 22)))).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(unit, style: AppTextStyles.secondaryInfo.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}