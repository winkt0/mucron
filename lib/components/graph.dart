import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';

class Graph {
  static LineChart build({
    required List<FlSpot> spots,
    required double xMax,
    required double yMax,
    required double interval,
  }) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: xMax,
        minY: 0,
        maxY: yMax,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text("${meta.formattedValue}s"),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: yMax / 8,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text("${meta.formattedValue}Hz"),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
