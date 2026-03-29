import 'package:flutter/material.dart';
import '../services/notification_service.dart'; // 👈 USE YOUR FILE NAME

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  void sendSOS() {
    NotificationService().sendEmergencyNotification();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency")),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
          ),
          onPressed: () {
            sendSOS();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Emergency Alert Sent")),
            );
          },
          child: const Text("SOS", style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
