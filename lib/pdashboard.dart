import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:location/location.dart';
import 'widgets/health_history_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final Location location = Location(); // ✅ location instance

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

  // 🚨 SOS WITH LOCATION (UPDATED)
  Future<void> sendSOS() async {
    setState(() => isLoading = true);

    try {
      // 🔐 Check permission
      PermissionStatus permission = await location.requestPermission();

      if (permission != PermissionStatus.granted) {
        setState(() => isLoading = false);
        return;
      }

      // 📍 Get location
      LocationData currentLocation = await location.getLocation();

      double? lat = currentLocation.latitude;
      double? lng = currentLocation.longitude;

      if (lat == null || lng == null) {
        setState(() => isLoading = false);
        return;
      }

      // 🔥 Send to Firestore
      await FirebaseFirestore.instance.collection('emergencies').add({
        'heartRate': heartRate,
        'spo2': spo2,
        'latitude': lat,
        'longitude': lng,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Health Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
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

          return HealthHistoryWidget(
            currentHeartRate: heartRate,
            currentSpO2: spo2,
            mean: mean,
            stdDev: stdDev,
            upper: upper,
            lower: lower,
            trend: trend,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: sendSOS,
        backgroundColor: Colors.red,
        child: const Icon(Icons.sos, color: Colors.white),
        tooltip: 'Emergency SOS',
      ),
    );
  }
}
