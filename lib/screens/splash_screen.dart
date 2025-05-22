// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // For jsonDecode

import 'login_screen.dart';
import 'main_screen_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500), // Reduced duration
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _navigateUser();
  }

  Future<void> _navigateUser() async {
    final prefs = await SharedPreferences.getInstance();
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    bool isLoggedIn = firebaseUser != null; // Primary check is Firebase Auth state

    String? localProfileDataString;
    if(isLoggedIn){
      localProfileDataString = prefs.getString('user_data');
      // Ensure these are set if firebaseUser is not null
      await prefs.setString('currentUserEmail', firebaseUser.email!);
      await prefs.setString('firebaseUserId', firebaseUser.uid);
    } else {
      // If not logged in via Firebase, also clear local flags just in case
      await prefs.setBool('isLoggedIn', false); // Ensure this matches Firebase state
      await prefs.remove('currentUserEmail');
      await prefs.remove('firebaseUserId');
      await prefs.remove('user_data');
    }

    await Future.delayed(const Duration(seconds: 2)); // Visual splash time

    if (mounted) {
      Widget destinationScreen;
      if (isLoggedIn) {
        if (localProfileDataString != null && localProfileDataString.isNotEmpty) {
          try {
            Map<String,dynamic> profile = jsonDecode(localProfileDataString);
            // A simple check if profile seems completed (e.g., name is filled)
            if (profile['name'] != null && (profile['name'] as String).isNotEmpty) {
              destinationScreen = const MainScreenShell();
            } else {
              destinationScreen = const OnboardingScreen();
            }
          } catch(e) {
            destinationScreen = const OnboardingScreen(); // Corrupted local data
          }
        } else {
          destinationScreen = const OnboardingScreen(); // Needs onboarding
        }
      } else {
        destinationScreen = const LoginScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destinationScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.health_and_safety,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "HealthTracker",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}