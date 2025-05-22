// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:mvc1/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/theme_provider.dart';
import '../utils/drive_helper.dart'; // If still used (e.g., for OAuth related CSV)
// For Firestore profiles it's not directly needed here.
import '../models/reminder_model.dart';
import '../services/notification_service.dart';
import 'main_screen_shell.dart';
import 'login_screen.dart';

// ProfileScreen constants (could be moved to a shared file)
const String waterReminderEnabledKey = 'water_reminder_enabled_v2';
const String waterReminderIntervalKey = 'water_reminder_interval_hours_v2';
const String walkReminderEnabledKey = 'walk_reminder_enabled_v2';
const int waterReminderBaseId = 1000;
const int walkReminderId = 2000;


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _selectedDietaryPreference;
  String? _selectedGender;
  List<String> _allergies = [];
  final TextEditingController _newAllergyController = TextEditingController();
  bool _hasDiabetes = false;
  bool _hasProteinDeficiency = false;
  bool _isSkinnyFat = false;
  TimeOfDay? _selectedSleepTime;
  TimeOfDay? _selectedWakeTime;

  int _currentStep = 0;
  int _previousStepIndex = 0;
  final int _totalSteps = 9;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _newAllergyController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay? tod) {
    if (tod == null) return "";
    return "${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _saveProfileDataToFirestoreAndLocal() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    if (firebaseUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in. Please sign in again.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (c) => const LoginScreen()), (route) => false);
        setState(() => _isSaving = false);
      }
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('userProfiles').doc(firebaseUser.uid).get();
    Map<String, dynamic>? existingFirestoreData = userDoc.exists ? userDoc.data() as Map<String,dynamic>? : null;
    dynamic originalCreatedAt = existingFirestoreData?['createdAt'];
    if (originalCreatedAt == null) {
      originalCreatedAt = FieldValue.serverTimestamp();
    }

    final Map<String, dynamic> detailedProfileData = {
      'name': _nameController.text,
      'age': _ageController.text,
      'height': _heightController.text,
      'weight': _weightController.text,
      'gender': _selectedGender,
      'dietaryPreference': _selectedDietaryPreference,
      'allergies': _allergies,
      'hasDiabetes': _hasDiabetes,
      'hasProteinDeficiency': _hasProteinDeficiency,
      'isSkinnyFat': _isSkinnyFat,
      'sleepTime': _formatTimeOfDay(_selectedSleepTime),
      'wakeTime': _formatTimeOfDay(_selectedWakeTime),
      'email': firebaseUser.email,
      'createdAt': originalCreatedAt,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'reminderSettings': { // Initialize with defaults
        'isWaterReminderEnabled': true,
        'waterIntervalHours': 2,
        'isWalkReminderEnabled': true,
        'customReminders': []
      }
    };

    try {
      await FirebaseFirestore.instance.collection('userProfiles').doc(firebaseUser.uid)
          .set(detailedProfileData, SetOptions(merge: true));

      Map<String, dynamic> localProfileDataToCache = Map.from(detailedProfileData);
      String nowISO = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());
      localProfileDataToCache['lastUpdatedAt'] = nowISO;
      if (localProfileDataToCache['createdAt'] is FieldValue) {
        localProfileDataToCache['createdAt'] = nowISO;
      } else if (localProfileDataToCache['createdAt'] is Timestamp) {
        localProfileDataToCache['createdAt'] = (localProfileDataToCache['createdAt'] as Timestamp).toDate().toIso8601String();
      }

      await prefs.setString('user_data', jsonEncode(localProfileDataToCache));

      // Save default reminder states after profile save
      await prefs.setBool(waterReminderEnabledKey, true);
      await prefs.setInt(waterReminderIntervalKey, 2);
      await prefs.setBool(walkReminderEnabledKey, true);
      await prefs.setStringList(userRemindersKey, []); // Ensure custom reminders is empty list

      // Schedule initial notifications based on these defaults
      if (_selectedWakeTime != null && _selectedSleepTime != null) {
        await NotificationService().scheduleWaterReminderSeries(_selectedWakeTime!, _selectedSleepTime!, 2, waterReminderBaseId);
        DateTime walkTimeDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, _selectedWakeTime!.hour, _selectedWakeTime!.minute).add(const Duration(minutes: 15));
        Reminder walkReminder = Reminder(id: 'default_walk_$walkReminderId', title: '🚶‍♂️ Time for a Walk!', time: TimeOfDay.fromDateTime(walkTimeDt), isDefault: true, frequency: ReminderFrequency.daily);
        await NotificationService().scheduleReminder(walkReminder);
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created and saved!')),
        );
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreenShell(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print("Error saving profile to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addAllergy() {
    if (_newAllergyController.text.trim().isNotEmpty) {
      setState(() {
        if (!_allergies.contains(_newAllergyController.text.trim())) {
          _allergies.add(_newAllergyController.text.trim());
        }
        _newAllergyController.clear();
      });
    }
  }

  void _removeAllergy(int index) {
    if (index >= 0 && index < _allergies.length) {
      setState(() {
        _allergies.removeAt(index);
      });
    }
  }

  void _nextStep() {
    bool isStepValidated = true;
    if (_currentStep == 4) {
      isStepValidated = _formKey.currentState!.validate();
    } else if (_currentStep == 1) {
      isStepValidated = _selectedSleepTime != null && _selectedWakeTime != null;
      if (!isStepValidated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both sleep and wake-up times.')),
        );
      } else {
        int sleepMinutes = _selectedSleepTime!.hour * 60 + _selectedSleepTime!.minute;
        int wakeMinutes = _selectedWakeTime!.hour * 60 + _selectedWakeTime!.minute;
        if (sleepMinutes == wakeMinutes) {
          isStepValidated = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sleep and wake-up times cannot be the same.')),
          );
        }
      }
    } else if (_currentStep == 2) {
      isStepValidated = _selectedDietaryPreference != null;
      if (!isStepValidated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your dietary preference.')),
        );
      }
    } else if (_currentStep == 3) {
      isStepValidated = _selectedGender != null;
      if (!isStepValidated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your gender.')),
        );
      }
    }

    if (isStepValidated) {
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _previousStepIndex = _currentStep;
          _currentStep++;
        });
      } else {
        if (!_isSaving) _saveProfileDataToFirestoreAndLocal();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _previousStepIndex = _currentStep;
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _totalSteps,
                    backgroundColor: Colors.grey[300],
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final Offset beginOffset = _currentStep > _previousStepIndex
                          ? const Offset(0.2, 0.0)
                          : const Offset(-0.2, 0.0);
                      final position = Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: position,
                          child: child,
                        ),
                      );
                    },
                    child: _buildCurrentStep(),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        ElevatedButton(
                          onPressed: _previousStep,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox(),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0,))
                            : Text(_currentStep < _totalSteps - 1 ? 'Next' : 'Finish'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildThemeSelectionStep(key: const ValueKey('onboarding_theme_selection'));
      case 1: return _buildSleepWakeStep(key: const ValueKey('onboarding_sleep_wake'));
      case 2: return _buildDietaryStep(key: const ValueKey('onboarding_dietary_preference'));
      case 3: return _buildGenderStep(key: const ValueKey('onboarding_gender'));
      case 4: return _buildPersonalInfoStep(key: const ValueKey('onboarding_personal_info'));
      case 5: return _buildAllergiesStep(key: const ValueKey('onboarding_allergies'));
      case 6: return _buildDiabetesStep(key: const ValueKey('onboarding_diabetes'));
      case 7: return _buildProteinStep(key: const ValueKey('onboarding_protein'));
      case 8: return _buildSkinnyFatStep(key: const ValueKey('onboarding_skinny_fat'));
      default: return const SizedBox();
    }
  }

  Widget _buildThemeSelectionStep({Key? key}) { // ... same ...
    final currentThemeMode = Provider.of<ThemeProvider>(context).themeMode;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose your theme', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Select your preferred app theme:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              _buildThemeOption(context: context, label: 'System Default', icon: Icons.settings_brightness, themeMode: ThemeMode.system, isSelected: currentThemeMode == ThemeMode.system, onTap: () => Provider.of<ThemeProvider>(context, listen: false).setThemeMode(ThemeMode.system)),
              const SizedBox(height: 20),
              _buildThemeOption(context: context, label: 'Light Theme', icon: Icons.wb_sunny_outlined, themeMode: ThemeMode.light, isSelected: currentThemeMode == ThemeMode.light, onTap: () => Provider.of<ThemeProvider>(context, listen: false).setThemeMode(ThemeMode.light)),
              const SizedBox(height: 20),
              _buildThemeOption(context: context, label: 'Dark Theme', icon: Icons.nightlight_round, themeMode: ThemeMode.dark, isSelected: currentThemeMode == ThemeMode.dark, onTap: () => Provider.of<ThemeProvider>(context, listen: false).setThemeMode(ThemeMode.dark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({required BuildContext context, required String label, required IconData icon, required ThemeMode themeMode, required bool isSelected, required VoidCallback onTap}) { // ... same ...
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepWakeStep({Key? key}) { // ... same ...
    String sleepDuration = "Please select both times";
    if (_selectedSleepTime != null && _selectedWakeTime != null) {
      final sleepDateTime = DateTime(2000, 1, 1, _selectedSleepTime!.hour, _selectedSleepTime!.minute);
      DateTime wakeDateTime = DateTime(2000, 1, 1, _selectedWakeTime!.hour, _selectedWakeTime!.minute);
      if (wakeDateTime.isBefore(sleepDateTime) || wakeDateTime.isAtSameMomentAs(sleepDateTime)) {
        wakeDateTime = wakeDateTime.add(const Duration(days: 1));
      }
      final duration = wakeDateTime.difference(sleepDateTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      sleepDuration = "${hours}h ${minutes}m";
    }

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sleep Schedule', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Set your typical sleep and wake-up times.', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 30),
        ListTile(
          leading: const Icon(Icons.bedtime_outlined, size: 30),
          title: Text('Sleep Time', style: Theme.of(context).textTheme.titleMedium),
          trailing: Text(
              _selectedSleepTime?.format(context) ?? 'Not Set',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)
          ),
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _selectedSleepTime ?? TimeOfDay.now(),);
            if (picked != null) setState(() => _selectedSleepTime = picked);
          },
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.wb_sunny_outlined, size: 30),
          title: Text('Wake-up Time', style: Theme.of(context).textTheme.titleMedium),
          trailing: Text(
              _selectedWakeTime?.format(context) ?? 'Not Set',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)
          ),
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _selectedWakeTime ?? TimeOfDay.now(),);
            if (picked != null) setState(() => _selectedWakeTime = picked);
          },
        ),
        const SizedBox(height: 30),
        if (_selectedSleepTime != null && _selectedWakeTime != null)
          Center(
            child: Text('Estimated Sleep Duration: $sleepDuration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)
            ),
          )
      ],
    );
  }

  Widget _buildDietaryStep({Key? key}) { // ... same ...
    return Column(
      key: key, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dietary Preferences', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), Text('What is your dietary preference?', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20),
        Column(children: [
          _buildSelectionButton(context: context, label: 'Vegetarian', isSelected: _selectedDietaryPreference == 'Vegetarian', onTap: () => setState(() => _selectedDietaryPreference = 'Vegetarian')), const SizedBox(height: 16),
          _buildSelectionButton(context: context, label: 'Non-vegetarian', isSelected: _selectedDietaryPreference == 'Non-vegetarian', onTap: () => setState(() => _selectedDietaryPreference = 'Non-vegetarian')), const SizedBox(height: 16),
          _buildSelectionButton(context: context, label: 'Vegan', isSelected: _selectedDietaryPreference == 'Vegan', onTap: () => setState(() => _selectedDietaryPreference = 'Vegan')),
        ]),
      ],);
  }

  Widget _buildGenderStep({Key? key}) { // ... same ...
    return Column(
      key: key, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), Text('What is your gender?', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20),
        Column(children: [
          _buildSelectionButton(context: context, label: 'Male', isSelected: _selectedGender == 'Male', onTap: () => setState(() => _selectedGender = 'Male')), const SizedBox(height: 16),
          _buildSelectionButton(context: context, label: 'Female', isSelected: _selectedGender == 'Female', onTap: () => setState(() => _selectedGender = 'Female')), const SizedBox(height: 16),
          _buildSelectionButton(context: context, label: 'Other', isSelected: _selectedGender == 'Other', onTap: () => setState(() => _selectedGender = 'Other')),
        ]),
      ],);
  }

  Widget _buildPersonalInfoStep({Key? key}) { // ... same ...
    return Column(
      key: key, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tell us about yourself', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Text('We need some basic information to personalize your experience', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))), const SizedBox(height: 30),
        TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Full Name', hintText: 'Enter your full name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person)), validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null), const SizedBox(height: 16),
        TextFormField(controller: _ageController, decoration: InputDecoration(labelText: 'Age', hintText: 'Enter your age', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.calendar_today)), keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your age'; final age = int.tryParse(value); if (age == null) return 'Please enter a valid number'; if (age <= 0 || age > 120) return 'Please enter a realistic age';
            return null;
          },
        ), const SizedBox(height: 16),
        TextFormField(controller: _heightController, decoration: InputDecoration(labelText: 'Height (cm)', hintText: 'Enter your height', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.height)), keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your height'; final height = double.tryParse(value); if (height == null) return 'Please enter a valid number'; if (height <= 0 || height > 300) return 'Please enter a realistic height in cm';
            return null;
          },
        ), const SizedBox(height: 16),
        TextFormField(controller: _weightController, decoration: InputDecoration(labelText: 'Weight (kg)', hintText: 'Enter your weight', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.line_weight)), keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your weight'; final weight = double.tryParse(value); if (weight == null) return 'Please enter a valid number'; if (weight <= 0 || weight > 500) return 'Please enter a realistic weight in kg';
            return null;
          },
        ),
      ],);
  }

  Widget _buildAllergiesStep({Key? key}) { // ... same ...
    return Column(
      key: key, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Allergies', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Text('Do you have any food allergies? (Optional)', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextFormField(controller: _newAllergyController, decoration: InputDecoration(labelText: 'Add Allergy', hintText: 'e.g., Peanuts', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onFieldSubmitted: (_) => _addAllergy())),
          const SizedBox(width: 8), ElevatedButton(onPressed: _addAllergy, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Icon(Icons.add)),
        ]), const SizedBox(height: 20),
        if (_allergies.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Allergies:', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
          Wrap(spacing: 8.0, runSpacing: 4.0, children: _allergies.asMap().entries.map((entry) {
            int idx = entry.key; String allergy = entry.value;
            return Chip(label: Text(allergy), deleteIcon: const Icon(Icons.close, size: 18), onDeleted: () => _removeAllergy(idx), backgroundColor: Theme.of(context).colorScheme.primaryContainer, labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer));
          }).toList()),
        ]) else Text('No allergies added yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      ],);
  }

  // Corrected definition of _buildHealthAssessmentContainer
  Widget _buildHealthAssessmentContainer({Key? key, required String title, required String description, required bool isYesSelected, required Function(bool) onSelection}) {
    return Column(
      key: key, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(description, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(child: _buildSelectionButton(context: context, label: 'Yes', isSelected: isYesSelected, onTap: () => onSelection(true))),
          const SizedBox(width: 16),
          Expanded(child: _buildSelectionButton(context: context, label: 'No', isSelected: !isYesSelected, onTap: () => onSelection(false))),
        ]),
      ],);
  }

  Widget _buildDiabetesStep({Key? key}) => _buildHealthAssessmentContainer(key: key, title: 'Do you have diabetes?', description: 'This helps us tailor dietary advice.', isYesSelected: _hasDiabetes, onSelection: (val) => setState(() => _hasDiabetes = val));
  Widget _buildProteinStep({Key? key}) => _buildHealthAssessmentContainer(key: key, title: 'Protein Deficiency?', description: 'Do you suspect you have protein deficiency?', isYesSelected: _hasProteinDeficiency, onSelection: (val) => setState(() => _hasProteinDeficiency = val));
  Widget _buildSkinnyFatStep({Key? key}) => _buildHealthAssessmentContainer(key: key, title: 'Consider yourself "Skinny Fat"?', description: 'This helps in recommending exercise and diet focus.', isYesSelected: _isSkinnyFat, onSelection: (val) => setState(() => _isSkinnyFat = val));

  Widget _buildSelectionButton({required BuildContext context, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30), border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.3), width: 2),
        ),
        child: Center(child: Text(label, style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))),
      ),);
  }
}