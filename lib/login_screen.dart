import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pdashboard.dart';
import 'cdashboard.dart';
import 'register_screen.dart';
import 'services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> loginUser() async {
    debugPrint('loginUser called');
    setState(() {
      isLoading = true;
    });

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Fetch role from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      final rawRole = userDoc.data()?['role'];
      final role =
          (rawRole is String ? rawRole : rawRole?.toString() ?? 'patient')
              .toLowerCase();
      debugPrint('user role from firestore: $rawRole (normalized: $role)');

      // Save FCM token to user document
      String? fcmToken = await NotificationService.getFCMToken();
      debugPrint('FCM token retrieved: $fcmToken');
      if (fcmToken != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({'fcmToken': fcmToken}, SetOptions(merge: true));
          debugPrint('FCM token saved: $fcmToken');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('FCM token saved to Firestore')),
          );
        } catch (firestoreError) {
          debugPrint('Failed to save FCM token: $firestoreError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save token: $firestoreError')),
          );
        }
      } else {
        debugPrint('FCM token is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('FCM token is null (check emulator or device)')),
        );
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful')),
      );

      // Navigate based on role
      if (role == 'caregiver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaregiverDashboard()),
        );
      } else {
        // default to patient
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientDashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} ${e.message}');
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (e, st) {
      debugPrint('loginUser error: $e');
      debugPrint('$st');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HealthBuddy Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: loginUser,
                    child: const Text("Login"),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterScreen()),
                );
              },
              child: const Text("Don't have an account? Register"),
            )
          ],
        ),
      ),
    );
  }
}
