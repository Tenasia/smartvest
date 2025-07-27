import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataPrivacyDisclaimer extends StatefulWidget {
  final VoidCallback onAgreed;

  const DataPrivacyDisclaimer({super.key, required this.onAgreed});

  @override
  State<DataPrivacyDisclaimer> createState() => _DataPrivacyDisclaimerState();
}

class _DataPrivacyDisclaimerState extends State<DataPrivacyDisclaimer> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Data Privacy & Disclaimer',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your health data is collected and processed with utmost care. This application provides insights based on simulated and real-time sensor data for informational purposes only. It is NOT a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of a qualified healthcare provider for any questions regarding your medical condition.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF8A94A6),
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('hasAgreedToDisclaimer', true);
                widget.onAgreed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5667FD), // profileColor
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'I Understand & Agree',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
