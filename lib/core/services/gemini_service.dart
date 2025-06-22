import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:health/health.dart';

class GeminiService {
  // Your actual API Key is correctly stored here.
  final String _apiKey = "AIzaSyDA03m67MzO-a012URe8LPTaQd-1toxQBE";

  Future<String> getHealthSummary(
      String metricName, List<HealthDataPoint> dataPoints, int? userAge) async {

    // THIS IS THE FIX: The check now compares against the original placeholder.
    // Since your _apiKey is different, this condition will be FALSE, and the code will proceed.
    if (_apiKey == "YOUR_GEMINI_API_KEY") {
      return "## AI Summary Disabled\n\nPlease add your Gemini API Key in `lib/core/services/gemini_service.dart` to enable this feature.";
    }

    if (dataPoints.isEmpty) {
      return "No data available to generate a summary for $metricName.";
    }

    // Prepare the data for the prompt
    final dataSummary = dataPoints
        .map((p) =>
    '${(p.value as NumericHealthValue).numericValue.toStringAsFixed(1)} at ${p.dateFrom.toLocal().hour}:${p.dateFrom.toLocal().minute}')
        .join(', ');

    final prompt = """
      You are a friendly and encouraging health assistant.
      Analyze the following health data for a user and provide a concise, easy-to-understand summary.
      The user's age is ${userAge ?? 'not provided'}.
      
      Data for '$metricName' today:
      $dataSummary

      Based on this data, provide:
      1.  **Status**: A one-sentence summary of their status (e.g., "Your heart rate seems stable," "Your SpO2 levels look excellent").
      2.  **Observations**: Mention any notable highs, lows, or patterns in a friendly tone.
      3.  **Recommendations**: Offer 2-3 simple, actionable health tips based on the data. Frame these as gentle suggestions.

      Format the entire response in simple Markdown.
      """;

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey');

    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        final text =
        decodedResponse['candidates'][0]['content']['parts'][0]['text'];
        return text;
      } else {
        debugPrint(
            'Gemini API Error: ${response.statusCode}\n${response.body}');
        return "Sorry, I couldn't generate a summary right now (Error: ${response.statusCode}). Please check your API key and billing settings.";
      }
    } catch (e) {
      debugPrint('Error calling Gemini API: $e');
      return "Sorry, I couldn't generate a summary due to a connection issue.";
    }
  }
}
