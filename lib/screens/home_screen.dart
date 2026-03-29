import 'package:flutter/material.dart';
import 'emergency_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HealthBuddy")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 5,
              child: ListTile(
                title: const Text("Emergency SOS"),
                subtitle: const Text("Send alert instantly"),
                trailing: const Icon(Icons.warning, color: Colors.red),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 5,
              child: const ListTile(
                title: Text("Health Tracking"),
                subtitle: Text("Coming soon"),
                trailing: Icon(Icons.favorite),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
