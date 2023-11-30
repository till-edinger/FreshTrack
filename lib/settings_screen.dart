import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_provider.dart';
import 'scanner_setting.dart';
import 'main.dart';
import 'notifications.dart';

// Die Einstellungen sind ein StatefulWidget
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final DailyNotifications dailyNotifications = DailyNotifications();

    return Scaffold(
      appBar: AppBar(
        title: Text('Einstellungen'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          ListTile(
            title: Text('Benachrichtigungen'),
            trailing: Switch(
              //Switch on notifications
              value: settingsProvider.notificationsEnabled,
              onChanged: (value) {
                settingsProvider.toggleNotifications(value);
                dailyNotifications.switchOnNotification(context);
                // Geändert
              },
            ),
          ),
          ListTile(
            title: Text('Thema und Design'),
            trailing: Switch(
              //Switch on theme
              value: settingsProvider.darkModeEnabled,
              onChanged: (value) {
                settingsProvider.toggleDarkMode(value);
              },
            ),
          ),
          ListTile(
            title: Text('Scanner Einstellungen'),
            onTap: () {
              // Navigate to ScannerSettings
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScannerSettings()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: Footer(),
    );
  }
}