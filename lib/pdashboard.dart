import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final int windowSize = 100;

  double mean = 0;
  double stdDev = 0;
  double upper = 0;
  double lower = 0;
  double trend = 0;

  bool isLoading = false;

  int heartRate = 0;
  int spo2 = 0;

  // 🔥 Intelligent model
  void calculateModel(List<QueryDocumentSnapshot> docs) {
    int startIndex = docs.length > windowSize ? docs.length - windowSize : 0;

    List<int> hr = [];

    for (int i = startIndex; i < docs.length; i++) {
      hr.add(docs[i]['heartRate']);
    }

    mean = hr.reduce((a, b) => a + b) / hr.length;

    double variance =
        hr.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / hr.length;

    stdDev = sqrt(variance);

    upper = mean + 2 * stdDev;
    lower = mean - 2 * stdDev;

    if (hr.length >= 5) {
      trend = (hr.last - hr[hr.length - 5]).toDouble();
    }
  }

  void checkAnomaly(int latestHR) {
    bool abnormal = latestHR > upper || latestHR < lower || trend > 15;

    if (abnormal) {
      sendSOS();
    }
  }

  // 🚨 SOS WITH LOCATION
  Future<void> sendSOS() async {
    setState(() => isLoading = true);

    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await FirebaseFirestore.instance.collection('emergencies').add({
      'heartRate': heartRate,
      'spo2': spo2,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚨 Emergency Triggered")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Health Dashboard")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("sensorData")
            .orderBy("timestamp", descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No data"));
          }

          calculateModel(docs);

          heartRate = docs.last['heartRate'];
          spo2 = docs.last['spo2'];

          checkAnomaly(heartRate);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text("❤️ HR: $heartRate", style: const TextStyle(fontSize: 24)),
                Text("🩸 SpO2: $spo2", style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 20),
                Text("Mean: ${mean.toStringAsFixed(2)}"),
                Text("StdDev: ${stdDev.toStringAsFixed(2)}"),
                Text("Upper: ${upper.toStringAsFixed(2)}"),
                Text("Lower: ${lower.toStringAsFixed(2)}"),
                Text("Trend: ${trend.toStringAsFixed(2)}"),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: sendSOS,
                        child: const Text("🚨 Emergency SOS"),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
