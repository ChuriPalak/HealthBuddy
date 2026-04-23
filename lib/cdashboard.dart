import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import 'widgets/health_history_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  String? _lastEmergencyId;
  bool _loadedInitialEmergency = false;

  void _showEmergencyPopup(BuildContext context, DocumentSnapshot emergency) {
    final data = emergency.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚨 Emergency Alert!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Heart Rate: ${data['heartRate']} bpm'),
              Text('SpO2: ${data['spo2']}%'),
              Text('Location: ${data['latitude']}, ${data['longitude']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final lat = data['latitude'];
                final lng = data['longitude'];
                await openMap(lat, lng);
              },
              child: const Text('View Location'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Caregiver Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text("Health History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sensorData')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('No sensor data available.'));
                  }

                  final latestDoc = docs.last;
                  final heartRate = (latestDoc['heartRate'] as num).toInt();
                  final spo2 = (latestDoc['spo2'] as num).toInt();

                  final List<int> hrValues = docs
                      .map((doc) => (doc['heartRate'] as num).toInt())
                      .toList();
                  final mean =
                      hrValues.reduce((a, b) => a + b) / hrValues.length;
                  final variance = hrValues
                          .map((e) => pow(e - mean, 2))
                          .reduce((a, b) => a + b) /
                      hrValues.length;
                  final stdDev = sqrt(variance);
                  final upper = mean + 2 * stdDev;
                  final lower = mean - 2 * stdDev;
                  final trend = hrValues.length >= 5
                      ? (hrValues.last - hrValues[hrValues.length - 5])
                          .toDouble()
                      : 0.0;

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
            ),
            const Divider(),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('emergencies')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                var docs = snapshot.data!.docs;

                if (docs.isNotEmpty && docs.first.id != _lastEmergencyId) {
                  _lastEmergencyId = docs.first.id;

                  // Avoid showing popup on initial app open; show only on a new record after already loaded.
                  if (_loadedInitialEmergency) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showEmergencyPopup(context, docs.first);
                    });
                  } else {
                    _loadedInitialEmergency = true;
                  }
                }

                // No visible list needed; popup is enough.
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
