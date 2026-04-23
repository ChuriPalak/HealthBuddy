import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum HealthPeriod { last24h, last7d, last30d }

extension HealthPeriodExtension on HealthPeriod {
  String get label {
    switch (this) {
      case HealthPeriod.last24h:
        return '24 Hours';
      case HealthPeriod.last7d:
        return '7 Days';
      case HealthPeriod.last30d:
        return '30 Days';
    }
  }

  Duration get duration {
    switch (this) {
      case HealthPeriod.last24h:
        return const Duration(hours: 24);
      case HealthPeriod.last7d:
        return const Duration(days: 7);
      case HealthPeriod.last30d:
        return const Duration(days: 30);
    }
  }
}

class DailyStats {
  final String date;
  final double hrAvg;
  final int hrMin;
  final int hrMax;
  final double spo2Avg;
  final int spo2Min;
  final int spo2Max;

  DailyStats({
    required this.date,
    required this.hrAvg,
    required this.hrMin,
    required this.hrMax,
    required this.spo2Avg,
    required this.spo2Min,
    required this.spo2Max,
  });
}

class HealthHistoryWidget extends StatefulWidget {
  final int currentHeartRate;
  final int currentSpO2;
  final double mean;
  final double stdDev;
  final double upper;
  final double lower;
  final double trend;

  const HealthHistoryWidget({
    super.key,
    required this.currentHeartRate,
    required this.currentSpO2,
    required this.mean,
    required this.stdDev,
    required this.upper,
    required this.lower,
    required this.trend,
  });

  @override
  State<HealthHistoryWidget> createState() => _HealthHistoryWidgetState();
}

class _HealthHistoryWidgetState extends State<HealthHistoryWidget> {
  HealthPeriod _selectedPeriod = HealthPeriod.last24h;
  List<DailyStats> _dailyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  void _loadHistoryData() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sensorData')
          .orderBy('timestamp', descending: false)
          .get();

      final docs = snapshot.docs;
      final statsMap = <String, List<Map<String, int>>>{};

