// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../providers/theme_provider.dart';
// import '../utils/drive_helper.dart'; // Assuming not used
import '../services/notification_service.dart';
import '../models/reminder_model.dart'; // Ensure this points to your corrected model
import 'login_screen.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

const String userRemindersKey = 'user_defined_reminders_v2';
const String waterReminderEnabledKey = 'water_reminder_enabled_v2';
const String waterReminderIntervalKey = 'water_reminder_interval_hours_v2';
const String walkReminderEnabledKey = 'walk_reminder_enabled_v2';

const int waterReminderBaseId = 1000;
const int walkReminderId = 2000;

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final Function(Map<String, dynamic>) updateUserData;

  const ProfileScreen({Key? key, required this.userData, required this.updateUserData}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingNonReminderFields = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  String? _selectedDietaryPreference;
  String? _selectedGender;
  List<String> _allergies = [];
  late TextEditingController _newAllergyController;
  bool _hasDiabetes = false;
  bool _hasProteinDeficiency = false;
  bool _isSkinnyFat = false;
  TimeOfDay? _selectedSleepTime;
  TimeOfDay? _selectedWakeTime;
  String? _createdAt;
  bool _isSavingProfile = false; // For the main profile save button

  List<Reminder> _userReminders = [];
  bool _isWaterReminderEnabled = true;
  int _waterIntervalHours = 2;
  bool _isWalkReminderEnabled = true;
  final TextEditingController _reminderTitleController = TextEditingController();
  TimeOfDay? _dialogSelectedReminderTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _newAllergyController = TextEditingController();
    _initializeControllersFromWidgetData();
    _loadReminderSettingsFromUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _newAllergyController.dispose();
    _reminderTitleController.dispose();
    super.dispose();
  }

  void _initializeControllersFromWidgetData() {
    _nameController.text = widget.userData?['name'] ?? '';
    _ageController.text = widget.userData?['age'] ?? '';
    _heightController.text = widget.userData?['height'] ?? '';
    _weightController.text = widget.userData?['weight'] ?? '';
    _selectedDietaryPreference = widget.userData?['dietaryPreference'];
    _selectedGender = widget.userData?['gender'];
    _allergies = List<String>.from(widget.userData?['allergies'] ?? []);
    _hasDiabetes = widget.userData?['hasDiabetes'] ?? false;
    _hasProteinDeficiency = widget.userData?['hasProteinDeficiency'] ?? false;
    _isSkinnyFat = widget.userData?['isSkinnyFat'] ?? false;
    _createdAt = widget.userData?['createdAt'];

    final String? sleepTimeString = widget.userData?['sleepTime'];
    _selectedSleepTime = _parseTimeOfDay(sleepTimeString);

    final String? wakeTimeString = widget.userData?['wakeTime'];
    _selectedWakeTime = _parseTimeOfDay(wakeTimeString);
  }

  TimeOfDay? _parseTimeOfDay(String? todString) {
    if (todString == null || todString.isEmpty) return null;
    final parts = todString.split(':');
    if (parts.length == 2) {
      try { return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])); }
      catch (_) { return null; }
    }
    return null;
  }

  String _formatTimeOfDay(TimeOfDay? tod) {
    if (tod == null) return "";
    return "${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _loadReminderSettingsFromUserData() async {
    Map<String, dynamic>? reminderSettingsSource = widget.userData?['reminderSettings'] as Map<String, dynamic>?;

    if (reminderSettingsSource != null) {
      if (kDebugMode) print("ProfileScreen: Loading reminder settings from widget.userData (Firestore cache)");
      final List<dynamic>? remindersJsonRawList = reminderSettingsSource['customReminders'] as List<dynamic>?;
      List<Reminder> loadedReminders = [];
      if (remindersJsonRawList != null) {
        for (var rJson in remindersJsonRawList) {
          if (rJson is Map<String, dynamic>) {
            try { loadedReminders.add(Reminder.fromJson(rJson)); }
            catch (e) { if (kDebugMode) print("Error decoding reminder from userData: $e"); }
          }
        }
      }
      if(mounted){
        setState(() {
          _isWaterReminderEnabled = reminderSettingsSource['isWaterReminderEnabled'] as bool? ?? true;
          _waterIntervalHours = reminderSettingsSource['waterIntervalHours'] as int? ?? 2;
          _isWalkReminderEnabled = reminderSettingsSource['isWalkReminderEnabled'] as bool? ?? true;
          _userReminders = loadedReminders;
        });
      }
    } else {
      if (kDebugMode) print("ProfileScreen: Reminder settings not in userData, falling back to SharedPreferences.");
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      List<Reminder> loadedUserRemindersFromPrefs = [];
      final List<String>? remindersJson = prefs.getStringList(userRemindersKey);
      if (remindersJson != null) {
        for (String rJson in remindersJson) {
          try { loadedUserRemindersFromPrefs.add(Reminder.fromJson(jsonDecode(rJson) as Map<String, dynamic>)); }
          catch (e) { if (kDebugMode) print("Error loading reminder from prefs fallback: $e"); }
        }
      }
      setState(() {
        _isWaterReminderEnabled = prefs.getBool(waterReminderEnabledKey) ?? true;
        _waterIntervalHours = prefs.getInt(waterReminderIntervalKey) ?? 2;
        _isWalkReminderEnabled = prefs.getBool(walkReminderEnabledKey) ?? true;
        _userReminders = loadedUserRemindersFromPrefs;
      });
    }
    // Reschedule based on loaded/default settings, only if not in main edit mode
    if (!_isEditingNonReminderFields) {
      await _rescheduleAllNotifications();
    }
  }

  Future<void> _saveAndRescheduleAllReminders() async {
    // Step 1: Save current reminder state to SharedPreferences (for local persistence and quick UI update)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(waterReminderEnabledKey, _isWaterReminderEnabled);
    await prefs.setInt(waterReminderIntervalKey, _waterIntervalHours);
    await prefs.setBool(walkReminderEnabledKey, _isWalkReminderEnabled);
    final List<String> remindersJson = _userReminders.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(userRemindersKey, remindersJson);

    // Step 2: Update Firestore with the new reminder settings
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        Map<String, dynamic> reminderSettingsForFirestore = {
          'isWaterReminderEnabled': _isWaterReminderEnabled,
          'waterIntervalHours': _waterIntervalHours,
          'isWalkReminderEnabled': _isWalkReminderEnabled,
          'customReminders': _userReminders.map((r) => r.toJson()).toList(),
        };
        await FirebaseFirestore.instance.collection('userProfiles').doc(firebaseUser.uid)
            .set({'reminderSettings': reminderSettingsForFirestore}, SetOptions(merge: true));
        if (kDebugMode) print("ProfileScreen: Reminder settings updated in Firestore.");

        // Update local widget.userData to reflect change immediately for other parts of the screen
        Map<String,dynamic> updatedUserData = Map.from(widget.userData ?? {});
        updatedUserData['reminderSettings'] = reminderSettingsForFirestore;
        widget.updateUserData(updatedUserData);


      } catch (e) {
        if (kDebugMode) print("Error updating reminder settings in Firestore: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save reminder settings to cloud: ${e.toString()}")));
      }
    }
    // Step 3: Reschedule all notifications based on the new settings
    await _rescheduleAllNotifications();
  }


  Future<void> _rescheduleAllNotifications() async {
    if (kDebugMode) print("ProfileScreen: Rescheduling all notifications based on current UI state...");
    await NotificationService().cancelAllNotifications();
    TimeOfDay? wakeTime; TimeOfDay? sleepTime;
    // Use the current state of _selectedWakeTime and _selectedSleepTime for scheduling
    if (_selectedWakeTime != null) wakeTime = _selectedWakeTime;
    if (_selectedSleepTime != null) sleepTime = _selectedSleepTime;


    if (_isWaterReminderEnabled && wakeTime != null && sleepTime != null) {
      await NotificationService().scheduleWaterReminderSeries( wakeTime, sleepTime, _waterIntervalHours, waterReminderBaseId);
    } else {
      // Cancel any existing water reminders if criteria not met or disabled
      for(int i=0; i< (24 ~/ (_waterIntervalHours > 0 ? _waterIntervalHours : 2 )) +2; i++){ // Estimate max possible
        await NotificationService().cancelNotificationByStringId('default_water_${waterReminderBaseId + i}');
      }
    }
    if (_isWalkReminderEnabled && wakeTime != null) {
      DateTime walkTimeDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, wakeTime.hour, wakeTime.minute).add(const Duration(minutes: 15));
      Reminder walkReminder = Reminder( id: 'default_walk_$walkReminderId', title: '🚶‍♂️ Time for a Walk!', time: TimeOfDay.fromDateTime(walkTimeDt), isDefault: true, frequency: ReminderFrequency.daily);
      await NotificationService().scheduleReminder(walkReminder);
    } else {
      await NotificationService().cancelNotificationByStringId('default_walk_$walkReminderId');
    }
    for (var reminder in _userReminders) {
      if (reminder.isEnabled) { await NotificationService().scheduleReminder(reminder); }
      else { await NotificationService().cancelNotificationByStringId(reminder.id); }
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData != oldWidget.userData) {
      _initializeControllersFromWidgetData();
      _loadReminderSettingsFromUserData(); // This will also call _rescheduleAllNotifications if not in edit mode
      if(mounted) setState(() {});
    }
  }

  Future<void> _logoutUser(BuildContext context) async {
    if (kDebugMode) print("ProfileScreen: Logging out user.");
    try {
      await _googleSignIn.signOut(); // Sign out from Google
      await FirebaseAuth.instance.signOut(); // Sign out from Firebase

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data'); // Clear local user data
      // Clear individual reminder settings from SharedPreferences as well
      await prefs.remove(userRemindersKey);
      await prefs.remove(waterReminderEnabledKey);
      await prefs.remove(waterReminderIntervalKey);
      await prefs.remove(walkReminderEnabledKey);

      // Cancel all notifications upon logout
      await NotificationService().cancelAllNotifications();
      if (kDebugMode) print("ProfileScreen: All notifications cancelled on logout.");


      if (mounted) {
        // Navigate to LoginScreen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) print("Error during logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: ${e.toString()}')),
        );
      }
    }
  }


  void _toggleMainProfileEditing() {
    if (_isEditingNonReminderFields) { // If currently editing, try to save
      if (_formKey.currentState!.validate()) {
        // Additional validation for sleep/wake times if necessary
        if (_selectedSleepTime != null && _selectedWakeTime != null) {
          // Example: Ensure wake time is after sleep time (can be complex with day crossing)
          // For simplicity, we'll assume basic validation is enough or handled elsewhere.
        }
        if(!_isSavingProfile) _saveProfileDataToFirestoreAndLocal();
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please correct the errors in the form.'), backgroundColor: Colors.redAccent,));
      }
    } else { // If not editing, switch to editing mode
      setState(() { _isEditingNonReminderFields = true; });
    }
  }


  Future<void> _saveProfileDataToFirestoreAndLocal() async {
    if (_isSavingProfile) return;
    setState(() => _isSavingProfile = true);

    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    if (firebaseUser == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in. Cannot save profile.'), backgroundColor: Colors.redAccent,));
      setState(() => _isSavingProfile = false);
      return;
    }

    // Fetch existing createdAt if it exists, otherwise generate new
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('userProfiles').doc(firebaseUser.uid).get();
    Map<String, dynamic>? firestoreDocData = userDoc.exists ? userDoc.data() as Map<String,dynamic>? : null;
    String finalCreatedAt = _createdAt ?? (firestoreDocData?['createdAt'] is Timestamp ? (firestoreDocData!['createdAt'] as Timestamp).toDate().toIso8601String() : firestoreDocData?['createdAt'] as String?) ?? DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());


    // Prepare reminder settings from current UI state to be saved as part of the main profile
    Map<String, dynamic> currentReminderSettings = {
      'isWaterReminderEnabled': _isWaterReminderEnabled,
      'waterIntervalHours': _waterIntervalHours,
      'isWalkReminderEnabled': _isWalkReminderEnabled,
      'customReminders': _userReminders.map((r) => r.toJson()).toList(),
    };

    Map<String, dynamic> firestoreProfileDataToSave = {
      'name': _nameController.text.trim(),
      'age': _ageController.text.trim(),
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
      'gender': _selectedGender,
      'dietaryPreference': _selectedDietaryPreference,
      'allergies': _allergies,
      'hasDiabetes': _hasDiabetes,
      'hasProteinDeficiency': _hasProteinDeficiency,
      'isSkinnyFat': _isSkinnyFat,
      'sleepTime': _formatTimeOfDay(_selectedSleepTime),
      'wakeTime': _formatTimeOfDay(_selectedWakeTime),
      'email': firebaseUser.email, // Email from Firebase Auth user
      'createdAt': finalCreatedAt, // Use existing or new
      'lastUpdatedAt': FieldValue.serverTimestamp(), // Firestore server timestamp for update
      'reminderSettings': currentReminderSettings, // Include current reminder settings directly
    };

    try {
      await FirebaseFirestore.instance.collection('userProfiles').doc(firebaseUser.uid).set(firestoreProfileDataToSave, SetOptions(merge: true));

      // Prepare local cache data; resolve server timestamp for local cache
      Map<String, dynamic> localProfileDataToCache = Map.from(firestoreProfileDataToSave);
      String nowISO = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());
      // Replace FieldValue.serverTimestamp() with actual timestamp for local cache
      localProfileDataToCache['lastUpdatedAt'] = nowISO;
      // Ensure createdAt is also a string for local cache if it was newly generated
      final firestoreCreatedAtValue = localProfileDataToCache['createdAt'];
      if (firestoreCreatedAtValue is FieldValue) { // Should not happen for createdAt if logic is correct
        localProfileDataToCache['createdAt'] = nowISO;
      } else if (firestoreCreatedAtValue is Timestamp) {
        localProfileDataToCache['createdAt'] = firestoreCreatedAtValue.toDate().toIso8601String();
      }


      await prefs.setString('user_data', jsonEncode(localProfileDataToCache)); // This now includes reminderSettings
      widget.updateUserData(localProfileDataToCache); // Update parent widget

      // Since reminder settings are part of the main profile data saved to Firestore,
      // we still need to ensure individual SharedPreferences reminder keys are up-to-date (for fallback loading)
      // AND notifications are rescheduled based on the *potentially new* sleep/wake times or reminder settings.
      // The `_saveAndRescheduleAllReminders` function handles updating individual prefs and rescheduling.
      // We can modify it or create a helper if we want to avoid its Firestore write here, but for now,
      // its existing behavior will ensure SharedPreferences and notifications are correctly updated.
      // The redundant Firestore write within it (if not modified) is a minor inefficiency.
      await _saveAndRescheduleAllReminders(); // Ensures local reminder prefs match and reschedules.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile and reminders updated successfully!'), backgroundColor: Colors.green,));
        setState(() => _isEditingNonReminderFields = false);
      }
    } catch (e) {
      if (kDebugMode) print("Error saving profile to Firestore: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: ${e.toString()}'), backgroundColor: Colors.redAccent,));
    }
    finally {
      if(mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _addAllergy() {
    if (_newAllergyController.text.isNotEmpty) {
      setState(() {
        _allergies.add(_newAllergyController.text.trim());
        _newAllergyController.clear();
      });
    }
  }
  void _removeAllergy(int index) {
    setState(() {
      _allergies.removeAt(index);
    });
  }

  void _addOrUpdateReminder({required Reminder newOrUpdatedReminder, int? existingIndex}) {
    setState(() {
      if (existingIndex != null && existingIndex >=0 && existingIndex < _userReminders.length) {
        _userReminders[existingIndex] = newOrUpdatedReminder;
      } else {
        // Ensure unique ID for new reminders
        String id = newOrUpdatedReminder.id.isEmpty || _userReminders.any((r) => r.id == newOrUpdatedReminder.id)
            ? 'custom_${DateTime.now().millisecondsSinceEpoch}'
            : newOrUpdatedReminder.id;
        // The following line was causing the error if Reminder class didn't have copyWith
        _userReminders.add(newOrUpdatedReminder.copyWith(id: id));
      }
    });
    if (!_isEditingNonReminderFields) {
      _saveAndRescheduleAllReminders();
    }
  }

  void _deleteReminder(int index) {
    if (index < 0 || index >= _userReminders.length) return;
    final reminderToCancel = _userReminders[index];
    setState(() { _userReminders.removeAt(index); });
    NotificationService().cancelNotificationByStringId(reminderToCancel.id); // Cancel its specific notification
    if (!_isEditingNonReminderFields) {
      _saveAndRescheduleAllReminders(); // Resave and reschedule all
    }
  }

  void _showReminderDialog({Reminder? reminder, int? index}) {
    _reminderTitleController.text = reminder?.title ?? '';
    _dialogSelectedReminderTime = reminder?.time ?? TimeOfDay.now();
    ReminderFrequency selectedFrequency = reminder?.frequency ?? ReminderFrequency.daily;
    bool isEditingReminder = reminder != null;

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder( // Use StatefulBuilder for dialog's own state
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(isEditingReminder ? 'Edit Reminder' : 'Add Reminder'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: _reminderTitleController,
                          decoration: const InputDecoration(labelText: 'Reminder Title'),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          title: const Text('Time'),
                          trailing: Text(_dialogSelectedReminderTime!.format(context)),
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: _dialogSelectedReminderTime!,
                            );
                            if (picked != null && picked != _dialogSelectedReminderTime) {
                              setDialogState(() { // Use setDialogState to update dialog UI
                                _dialogSelectedReminderTime = picked;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<ReminderFrequency>(
                          decoration: const InputDecoration(labelText: 'Frequency'),
                          value: selectedFrequency,
                          items: ReminderFrequency.values.map((ReminderFrequency frequency) {
                            return DropdownMenuItem<ReminderFrequency>(
                              value: frequency,
                              child: Text(frequency.toString().split('.').last),
                            );
                          }).toList(),
                          onChanged: (ReminderFrequency? newValue) {
                            if (newValue != null) {
                              setDialogState(() { // Use setDialogState
                                selectedFrequency = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: Text(isEditingReminder ? 'Save' : 'Add'),
                      onPressed: () {
                        if (_reminderTitleController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Title cannot be empty!"), backgroundColor: Colors.red));
                          return;
                        }
                        final newReminder = Reminder(
                          id: isEditingReminder ? reminder.id : 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          title: _reminderTitleController.text,
                          time: _dialogSelectedReminderTime!,
                          frequency: selectedFrequency,
                          isEnabled: isEditingReminder ? reminder.isEnabled : true, // Default to enabled for new
                        );
                        _addOrUpdateReminder(newOrUpdatedReminder: newReminder, existingIndex: index);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              }
          );
        }
    ).then((_) { // Clear controller after dialog is dismissed
      _reminderTitleController.clear();
      _dialogSelectedReminderTime = null;
    });
  }


  void _addProfilePicture() {
    // Placeholder for profile picture functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture feature coming soon!')),
    );
  }
  double? _calculateBmi() {
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);
    if (height != null && weight != null && height > 0 && weight > 0) {
      return weight / ((height / 100) * (height / 100));
    }
    return null;
  }
  String _formatBmi(double bmi) => bmi.toStringAsFixed(1);

  String _getSleepDuration() {
    if (_selectedSleepTime == null || _selectedWakeTime == null) return "N/A";

    final now = DateTime.now();
    DateTime sleepDateTime = DateTime(now.year, now.month, now.day, _selectedSleepTime!.hour, _selectedSleepTime!.minute);
    DateTime wakeDateTime = DateTime(now.year, now.month, now.day, _selectedWakeTime!.hour, _selectedWakeTime!.minute);

    if (wakeDateTime.isBefore(sleepDateTime) || wakeDateTime.isAtSameMomentAs(sleepDateTime)) { // Wake time is on the next day
      wakeDateTime = wakeDateTime.add(const Duration(days: 1));
    }
    final duration = wakeDateTime.difference(sleepDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    String durationString = '';
    if (hours > 0) durationString += '$hours hr ';
    if (minutes > 0) durationString += '$minutes min';
    return durationString.trim().isEmpty ? 'N/A' : durationString;
  }

  Widget _buildProfileRow(BuildContext context, String title, TextEditingController controller, {bool isEditing = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: isEditing
          ? TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Flexible(child: Text(controller.text.isEmpty ? 'Not set' : controller.text, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.end,)),
        ],
      ),
    );
  }

  Widget _buildInfoDisplayRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(value.isEmpty ? 'Not set' : value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildHealthInfoRow(BuildContext context, String title, bool? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(value == null ? 'Not specified' : (value ? 'Yes' : 'No'), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildHealthAssessmentRowEditable(BuildContext context, String title, bool isYesSelected, Function(bool) onSelection) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectionButton(context: context, label: 'Yes', isSelected: isYesSelected, onTap: () => onSelection(true))),
              const SizedBox(width: 10),
              Expanded(child: _buildSelectionButton(context: context, label: 'No', isSelected: !isYesSelected, onTap: () => onSelection(false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton({required BuildContext context, required String label, required bool isSelected, required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: isSelected ? 2:0,
      ),
      child: Text(label),
    );
  }

  Widget _buildThemeOption({required BuildContext context, required String label, required IconData icon, required ThemeMode themeMode, required bool isSelected, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _calculateBmi();
    final String formattedCreatedAt = _createdAt != null && _createdAt!.isNotEmpty && DateTime.tryParse(_createdAt!) != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(_createdAt!))
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: _isSavingProfile ? const SizedBox(width:20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_isEditingNonReminderFields ? Icons.save_outlined : Icons.edit_outlined),
            onPressed: _isSavingProfile ? null : _toggleMainProfileEditing,
            tooltip: _isEditingNonReminderFields ? 'Save Profile Changes' : 'Edit Profile Details',
          ),
          IconButton( icon: const Icon(Icons.logout_outlined ), onPressed: () => _logoutUser(context), tooltip: 'Logout',),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Column(children: [ CircleAvatar(radius: 60, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2), child: Icon(Icons.person, size: 80, color: Theme.of(context).colorScheme.primary,),), const SizedBox(height: 12), if (_isEditingNonReminderFields) TextButton.icon(onPressed: _addProfilePicture, icon: const Icon(Icons.camera_alt_outlined, size: 18), label: const Text('Change Picture'),), ],),),
              const SizedBox(height: 30),
              // Personal Info Card
              Card(elevation:_isEditingNonReminderFields ? 2 : 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: AbsorbPointer(absorbing:!_isEditingNonReminderFields, child: Opacity(opacity: _isEditingNonReminderFields ? 1.0 : 0.7, child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Personal Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height: 30), _buildProfileRow(context, 'Name', _nameController, isEditing: _isEditingNonReminderFields, validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null), _buildProfileRow(context, 'Age', _ageController, isEditing: _isEditingNonReminderFields, keyboardType: TextInputType.number, validator: (v){if(v!=null && v.isNotEmpty && int.tryParse(v)==null) return "Invalid age"; return null;}), _buildProfileRow(context, 'Height (cm)', _heightController, isEditing: _isEditingNonReminderFields, keyboardType: TextInputType.number, validator: (v){if(v!=null && v.isNotEmpty && double.tryParse(v)==null) return "Invalid height"; return null;}), _buildProfileRow(context, 'Weight (kg)', _weightController, isEditing: _isEditingNonReminderFields, keyboardType: TextInputType.number, validator: (v){if(v!=null && v.isNotEmpty && double.tryParse(v)==null) return "Invalid weight"; return null;}), if (bmi != null && !_isEditingNonReminderFields) _buildInfoDisplayRow(context, 'BMI', _formatBmi(bmi)), if (!_isEditingNonReminderFields) _buildInfoDisplayRow(context, 'Member Since', formattedCreatedAt), ]),),),)),
              const SizedBox(height: 20),
              // Sleep Schedule Card
              Card(elevation: _isEditingNonReminderFields ? 2 : 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: AbsorbPointer(absorbing:!_isEditingNonReminderFields, child: Opacity(opacity: _isEditingNonReminderFields ? 1.0 : 0.7, child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Sleep Schedule', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height: 30), if (_isEditingNonReminderFields) ...[ ListTile(title: const Text("Sleep Time"), trailing: Text(_selectedSleepTime?.format(context) ?? "Set"), onTap: () async { final tod = await showTimePicker(context: context, initialTime: _selectedSleepTime ?? TimeOfDay(hour: 22, minute: 0)); if(tod!=null) setState(()=>_selectedSleepTime=tod);}), ListTile(title: const Text("Wake Time"), trailing: Text(_selectedWakeTime?.format(context) ?? "Set"), onTap: () async { final tod = await showTimePicker(context: context, initialTime: _selectedWakeTime ?? TimeOfDay(hour: 7, minute: 0)); if(tod!=null) setState(()=>_selectedWakeTime=tod);}), if (_selectedSleepTime != null && _selectedWakeTime != null) Padding(padding: const EdgeInsets.all(8.0), child: Center(child: Text('Duration: ${_getSleepDuration()}')))] else ...[ _buildInfoDisplayRow(context, 'Sleep Time', _selectedSleepTime?.format(context) ?? 'Not set'), _buildInfoDisplayRow(context, 'Wake-up Time', _selectedWakeTime?.format(context) ?? 'Not set'), if (_selectedSleepTime != null && _selectedWakeTime != null) _buildInfoDisplayRow(context, 'Sleep Duration',_getSleepDuration())], ]),),),)),
              const SizedBox(height: 20),
              // Reminders Card - This card is always interactive for its own content
              Card( elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Reminders', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height: 30), SwitchListTile(activeColor: Theme.of(context).colorScheme.primary, title: const Text('Water Reminder'), subtitle: Text(_isWaterReminderEnabled ? 'Enabled (Every $_waterIntervalHours hrs)' : 'Disabled'), value: _isWaterReminderEnabled, onChanged: (val){setState(()=>_isWaterReminderEnabled=val); _saveAndRescheduleAllReminders();}), if(_isWaterReminderEnabled) Padding(padding: const EdgeInsets.fromLTRB(16,0,16,8), child: Row(children: [const Text("Interval: "), Expanded(child: Slider(value: _waterIntervalHours.toDouble(), min:1,max:8,divisions:7,label:"$_waterIntervalHours hr${_waterIntervalHours>1?'s':''}", activeColor:Theme.of(context).colorScheme.primary, onChanged: (val)=>setState(()=>_waterIntervalHours=val.toInt()), onChangeEnd:(_)=>_saveAndRescheduleAllReminders(),)), Text("$_waterIntervalHours hr${_waterIntervalHours>1?'s':''}")])), SwitchListTile(activeColor: Theme.of(context).colorScheme.primary, title: const Text('Morning Walk'), subtitle: Text(_isWalkReminderEnabled ? 'Enabled (15m after wake)' : 'Disabled'), value: _isWalkReminderEnabled, onChanged: (val){setState(()=>_isWalkReminderEnabled=val); _saveAndRescheduleAllReminders();}), const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Custom Reminders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)), IconButton(icon: const Icon(Icons.add_alarm_outlined), tooltip: 'Add Reminder', onPressed: () => _showReminderDialog())]), if (_userReminders.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical:8), child: Text('No custom reminders set.', style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).hintColor))), if (_userReminders.isNotEmpty) ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _userReminders.length, itemBuilder: (ctx,idx){ final r = _userReminders[idx]; return ListTile(title: Text(r.title), subtitle: Text('${r.time.format(context)} - ${r.frequency.toString().split('.').last}'), leading: Switch(value: r.isEnabled, activeColor: Theme.of(context).colorScheme.primary, onChanged: (val){setState(()=>_userReminders[idx].isEnabled=val); _saveAndRescheduleAllReminders();}), trailing: Row(mainAxisSize:MainAxisSize.min, children:[IconButton(icon:const Icon(Icons.edit_outlined, size:20),onPressed:()=>_showReminderDialog(reminder:r,index:idx)), IconButton(icon:Icon(Icons.delete_outline, size:20, color:Theme.of(context).colorScheme.error),onPressed:()=>_deleteReminder(idx))]));}) ]))),
              const SizedBox(height: 20),
              // Dietary Preference, Gender, Health Info Cards
              Card(elevation: _isEditingNonReminderFields ? 2 : 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: AbsorbPointer(absorbing:!_isEditingNonReminderFields, child: Opacity(opacity: _isEditingNonReminderFields ? 1.0 : 0.7, child: Padding(padding:const EdgeInsets.all(20), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('Dietary Preference', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height:30), if (_isEditingNonReminderFields) ...[ _buildSelectionButton(context:context, label:'Vegetarian', isSelected: _selectedDietaryPreference=='Vegetarian', onTap:()=>setState(()=>_selectedDietaryPreference='Vegetarian')), const SizedBox(height:10), _buildSelectionButton(context:context, label:'Non-vegetarian', isSelected: _selectedDietaryPreference=='Non-vegetarian', onTap:()=>setState(()=>_selectedDietaryPreference='Non-vegetarian')), const SizedBox(height:10), _buildSelectionButton(context:context, label:'Vegan', isSelected: _selectedDietaryPreference=='Vegan', onTap:()=>setState(()=>_selectedDietaryPreference='Vegan')), if (_selectedDietaryPreference == null && _formKey.currentState?.validate() == false /* only show if tried to submit */ ) Padding(padding: const EdgeInsets.only(top:8.0), child: Text('Please select a preference.', style: TextStyle(color: Theme.of(context).colorScheme.error)))] else _buildInfoDisplayRow(context, 'Preference', _selectedDietaryPreference ?? 'Not specified') ]))))),
              const SizedBox(height: 20),
              Card(elevation: _isEditingNonReminderFields ? 2 : 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: AbsorbPointer(absorbing:!_isEditingNonReminderFields, child: Opacity(opacity: _isEditingNonReminderFields ? 1.0 : 0.7, child: Padding(padding:const EdgeInsets.all(20), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('Gender', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height:30), if(_isEditingNonReminderFields) ...[_buildSelectionButton(context:context,label:'Male',isSelected:_selectedGender=='Male',onTap:()=>setState(()=>_selectedGender='Male')), const SizedBox(height:10), _buildSelectionButton(context:context,label:'Female',isSelected:_selectedGender=='Female',onTap:()=>setState(()=>_selectedGender='Female')), const SizedBox(height:10), _buildSelectionButton(context:context,label:'Other',isSelected:_selectedGender=='Other',onTap:()=>setState(()=>_selectedGender='Other')), if (_selectedGender == null && _formKey.currentState?.validate() == false) Padding(padding: const EdgeInsets.only(top:8.0), child: Text('Please select a gender.', style: TextStyle(color: Theme.of(context).colorScheme.error)))] else _buildInfoDisplayRow(context, 'Gender', _selectedGender ?? 'Not specified') ]))))),
              const SizedBox(height: 20),
              Card(elevation: _isEditingNonReminderFields ? 2 : 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: AbsorbPointer(absorbing:!_isEditingNonReminderFields, child: Opacity(opacity: _isEditingNonReminderFields ? 1.0 : 0.7, child: Padding(padding:const EdgeInsets.all(20), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('Health Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height:30), if(_isEditingNonReminderFields) ...[_buildHealthAssessmentRowEditable(context,'Diabetes',_hasDiabetes,(val)=>setState(()=>_hasDiabetes=val)),_buildHealthAssessmentRowEditable(context,'Protein Deficiency',_hasProteinDeficiency,(val)=>setState(()=>_hasProteinDeficiency=val)), _buildHealthAssessmentRowEditable(context,'Skinny Fat',_isSkinnyFat,(val)=>setState(()=>_isSkinnyFat=val))] else ...[_buildHealthInfoRow(context,'Diabetes',_hasDiabetes), _buildHealthInfoRow(context,'Protein Deficiency',_hasProteinDeficiency), _buildHealthInfoRow(context,'Skinny Fat',_isSkinnyFat)], const Divider(height:30), Text('Allergies', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)), const SizedBox(height:16), if(_isEditingNonReminderFields) ...[Row(children:[Expanded(child:TextFormField(controller:_newAllergyController, decoration:InputDecoration(labelText:'Add Allergy', hintText: 'e.g., Peanuts', border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))), onFieldSubmitted:(_)=>_addAllergy())), const SizedBox(width:8), ElevatedButton.icon(icon:const Icon(Icons.add),label:const Text("Add"),onPressed:_addAllergy, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)))]), const SizedBox(height:20), if (_allergies.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your Allergies:', style: Theme.of(context).textTheme.titleSmall), const SizedBox(height:8),Wrap(spacing:8, runSpacing:4, children:_allergies.asMap().entries.map((entry) => Chip(label:Text(entry.value), deleteIcon:const Icon(Icons.close,size:18), onDeleted:()=>_removeAllergy(entry.key), backgroundColor: Theme.of(context).colorScheme.primaryContainer, labelStyle: TextStyle(color:Theme.of(context).colorScheme.onPrimaryContainer))).toList())]) else Text('No allergies added yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))) ] else _allergies.isEmpty ? Text('No allergies reported.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))) : Wrap(spacing:8, runSpacing:4, children:_allergies.map((a)=>Chip(label:Text(a), backgroundColor: Theme.of(context).colorScheme.secondaryContainer, labelStyle: TextStyle(color:Theme.of(context).colorScheme.onSecondaryContainer))).toList()) ]))))),
              const SizedBox(height: 20),
              // App Theme Card - Always interactive
              Card(elevation:4, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)), child:Padding(padding:const EdgeInsets.all(20), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('App Theme', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const Divider(height:30), _buildThemeOption(context:context, label:'System Default', icon:Icons.settings_brightness_outlined, themeMode:ThemeMode.system, isSelected:Provider.of<ThemeProvider>(context).themeMode==ThemeMode.system, onTap:()=>Provider.of<ThemeProvider>(context,listen:false).setThemeMode(ThemeMode.system)), const SizedBox(height:10), _buildThemeOption(context:context, label:'Light Theme', icon:Icons.wb_sunny_outlined, themeMode:ThemeMode.light, isSelected:Provider.of<ThemeProvider>(context).themeMode==ThemeMode.light, onTap:()=>Provider.of<ThemeProvider>(context,listen:false).setThemeMode(ThemeMode.light)), const SizedBox(height:10), _buildThemeOption(context:context, label:'Dark Theme', icon:Icons.nightlight_round_outlined, themeMode:ThemeMode.dark, isSelected:Provider.of<ThemeProvider>(context).themeMode==ThemeMode.dark, onTap:()=>Provider.of<ThemeProvider>(context,listen:false).setThemeMode(ThemeMode.dark)), ]))),
              const SizedBox(height: 40), // Extra space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}