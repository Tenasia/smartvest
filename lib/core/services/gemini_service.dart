import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:health/health.dart';
import 'package:intl/intl.dart';


class GeminiService {
  // Your actual API Key is correctly stored here.
  final String _apiKey = "AIzaSyDA03m67MzO-a012URe8LPTaQd-1toxQBE";

  /// Generates a health summary from a list of HealthDataPoint objects (from Health Connect).
  Future<String> getHealthSummary(
      String metricName, List<HealthDataPoint> dataPoints, int? userAge) async {
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

    return _callGeminiAPI(prompt);
  }

  /// Generates a health summary from a raw data string (e.g., from Firebase).
  Future<String> getSummaryFromRawString({
    required String metricName,
    required String dataSummary,
    required int? userAge,
    required String analysisInstructions,
  }) async {
    if (_apiKey == "YOUR_GEMINI_API_KEY") {
      return "## AI Summary Disabled\n\nPlease add your Gemini API Key to enable this feature.";
    }

    if (dataSummary.isEmpty) {
      return "No data available to generate a summary for $metricName.";
    }

    final prompt = """
      You are a friendly and encouraging health assistant.
      Analyze the following health data for a user and provide a concise, easy-to-understand summary in Markdown format.
      The user's age is ${userAge ?? 'not provided'}.

      **Metric:**
      '$metricName'

      **Data:**
      $dataSummary

      **Instructions:**
      $analysisInstructions
      """;

    return _callGeminiAPI(prompt);
  }

  /// Private helper to handle the HTTP request to the Gemini API.
  Future<String> _callGeminiAPI(String prompt) async {
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
        // Add robust checking for the response structure
        if (decodedResponse.containsKey('candidates') &&
            decodedResponse['candidates'] is List &&
            decodedResponse['candidates'].isNotEmpty &&
            decodedResponse['candidates'][0].containsKey('content') &&
            decodedResponse['candidates'][0]['content'].containsKey('parts') &&
            decodedResponse['candidates'][0]['content']['parts'] is List &&
            decodedResponse['candidates'][0]['content']['parts'].isNotEmpty) {
          return decodedResponse['candidates'][0]['content']['parts'][0]['text'];
        }
        return "Sorry, I received an unexpected response format from the AI.";
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