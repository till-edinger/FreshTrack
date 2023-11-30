import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Managing and providing application settings
class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;

  // Flag indicating whether notifications are enabled
  bool _notificationsEnabled = false;
  bool get notificationsEnabled => _notificationsEnabled;

  // Flag indicating whether dark mode is enabled
  bool _darkModeEnabled = false;
  bool get darkModeEnabled => _darkModeEnabled;

  // Constructor that initializes settings by calling the private method [_loadSettings]
  SettingsProvider() {
    _loadSettings();
  }

  // Loads settings from SharedPreferences and notifies listeners
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = _prefs.getBool('notificationsEnabled') ?? false;
    _darkModeEnabled = _prefs.getBool('darkModeEnabled') ?? false;
    notifyListeners();
  }

  // Saves current settings to SharedPreferences.
  Future<void> _saveSettings() async {
    await _prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await _prefs.setBool('darkModeEnabled', _darkModeEnabled);
  }

  // Toggles the notifications setting and saves the changes
  void toggleNotifications(bool value) {
    _notificationsEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  // Toggles the dark mode setting and saves the changes
  void toggleDarkMode(bool value) {
    _darkModeEnabled = value;
    _saveSettings();
    notifyListeners();
  }
}



