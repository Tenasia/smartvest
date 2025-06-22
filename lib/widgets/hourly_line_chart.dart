import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartvest/models/chart_models.dart';

class HourlyLineChart extends StatelessWidget {
  final List<ChartDataPoint> chartData;
  final List<Color> gradientColors;
  final String yAxisUnit;

  const HourlyLineChart({
    super.key,
    required this.chartData,
    required this.gradientColors,
    this.yAxisUnit = '',
  });

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return Center(
          child: Text(
            "No chart data for today.",
            style: TextStyle(color: Colors.grey[600]),
          ));
    }

    return LineChart(
      mainData(),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 0: text = '12A'; break;
      case 6: text = '6A'; break;
      case 12: text = '12P'; break;
      case 18: text = '6P'; break;
      case 23: text = '11P'; break;
      default: return Container();
    }
    return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 12);
    if (value == meta.max || value == meta.min) {
      return Container();
    }
    return Text(value.toInt().toString(), style: style, textAlign: TextAlign.left);
  }

  LineChartData mainData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 20,
        verticalInterval: 6,
        getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xff37434d), strokeWidth: 1),
        getDrawingVerticalLine: (value) => const FlLine(color: Color(0xff37434d), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d))),
      minX: 0,
      maxX: 23,
      lineBarsData: [
        LineChartBarData(
          spots: chartData.map((point) => FlSpot(point.time.hour.toDouble(), point.value)).toList(),
          isCurved: true,
          gradient: LinearGradient(colors: gradientColors),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(colors: gradientColors.map((color) => color.withOpacity(0.3)).toList()),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final hour = spot.x.toInt();
              final timeFormat = DateFormat('ha'); // Format to '10AM', '11PM' etc.
              final time = timeFormat.format(DateTime(2023,1,1,hour));

              return LineTooltipItem(
                '${spot.y.toStringAsFixed(0)} $yAxisUnit\n$time',
                TextStyle(color: gradientColors[0], fontWeight: FontWeight.bold, fontSize: 14),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
