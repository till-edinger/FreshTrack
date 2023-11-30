import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// Initialize notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Request notification permission for IOS and Android
class RequestPermission {

  bool _notificationPermission = false;

  Future<void> requestNotificationPermission() async {

    if (Platform.isIOS) {

      bool? permissionsGranted =
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      _notificationPermission = permissionsGranted ?? false;
      // print("$_notificationPermission");

    } else if (Platform.isAndroid) {

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
      await androidImplementation?.requestNotificationsPermission();
      _notificationPermission = grantedNotificationPermission ?? false;
      // print("$_notificationPermission");
    }
  }

  //Cancel all notification
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  //Initialize permission when starting the app and cancel all notifications if no permission
  Future<void> initializePermission() async {
    SettingsProvider settingsProvider = SettingsProvider();

    await requestNotificationPermission();

    if (!_notificationPermission) {
      cancelAllNotifications();
      settingsProvider.toggleNotifications(false);
    }
  }
}

//class for daily notification
class DailyNotifications {

final RequestPermission requestPermission = RequestPermission();

// switch notifications on and off via a toogle in settings_screen.dart
  Future<void> switchOnNotification(BuildContext context) async {

    SettingsProvider settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    await requestPermission.requestNotificationPermission();

    // Check if notifications are enabled and the notification permission is granted
    if (settingsProvider.notificationsEnabled && requestPermission._notificationPermission) {
      scheduleDailyNotification();
    } else {
      cancelNotifications();
      if (settingsProvider.notificationsEnabled && !requestPermission._notificationPermission) {
        _showEnableNotificationsDialog(context);
        settingsProvider.toggleNotifications(false);
      }
    }
  }

  // Function for calculating the next notification time
  tz.TZDateTime _notificationTime() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, 17, 30);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
//Update the daily notification body, to get the nearest expiration dates
  Future<void> updateDailyNotification() async {
    SettingsProvider settingsProvider = SettingsProvider();
    RequestPermission requestPermission = RequestPermission();

    await requestPermission.requestNotificationPermission();

  if (settingsProvider.notificationsEnabled && requestPermission._notificationPermission) {
        scheduleDailyNotification();
  }
}
  // Function for scheduling a daily notification
Future<void> scheduleDailyNotification() async {
  try {

    GetFoodItemDataFromFirestore getDataFromFirestore = GetFoodItemDataFromFirestore();

    // Call up products
    List<Map<String, dynamic>> foodItemsList = await getDataFromFirestore.getFoodItems();

    // List for products that expire next
    List<Map<String, dynamic>> expiringProducts = [];

    // Current date
    DateTime currentDate = DateTime.now();

    // Filter products that expire next
    foodItemsList.forEach((data) {

      if (data.containsKey('expiration_date')) {

        DateTime expirationDate = DateTime.parse(data['expiration_date']);

        // Add the product to the list if the expiry date is within the next 5 days
        if (expirationDate.difference(currentDate).inDays <= 3) {
          expiringProducts.add(data);
        }
      }
    });

    // Check whether at least one product was found
    if (expiringProducts.isNotEmpty) {
      // Create the body text based on the products found
      String bodyText = 'Die folgenden Produkte laufen bald ab:\n';

      for (var product in expiringProducts) {
        bodyText += '- ${product['name']}, Ablaufdatum: ${product['expiration_date']}\n';
      }

      // Schedule notification with updated body text
      await flutterLocalNotificationsPlugin.zonedSchedule(
        1,
        'Ihre Lebensmittel laufen bald ab',
        bodyText,
        _notificationTime(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id 1',
            'Ihre Lebensmittel laufen bald ab',
            channelDescription: 'Es wird eine Benachrichtigung ausgegeben, wenn die Lebensmittel in zwei Tagen oder früher ablaufen',
            icon: '@mipmap/ic_launcher', // Set your small icon here
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Schedule notification with updated body text
      await flutterLocalNotificationsPlugin.zonedSchedule(
        1,
        'Behalte den Überblick über deine Lebensmittel',
        '',
        _notificationTime(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id 1',
            'Ihre Lebensmittel laufen bald ab',
            channelDescription: 'Es wird eine Benachrichtigung ausgegeben, wenn die Lebensmittel in zwei Tagen oder früher ablaufen',
            icon: '@mipmap/ic_launcher', // Set your small icon here
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  } catch (e) {
    print('Fehler beim Planen der Benachrichtigung: $e');
  }
}


  // Function for cancelling the daily notification important if further notifications are added
  Future<void> cancelNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(1);
  }

  // PopUp if the notifications are to be switched on but the notifications are deactivated in the device settings
  // With a navigator to device settings
  void _showEnableNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Benachrichtigungen aktivieren'),
          content: const Text(
              'Gehe zu den Geräteeinstellungen und aktiviere Benachrichtigungen.'),
          actions: [
            TextButton(
              onPressed: () {
                AppSettings.openAppSettings(type: AppSettingsType.notification);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context);
              },
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }
}

class GetFoodItemDataFromFirestore {

  Future<List<Map<String, dynamic>>> getFoodItems() async {
    CollectionReference foodItemsCollection = FirebaseFirestore.instance.collection('food_items');

    // Retrieve documents from the collection
    QuerySnapshot querySnapshot = await foodItemsCollection.get();

    // save in foodItemList
    List<Map<String, dynamic>> foodItemList = [];

    querySnapshot.docs.forEach((doc) {
      Map<String, dynamic> foodItem = doc.data() as Map<String, dynamic>;


      //Add the food product to the list
      foodItemList.add(foodItem);
    });

    return foodItemList;
  }
}
