// lib/screens/tools_screen.dart
import 'package:flutter/material.dart';
import '../widgets/bmi_calculator_widget.dart'; // This path must be correct

class ToolsScreen extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const ToolsScreen({Key? key, this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BMICalculatorWidget(userData: userData), // Ensure BMICalculatorWidget class exists and is imported
        ],
      ),
    );
  }
}