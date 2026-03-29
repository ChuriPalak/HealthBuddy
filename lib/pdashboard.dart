import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/health_card.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int heartRate = 0;
  int spo2 = 0;

  List<FlSpot> hrSpots = [];
  List<FlSpot> spo2Spots = [];

  int maxHR = 0, minHR = 999;
  int maxSpO2 = 0, minSpO2 = 999;

  List<Map<String, dynamic>> historyData = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() {
    FirebaseFirestore.instance
        .collection("sensorData")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .listen((snapshot) {
      List<FlSpot> tempHR = [];
      List<FlSpot> tempSpO2 = [];

      int tMaxHR = 0, tMinHR = 999;
      int tMaxSpO2 = 0, tMinSpO2 = 999;

      List<Map<String, dynamic>> tempHistory = [];

      DateTime now = DateTime.now();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        if (data['timestamp'] == null) continue;

        DateTime time = (data['timestamp'] as Timestamp).toDate();

        int hr = data['heartRate'];
        int sp = data['spo2'];

        // 📊 24 hour graph
        if (now.difference(time).inHours <= 24) {
          double x = time.hour + (time.minute / 60);

          tempHR.add(FlSpot(x, hr.toDouble()));
          tempSpO2.add(FlSpot(x, sp.toDouble()));
        }

        // 📜 History
        tempHistory.add({
          "hr": hr,
          "spo2": sp,
          "time": time,
        });

        // 📉 Min/Max
        tMaxHR = hr > tMaxHR ? hr : tMaxHR;
        tMinHR = hr < tMinHR ? hr : tMinHR;

        tMaxSpO2 = sp > tMaxSpO2 ? sp : tMaxSpO2;
        tMinSpO2 = sp < tMinSpO2 ? sp : tMinSpO2;
      }

      if (snapshot.docs.isNotEmpty) {
        var latest = snapshot.docs.first;

        setState(() {
          heartRate = latest['heartRate'];
          spo2 = latest['spo2'];

          hrSpots = tempHR;
          spo2Spots = tempSpO2;

          maxHR = tMaxHR;
          minHR = tMinHR;
          maxSpO2 = tMaxSpO2;
          minSpO2 = tMinSpO2;

          historyData = tempHistory;
        });
      }
    });
  }

  Future<void> sendSOS() async {
    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('emergencies').add({
      'message': '🚨 Patient triggered emergency!',
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("SOS Sent")));
  }

  LineChartData chartData() {
    return LineChartData(
      minX: 0,
      maxX: 24,
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 4,
            getTitlesWidget: (value, meta) {
              return Text("${value.toInt()}h");
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(spots: hrSpots, isCurved: true),
        LineChartBarData(spots: spo2Spots, isCurved: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            HealthCard(
                title: "Heart Rate",
                value: "$heartRate BPM",
                icon: Icons.favorite,
                color: Colors.red),
            const SizedBox(height: 10),
            HealthCard(
                title: "SpO2",
                value: "$spo2 %",
                icon: Icons.air,
                color: Colors.blue),
            const SizedBox(height: 20),
            const Text("24 Hour Graph",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 250, child: LineChart(chartData())),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text("Max HR: $maxHR | Min HR: $minHR"),
                    Text("Max SpO2: $maxSpO2 | Min SpO2: $minSpO2"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("History"),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyData.length > 10 ? 10 : historyData.length,
              itemBuilder: (context, index) {
                var item = historyData[index];

                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text("HR: ${item['hr']} | SpO2: ${item['spo2']}"),
                  subtitle: Text(item['time'].toString()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : sendSOS,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SOS"),
            ),
          ],
        ),
      ),
    );
  }
}
