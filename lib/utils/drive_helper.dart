// lib/utils/drive_helper.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart'; // Added for TimeOfDay

class DriveHelper {
  static const String _userDataFileId = "1pb5oQO4bv6fOGtIwCOaswTt9cdGtCuPo"; // Your .txt file ID
  static const String _userDataDownloadUrl = "https://drive.google.com/uc?export=download&id=$_userDataFileId";

  // New CSV Headers: email is the key, no password field in CSV
  // email,name,age,height,weight,gender,dietaryPreference,sleepTime,wakeTime,createdAt,allergies,hasDiabetes,hasProteinDeficiency,isSkinnyFat
  static const List<String> _csvHeaders = [
    "email", "name", "age", "height", "weight", "gender",
    "dietaryPreference", "sleepTime", "wakeTime", "createdAt", "allergies",
    "hasDiabetes", "hasProteinDeficiency", "isSkinnyFat"
  ];

  // In-memory cache for simulation purposes during a single app session
  static List<Map<String, dynamic>>? _inMemoryUserDataCache;
  static bool _hasFetchedOnce = false;

  // Helper to convert TimeOfDay to "HH:mm" string - MADE PUBLIC
  static String timeOfDayToString(TimeOfDay? tod) {
    if (tod == null) return "";
    return "${tod.hour.toString().padLeft(2, '0')}:${tod.minute
        .toString()
        .padLeft(2, '0')}";
  }

  // Helper to convert "HH:mm" string to TimeOfDay - MADE PUBLIC
  static TimeOfDay? stringToTimeOfDay(String? todString) {
    if (todString == null || todString.isEmpty) return null;
    final parts = todString.split(':');
    if (parts.length == 2) {
      try {
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        if (kDebugMode) print(
            "DriveHelper: Error parsing TimeOfDay string '$todString': $e");
        return null;
      }
    }
    return null;
  }

  // Fetches all user data and converts from CSV to List<Map<String, dynamic>>
  // Each map in the list is structured as: {"email": "...", "profile": {...}}
  // The "password" field is no longer expected from the CSV for OAuth.
  static Future<List<Map<String, dynamic>>?> fetchAndParseAllUsersDataCsv(
      {bool forceNetwork = false}) async {
    if (!forceNetwork && _hasFetchedOnce && _inMemoryUserDataCache != null) {
      if (kDebugMode) print(
          "DriveHelper: Returning user data from in-memory cache.");
      return List<Map<String, dynamic>>.from(
          _inMemoryUserDataCache!.map((user) =>
          Map<String, dynamic>.from(user)
            ..['profile'] = Map<String, dynamic>.from(
                user['profile'] as Map<String, dynamic>? ?? {})
          )
      );
    }

    if (kDebugMode) {
      print(
          "DriveHelper: Fetching and parsing user data CSV from $_userDataDownloadUrl");
    }
    try {
      final response = await http.get(Uri.parse(_userDataDownloadUrl));
      _hasFetchedOnce = true;

      if (response.statusCode == 200) {
        String fileContent = utf8.decode(response.bodyBytes);
        List<String> lines = fileContent.split('\n').where((line) =>
        line
            .trim()
            .isNotEmpty).toList();
        List<Map<String, dynamic>> allUsersData = [];

        if (lines.isEmpty) {
          _inMemoryUserDataCache = [];
          return [];
        }

        for (String line in lines) {
          List<String> values = line.split(',');
          if (values.length ==
              _csvHeaders.length) { // Check against new header length
            Map<String, dynamic> userEntry = {
              "email": values[_csvHeaders.indexOf("email")].trim(),
              // First column is email
              // "password" field is removed from this structure as Google handles auth
              "profile": {
                "name": values[_csvHeaders.indexOf("name")].trim(),
                "age": values[_csvHeaders.indexOf("age")].trim(),
                "height": values[_csvHeaders.indexOf("height")].trim(),
                "weight": values[_csvHeaders.indexOf("weight")].trim(),
                "gender": values[_csvHeaders.indexOf("gender")]
                    .trim()
                    .isEmpty ? null : values[_csvHeaders.indexOf("gender")]
                    .trim(),
                "dietaryPreference": values[_csvHeaders.indexOf(
                    "dietaryPreference")]
                    .trim()
                    .isEmpty ? null : values[_csvHeaders.indexOf(
                    "dietaryPreference")].trim(),
                "sleepTime": values[_csvHeaders.indexOf("sleepTime")].trim(),
                "wakeTime": values[_csvHeaders.indexOf("wakeTime")].trim(),
                "createdAt": values[_csvHeaders.indexOf("createdAt")].trim(),
                "allergies": values[_csvHeaders.indexOf("allergies")]
                    .trim()
                    .isEmpty
                    ? []
                    : values[_csvHeaders.indexOf("allergies")]
                    .trim()
                    .split(';')
                    .where((s) => s.isNotEmpty)
                    .toList(),
                "hasDiabetes": values[_csvHeaders.indexOf("hasDiabetes")]
                    .trim()
                    .toLowerCase() == 'true',
                "hasProteinDeficiency": values[_csvHeaders.indexOf(
                    "hasProteinDeficiency")].trim().toLowerCase() == 'true',
                "isSkinnyFat": values[_csvHeaders.indexOf("isSkinnyFat")]
                    .trim()
                    .toLowerCase() == 'true',
              }
            };
            allUsersData.add(userEntry);
          } else {
            if (kDebugMode) print(
                "DriveHelper: Skipped malformed CSV line (parts count ${values
                    .length} vs ${_csvHeaders.length}): $line");
          }
        }
        _inMemoryUserDataCache = List<Map<String, dynamic>>.from(
            allUsersData.map((user) =>
            Map<String, dynamic>.from(user)
              ..['profile'] = Map<String, dynamic>.from(
                  user['profile'] as Map<String, dynamic>? ?? {})
            )
        );
        return allUsersData;
      } else {
        if (kDebugMode) print(
            "DriveHelper: Failed to fetch user data CSV. Status: ${response
                .statusCode}");
        if (response.statusCode == 404) {
          _inMemoryUserDataCache = [];
          return [];
        }
        _inMemoryUserDataCache = null;
        return null;
      }
    } catch (e) {
      if (kDebugMode) print("DriveHelper: Exception fetching/parsing CSV: $e");
      _inMemoryUserDataCache = null;
      return null;
    }
  }

  // Updates the entire CSV content on Drive (simulated)
  // allUsersData is List<Map<String, dynamic>> where each map is {"email": "...", "profile": {...}}
  static Future<bool> updateAllUsersDataCsv(
      List<Map<String, dynamic>> allUsersData) async {
    _inMemoryUserDataCache = List<Map<String, dynamic>>.from(
        allUsersData.map((user) =>
        Map<String, dynamic>.from(user)
          ..['profile'] = Map<String, dynamic>.from(
              user['profile'] as Map<String, dynamic>? ?? {})
        )
    );
    _hasFetchedOnce = true;

    List<String> csvLines = [];
    // Optional header:
    // csvLines.add(_csvHeaders.join(','));

    for (var userEntry in allUsersData) {
      Map<String, dynamic> profile = userEntry['profile'] as Map<String,
          dynamic>? ?? {};

      String name = profile['name']?.toString() ?? "";
      String age = profile['age']?.toString() ?? "";
      String height = profile['height']?.toString() ?? "";
      String weight = profile['weight']?.toString() ?? "";
      String gender = profile['gender']?.toString() ?? "";
      String dietaryPreference = profile['dietaryPreference']?.toString() ?? "";
      String sleepTimeStr = profile['sleepTime']?.toString() ?? "";
      String wakeTimeStr = profile['wakeTime']?.toString() ?? "";
      String createdAt = profile['createdAt']?.toString() ?? "";
      if (createdAt
          .isEmpty) { // Fallback, should be set during initial profile creation
        createdAt = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(
            DateTime.now().toUtc());
      }

      List<String> allergiesList = List<String>.from(
          profile['allergies'] ?? []);
      String allergiesStr = allergiesList.join(';');

      String hasDiabetesStr = (profile['hasDiabetes'] as bool?)?.toString() ??
          "false";
      String hasProteinDeficiencyStr = (profile['hasProteinDeficiency'] as bool?)
          ?.toString() ?? "false";
      String isSkinnyFatStr = (profile['isSkinnyFat'] as bool?)?.toString() ??
          "false";

      List<String> values = [
        userEntry['email'].toString(), // Email is the first column
        // Password field is removed
        name, age, height, weight, gender, dietaryPreference,
        sleepTimeStr, wakeTimeStr, createdAt,
        allergiesStr, hasDiabetesStr, hasProteinDeficiencyStr, isSkinnyFatStr
      ];
      csvLines.add(values.join(','));
    }
    String csvContent = csvLines.join('\n');

    if (kDebugMode) {
      print(
          "DriveHelper: SIMULATING UPLOAD of CSV with email as key to Google Drive.");
      print("DriveHelper: CSV content for file ID: $_userDataFileId");
      print(csvContent);
      print("----------------------------------------------------");
    }
    // In a real scenario with Google Drive API:
    // final success = await SomeGoogleDriveApiService.overwriteFile(_userDataFileId, csvContent);
    // return success;
    return true; // Simulate success
  }
}