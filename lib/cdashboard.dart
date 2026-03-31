import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverDashboard extends StatelessWidget {
  const CaregiverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text("🚨 Emergency Alerts",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('emergencies')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text("No emergencies"));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index];

                      return Card(
                        elevation: 4,
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(
                              "HR: ${data['heartRate']} | SpO2: ${data['spo2']}"),
                          subtitle: Text(
                              "📍 ${data['latitude']}, ${data['longitude']}"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
