import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  bool _isLoading = false;

  Future<void> _sendEmergencyAlert() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch caregiver's FCM token from Firestore
      // Assuming caregiver has a document with role 'caregiver'
      QuerySnapshot caregiverSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .limit(1)
          .get();

      if (caregiverSnapshot.docs.isNotEmpty) {
        String caregiverToken = caregiverSnapshot.docs.first['fcmToken'];
        print('Caregiver token: $caregiverToken');
        await NotificationService.sendEmergencyNotification([caregiverToken],
            'Patient Emergency', 'A patient has triggered an emergency alert!');
        // Save emergency to Firestore
        await FirebaseFirestore.instance.collection('emergencies').add({
          'type': 'patient_emergency',
          'message': 'A patient has triggered an emergency alert!',
          'timestamp': FieldValue.serverTimestamp(),
          'sender': 'patient',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency alert sent to caregiver')),
        );
      } else {
        print('No caregiver found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No caregiver found')),
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
      appBar: AppBar(title: const Text("Patient Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome Patient"),
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
                  : const Text('Simulate Emergency',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
