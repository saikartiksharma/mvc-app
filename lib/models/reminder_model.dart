// lib/models/reminder_model.dart
import 'package:flutter/material.dart'; // For TimeOfDay

enum ReminderFrequency { once, daily, weekdays, weekends, specificDays }

class Reminder {
  String id; // Unique ID (e.g., Firestore doc ID or generated like DateTime.now().millisecondsSinceEpoch.toString())
  String title;
  TimeOfDay time;
  ReminderFrequency frequency;
  List<int>? specificDays; // 1 for Monday, 7 for Sunday (if frequency is specificDays)
  bool isEnabled;
  bool isDefault; // To distinguish app's default vs user-created
  String? payload; // Optional, for notification interaction

  Reminder({
    required this.id,
    required this.title,
    required this.time,
    this.frequency = ReminderFrequency.daily,
    this.specificDays,
    this.isEnabled = true,
    this.isDefault = false,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'frequency': frequency.toString(), // Store enum as string name
      'specificDays': specificDays,
      'isEnabled': isEnabled,
      'isDefault': isDefault,
      'payload': payload,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String? ?? "00:00").split(':');
    TimeOfDay parsedTime;
    if (timeParts.length == 2) {
      parsedTime = TimeOfDay(hour: int.tryParse(timeParts[0]) ?? 0, minute: int.tryParse(timeParts[1]) ?? 0);
    } else {
      parsedTime = const TimeOfDay(hour: 0, minute: 0); // Fallback
    }

    ReminderFrequency freq = ReminderFrequency.daily;
    final freqString = json['frequency'] as String?;
    if (freqString != null) {
      try {
        freq = ReminderFrequency.values.firstWhere((e) => e.toString() == freqString);
      } catch (e) {
        // If string from JSON doesn't match any enum, default to daily
        freq = ReminderFrequency.daily;
      }
    }

    return Reminder(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled Reminder',
      time: parsedTime,
      frequency: freq,
      specificDays: json['specificDays'] != null ? List<int>.from(json['specificDays']) : null,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      payload: json['payload'] as String?,
    );
  }

  // Added copyWith method
  Reminder copyWith({
    String? id,
    String? title,
    TimeOfDay? time,
    ReminderFrequency? frequency,
    List<int>? specificDays,
    bool? isEnabled,
    bool? isDefault,
    String? payload,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      specificDays: specificDays ?? this.specificDays, // Be careful with list copying if deep copy is needed
      isEnabled: isEnabled ?? this.isEnabled,
      isDefault: isDefault ?? this.isDefault,
      payload: payload ?? this.payload,
    );
  }
}