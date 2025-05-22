// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// Assuming DriveHelper is no longer used for profile data
// import '../utils/drive_helper.dart';
import 'main_screen_shell.dart';
import 'onboarding_screen.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: <String>['email'],
);
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleSignInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        if (kDebugMode) {
          print("Firebase Sign-In successful: UID: ${firebaseUser.uid}, Email: ${firebaseUser.email}");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('currentUserEmail', firebaseUser.email!);
        await prefs.setString('firebaseUserId', firebaseUser.uid);

        DocumentSnapshot userProfileDoc = await _firestore.collection('userProfiles').doc(firebaseUser.uid).get();

        if (userProfileDoc.exists) {
          Map<String, dynamic> profileDataFromFirestore = userProfileDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> profileDataForLocalCache = Map.from(profileDataFromFirestore);

          // Convert Firestore Timestamps to ISO8601 strings for local JSON storage
          if (profileDataForLocalCache['createdAt'] is Timestamp) {
            profileDataForLocalCache['createdAt'] = (profileDataForLocalCache['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (profileDataForLocalCache['lastUpdatedAt'] is Timestamp) {
            profileDataForLocalCache['lastUpdatedAt'] = (profileDataForLocalCache['lastUpdatedAt'] as Timestamp).toDate().toIso8601String();
          }
          // Reminder settings might also contain Timestamps if you ever store them directly,
          // but currently, Reminder model uses string time & ReminderFrequency.toString()

          // Check if the profile seems complete (e.g., has a name)
          if (profileDataForLocalCache.isNotEmpty && profileDataForLocalCache['name'] != null && profileDataForLocalCache['name'].toString().isNotEmpty) {
            await prefs.setString('user_data', jsonEncode(profileDataForLocalCache));
            if (mounted) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreenShell()));
            }
          } else {
            // Profile exists in Firestore but is incomplete
            await prefs.remove('user_data'); // Clear old local cache
            if (mounted) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
            }
          }
        } else {
          // Profile doesn't exist in Firestore (new user to the app's data store)
          if (kDebugMode) print("New user profile for Firestore: ${firebaseUser.email}. Creating basic entry and proceeding to onboarding.");

          Map<String, dynamic> initialProfileData = {
            'email': firebaseUser.email,
            'name': '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            // Initialize reminderSettings with defaults
            'reminderSettings': {
              'isWaterReminderEnabled': true,
              'waterIntervalHours': 2,
              'isWalkReminderEnabled': true,
              'customReminders': [] // Empty list for custom reminders
            }
            // Add other fields with default empty/null values as needed
          };
          await _firestore.collection('userProfiles').doc(firebaseUser.uid).set(initialProfileData);

          await prefs.remove('user_data'); // Ensure no stale local data
          if (mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
          }
        }
      } else {
        throw Exception("Firebase user is null after sign-in");
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print("Error during Google Sign-In or Firestore processing: $error");
        print("Stack trace: $stackTrace");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${error.toString().substring(0,min(error.toString().length, 100))}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI Remains the same
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(Icons.health_and_safety_outlined, size: 100, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 30),
                Text(
                  'Welcome to HealthTracker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in with Google to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 50),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  icon: Image.asset('assets/images/google_logo.png', height: 24.0), // Ensure image asset exists
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black87, backgroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300)
                      ),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                  ),
                  onPressed: _handleSignInWithGoogle,
                ),
                const SizedBox(height: 20),
                const Text(
                  "By signing in, you agree to our Terms and Privacy Policy (simulated placeholders).",
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}