      for (final doc in docs) {
        final ts = doc['timestamp'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        statsMap.putIfAbsent(key, () => []).add({
          'heartRate': (doc['heartRate'] as num).toInt(),
          'spo2': (doc['spo2'] as num).toInt(),
        });
      }

      final dailyStats = statsMap.entries.map((entry) {
        final hrValues = entry.value.map((m) => m['heartRate']!).toList();
        final spo2Values = entry.value.map((m) => m['spo2']!).toList();
        final hrSum = hrValues.reduce((a, b) => a + b);
        final spo2Sum = spo2Values.reduce((a, b) => a + b);

        return DailyStats(
          date: entry.key,
          hrAvg: hrSum / hrValues.length,
          hrMin: hrValues.reduce((a, b) => a < b ? a : b),
          hrMax: hrValues.reduce((a, b) => a > b ? a : b),
          spo2Avg: spo2Sum / spo2Values.length,
          spo2Min: spo2Values.reduce((a, b) => a < b ? a : b),
          spo2Max: spo2Values.reduce((a, b) => a > b ? a : b),
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _dailyStats = dailyStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading history data: $e');
    }
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: HealthPeriod.values.map((period) {
              return ListTile(
                leading: Icon(
                  period == HealthPeriod.last24h
                      ? Icons.access_time
                      : period == HealthPeriod.last7d
                          ? Icons.calendar_view_week
                          : Icons.calendar_view_month,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  period.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  setState(() {
                    _selectedPeriod = period;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ElevatedButton.icon(
            onPressed: _showPeriodSelector,
            icon: const Icon(Icons.schedule),
            label: Text('Period: ${_selectedPeriod.label}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _dailyStats.isEmpty
                  ? const Center(child: Text('No data available.'))
                  : Column(
                      children: [
                        // Graph Section
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('sensorData')
                              .where('timestamp',
                                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                                      DateTime.now()
                                          .subtract(_selectedPeriod.duration)))
                              .orderBy('timestamp', descending: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 240,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }

                            final docs = snapshot.data?.docs ?? [];
                            return _buildChart(docs);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statCard('HR', '${widget.currentHeartRate} bpm',
                                Colors.red),
                            _statCard(
                                'SpO2', '${widget.currentSpO2} %', Colors.blue),
                            _statCard('Mean HR', widget.mean.toStringAsFixed(1),
                                Colors.teal),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text('History',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // History Section
                        Expanded(
                          child: ListView.builder(
                            itemCount: _dailyStats.length,
                            itemBuilder: (context, index) {
                              final stat = _dailyStats[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(stat.date,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'HR avg ${stat.hrAvg.toStringAsFixed(1)}, min ${stat.hrMin}, max ${stat.hrMax}'),
                                      Text(
                                          'SpO2 avg ${stat.spo2Avg.toStringAsFixed(1)}, min ${stat.spo2Min}, max ${stat.spo2Max}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildChart(List<QueryDocumentSnapshot> docs) {
    final statsMap = <String, List<Map<String, int>>>{};

    for (final doc in docs) {
      final ts = doc['timestamp'];
      if (ts is! Timestamp) continue;
      final date = ts.toDate();
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      statsMap.putIfAbsent(key, () => []).add({
        'heartRate': (doc['heartRate'] as num).toInt(),
        'spo2': (doc['spo2'] as num).toInt(),
      });
    }

    final dailyStats = statsMap.entries.map((entry) {
      final hrValues = entry.value.map((m) => m['heartRate']!).toList();
      final spo2Values = entry.value.map((m) => m['spo2']!).toList();
      final hrSum = hrValues.reduce((a, b) => a + b);
      final spo2Sum = spo2Values.reduce((a, b) => a + b);

      return DailyStats(
        date: entry.key,
        hrAvg: hrSum / hrValues.length,
        hrMin: hrValues.reduce((a, b) => a < b ? a : b),
        hrMax: hrValues.reduce((a, b) => a > b ? a : b),
        spo2Avg: spo2Sum / spo2Values.length,
        spo2Min: spo2Values.reduce((a, b) => a < b ? a : b),
        spo2Max: spo2Values.reduce((a, b) => a > b ? a : b),
      );
    }).toList();

    // Sort by date (latest first)
    dailyStats.sort((a, b) => b.date.compareTo(a.date));

    // Filter docs for graph based on selected period
    final now = DateTime.now();
    final startTime = now.subtract(_selectedPeriod.duration);
    final filteredDocs = docs.where((doc) {
      final ts = doc['timestamp'];
      if (ts is! Timestamp) return false;
      return ts.toDate().isAfter(startTime) ||
          ts.toDate().isAtSameMomentAs(startTime);
    }).toList();

    // Generate spots based on selected period
    List<FlSpot> hrSpots = [];
    List<FlSpot> spo2Spots = [];

    if (_selectedPeriod == HealthPeriod.last24h) {
      // For 24 hours: aggregate data by hour
      final hourlyMap = <int, List<Map<String, int>>>{};
      final baseMs = (filteredDocs.isNotEmpty
              ? filteredDocs.first['timestamp'] as Timestamp
              : Timestamp.now())
          .millisecondsSinceEpoch
          .toDouble();

      for (final doc in filteredDocs) {
        final ts = doc['timestamp'];
        if (ts is! Timestamp) continue;
        final hour =
            ((ts.millisecondsSinceEpoch.toDouble() - baseMs) / 3600000.0)
                .floor();
        hourlyMap.putIfAbsent(hour, () => []).add({
          'heartRate': (doc['heartRate'] as num).toInt(),
          'spo2': (doc['spo2'] as num).toInt(),
        });
      }

      for (final entry in hourlyMap.entries) {
        final hrValues = entry.value.map((m) => m['heartRate']!).toList();
        final spo2Values = entry.value.map((m) => m['spo2']!).toList();
        final hrAvg = hrValues.reduce((a, b) => a + b) / hrValues.length;
        final spo2Avg = spo2Values.reduce((a, b) => a + b) / spo2Values.length;
        hrSpots.add(FlSpot(entry.key.toDouble(), hrAvg));
        spo2Spots.add(FlSpot(entry.key.toDouble(), spo2Avg));
      }
    } else {
      // For 7+ days: use daily aggregates filtered by period
      final periodFilteredStats = dailyStats.where((stat) {
        final parts = stat.date.split('-');
        final statDate = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return statDate.isAfter(startTime) ||
            statDate.isAtSameMomentAs(startTime);
      }).toList();

      for (int i = 0; i < periodFilteredStats.length; i++) {
        hrSpots.add(FlSpot(i.toDouble(), periodFilteredStats[i].hrAvg));
        spo2Spots.add(FlSpot(i.toDouble(), periodFilteredStats[i].spo2Avg));
      }
    }

    final maxX = _selectedPeriod == HealthPeriod.last24h
        ? ([hrSpots, spo2Spots]
            .expand((list) => list)
            .map((s) => s.x)
            .fold<double>(0, (prev, e) => e > prev ? e : prev))
        : ((hrSpots.length - 1).toDouble());
    final minY = [hrSpots, spo2Spots]
        .expand((list) => list)
        .map((s) => s.y)
        .fold<double>(double.infinity, (prev, e) => e < prev ? e : prev);
    final maxY = [hrSpots, spo2Spots]
        .expand((list) => list)
        .map((s) => s.y)
        .fold<double>(0, (prev, e) => e > prev ? e : prev);
    final bottomInterval = _selectedPeriod == HealthPeriod.last24h
        ? (maxX > 1.0 ? (maxX / 4.0).clamp(1.0, maxX).toDouble() : 1.0)
        : (hrSpots.length > 1
            ? (hrSpots.length / 4.0)
                .clamp(1.0, hrSpots.length.toDouble())
                .toDouble()
            : 1.0);
    final yRange = maxY - minY;
    final leftInterval = yRange > 0
        ? (yRange / 4.0).clamp(1.0, double.infinity).toDouble()
        : 1.0;
    final safeMinY = minY.isFinite ? minY - 5.0 : 0.0;
    final safeMaxY = maxY.isFinite ? maxY + 5.0 : 1.0;

    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: bottomInterval,
                    getTitlesWidget: (value, meta) {
                      if (_selectedPeriod == HealthPeriod.last24h) {
                        final baseMs = (filteredDocs.isNotEmpty
                                ? filteredDocs.first['timestamp'] as Timestamp
                                : Timestamp.now())
                            .millisecondsSinceEpoch
                            .toDouble();
                        final dateTime = DateTime.fromMillisecondsSinceEpoch(
                            (baseMs + (value * 3600000.0)).toInt());
                        final label =
                            '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                        return Text(label,
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey));
                      } else {
                        final periodFilteredStats = dailyStats.where((stat) {
                          final parts = stat.date.split('-');
                          final statDate = DateTime(int.parse(parts[0]),
                              int.parse(parts[1]), int.parse(parts[2]));
                          return statDate.isAfter(startTime) ||
                              statDate.isAtSameMomentAs(startTime);
                        }).toList();

                        final index = value.toInt();
                        if (index >= 0 && index < periodFilteredStats.length) {
                          final parts =
                              periodFilteredStats[index].date.split('-');
                          return Text('${parts[1]}/${parts[2]}',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey));
                        }
                        return const Text('');
                      }
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: leftInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey),
                        );
                      }),
                ),
              ),
              minX: 0,
              maxX: maxX > 0 ? maxX : 1,
              minY: safeMinY,
              maxY: safeMaxY,
              lineBarsData: [
                LineChartBarData(
                  spots: hrSpots,
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 2,
                  dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.red,
                          strokeWidth: 0,
                        );
                      }),
                ),
                LineChartBarData(
                  spots: spo2Spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 2,
                  dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.blue,
                          strokeWidth: 0,
                        );
                      }),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final isSeries0 = barSpot.barIndex == 0;
                      final value = barSpot.y.toStringAsFixed(1);
                      final label =
                          isSeries0 ? 'HR: $value bpm' : 'SpO2: $value %';
                      return LineTooltipItem(
                        label,
                        TextStyle(
                          color: isSeries0 ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
