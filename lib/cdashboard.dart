import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  _CaregiverDashboardState createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  bool _isLoading = false;

  Future<void> _sendEmergencyAlert() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all patients' FCM tokens from Firestore
      QuerySnapshot patientsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      List<String> patientTokens = [];
      for (var doc in patientsSnapshot.docs) {
        if (doc['fcmToken'] != null) {
          patientTokens.add(doc['fcmToken']);
        }
      }
      print('Patient tokens: $patientTokens');

      if (patientTokens.isNotEmpty) {
        await NotificationService.sendEmergencyNotification(patientTokens,
            'Caregiver Alert', 'Caregiver has sent an emergency alert!');
        // Save emergency to Firestore
        await FirebaseFirestore.instance.collection('emergencies').add({
          'type': 'caregiver_alert',
          'message': 'Caregiver has sent an emergency alert!',
          'timestamp': FieldValue.serverTimestamp(),
          'sender': 'caregiver',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency alert sent to all patients')),
        );
      } else {
        print('No patients found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No patients found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send alert: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome Caregiver"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendEmergencyAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send Emergency Alert',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
