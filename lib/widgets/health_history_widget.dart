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
    final now = DateTime.now();
    final startTime = now.subtract(_selectedPeriod.duration);

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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sensorData')
                .where('timestamp',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No data available for this period.'));
              }

              final docs = snapshot.data!.docs;
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
                final hrValues =
                    entry.value.map((m) => m['heartRate']!).toList();
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
                ..sort((a, b) => a.date.compareTo(b.date));

              final baseMs = (docs.first['timestamp'] as Timestamp)
                  .millisecondsSinceEpoch
                  .toDouble();
              final hrSpots = docs
                  .map((doc) {
                    final ts = doc['timestamp'];
                    if (ts is! Timestamp) return null;
                    final x = ((ts.millisecondsSinceEpoch.toDouble() - baseMs) /
                        3600000.0);
                    final y = (doc['heartRate'] as num).toDouble();
                    return FlSpot(x, y);
                  })
                  .whereType<FlSpot>()
                  .toList();
              final spo2Spots = docs
                  .map((doc) {
                    final ts = doc['timestamp'];
                    if (ts is! Timestamp) return null;
                    final x = ((ts.millisecondsSinceEpoch.toDouble() - baseMs) /
                        3600000.0);
                    final y = (doc['spo2'] as num).toDouble();
                    return FlSpot(x, y);
                  })
                  .whereType<FlSpot>()
                  .toList();

              final maxX = [hrSpots, spo2Spots]
                  .expand((list) => list)
                  .map((s) => s.x)
                  .fold<double>(0, (prev, e) => e > prev ? e : prev);
              final minY = [hrSpots, spo2Spots]
                  .expand((list) => list)
                  .map((s) => s.y)
                  .fold<double>(
                      double.infinity, (prev, e) => e < prev ? e : prev);
              final maxY = [hrSpots, spo2Spots]
                  .expand((list) => list)
                  .map((s) => s.y)
                  .fold<double>(0, (prev, e) => e > prev ? e : prev);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        height: 240,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: (maxX / 5).clamp(0.1, maxX),
                                  getTitlesWidget: (value, meta) {
                                    final dateTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            (baseMs + (value * 3600000.0))
                                                .toInt());
                                    final label = _selectedPeriod ==
                                            HealthPeriod.last24h
                                        ? '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
                                        : '${dateTime.month}/${dateTime.day}';
                                    return Text(label,
                                        style: const TextStyle(fontSize: 10));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: ((maxY - minY) / 5)
                                        .clamp(1, double.infinity)),
                              ),
                            ),
                            minX: 0,
                            maxX: maxX > 0 ? maxX : 1,
                            minY: minY - 5,
                            maxY: maxY + 5,
                            lineBarsData: [
                              LineChartBarData(
                                spots: hrSpots,
                                isCurved: true,
                                color: Colors.red,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: spo2Spots,
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statCard(
                          'HR', '${widget.currentHeartRate} bpm', Colors.red),
                      _statCard('SpO2', '${widget.currentSpO2} %', Colors.blue),
                      _statCard('Mean HR', widget.mean.toStringAsFixed(1),
                          Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('History',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: dailyStats.length,
                      itemBuilder: (context, index) {
                        final stat = dailyStats[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
              );
            },
          ),
        ),
      ],
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
