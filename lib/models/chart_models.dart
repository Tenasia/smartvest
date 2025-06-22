// Defines the data structures used for charts and Firebase data.

class ChartDataPoint {
  final DateTime time;
  final double value;

  ChartDataPoint({required this.time, required this.value});
}

class PostureDataPoint {
  final DateTime timestamp;
  final int rulaScore;
  final String assessment;

  PostureDataPoint({required this.timestamp, required this.rulaScore, required this.assessment});
}

class StressDataPoint {
  final DateTime timestamp;
  final int gsrDeviation;
  final String stressLevel;

  StressDataPoint({required this.timestamp, required this.gsrDeviation, required this.stressLevel});
}
