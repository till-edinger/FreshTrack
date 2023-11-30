import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

import 'scanner_setting.dart';
import 'foodinfo_manuel.dart';
import 'main.dart';

// catches exceptions in the FetchFoodInfo method
class FetchFoodInfoException implements Exception {
  final String message;

  FetchFoodInfoException(this.message);
}

// catches exceptions in the SaveToFirestore method
class SaveToFirestoreException implements Exception {
  final String message;

  SaveToFirestoreException(this.message);
}

class FoodInfoService {

  final ScannerSettings scannerSettings = ScannerSettings();

  // the actual scanfunction. calls up the individual methods and outputs error messages
  Future<void> scanAndSaveToFirestore(BuildContext context) async {
    try {
      final result = await BarcodeScanner.scan(
        options: ScanOptions(
          restrictFormat: scannerSettings.selectedFormats,
          useCamera: scannerSettings.selectedCamera,
          autoEnableFlash: scannerSettings.autoEnableFlash,
          android: AndroidOptions(
            aspectTolerance: scannerSettings.aspectTolerance,
            useAutoFocus: scannerSettings.useAutoFocus,
          ),
        ),
      );

      if (result.type == ResultType.Barcode) {
        final foodInfo = await fetchFoodInfo(result.rawContent);
        await saveBarcodeInformationToFirestore(context, foodInfo);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      if (e is FetchFoodInfoException) {
        showPopupScanError(context, e.message);
      } else if (e is SaveToFirestoreException) {
        showPopupScanError(context, e.message);
      } else {
        showPopupScanError(context, 'Scannen nicht möglich:$e'
            'Versuchen sie es erneut oder geben sie'
            ' ihre Lebensmittelinformationen manuelle ein');
      }
    }
  }

  // Retrieves the information about the scanned barcode via the
  // https://world.openfoodfacts.org/api/v0/product/$barcode.json API
  // and saves the data from the json as Map<String, dynamic>
  Future<Map<String, dynamic>?> fetchFoodInfo(String barcode) async {

    try {
      final response = await http.get(
        Uri.parse(
            'https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      throw FetchFoodInfoException('Lebensmittelinformationen konnten nicht geladen weren: $e '
          'Versuchen sie es erneut oder geben sie'
          ' ihre Lebensmittelinformationen manuelle ein');
    }
    return null;
  }

  // automatic saving of food information if a product name and a
  // correct expiry date is available, if not then a popup for manual entry is opened
  Future<void> saveBarcodeInformationToFirestore(BuildContext context, Map<String, dynamic>? foodInfo) async {
    try {
      if (foodInfo != null && foodInfo['product'] != null) {

        var productData = foodInfo['product'];
        var expirationDate = DateTime.parse(productData['expiration_date']);

        if (productData['product_name'] != null &&
            productData['expiration_date'] != null
            &&expirationDate.isAfter(DateTime.now()))
        {

            final CollectionReference foodItems =
            FirebaseFirestore.instance.collection('food_items');

            //Extract calories from nutriments, as subordinate
            var nutriments = productData['nutriments'] ?? {};
            var calValue = nutriments['energy-kcal_100g'];
            String calString = calValue != null ? calValue.toString() : 'N/A';
            var foodItem = {
              'product_name': productData['product_name'] ?? 'N/A',
              'image_url': productData['image_url'] ?? 'N/A',
              'expiration_date': productData['expiration_date'] ?? 'N/A',
              'brand_name': productData['brands'] ?? 'N/A',
              'ingredients': productData['ingredients_text'] ?? 'N/A',
              'cal': calString,
              'quantity': productData['quantity'] ?? 'N/A',
              'nutriscore': productData['nutriscore_grade'] ?? 'N/A',
              'userId': FirebaseAuth.instance.currentUser?.uid,
            };
            await foodItems.add(foodItem);
        } else {
          print('Calling showManualEntryPopUpWithFoodInfo');
          await showManualEntryPopUpWithFoodInfo(context, productData);
        }
      }
    } catch (e) {
      throw SaveToFirestoreException('Daten konnten nicht gespeichert werden: $e '
          'Versuchen sie es erneut oder geben sie'
          ' ihre Lebensmittelinformationen manuelle ein');
    }
  }

  // PopUp when an error is issued during scanning (scanAndSaveToFirestore)
  void showPopupScanError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showManualEntryPopup(context);              },
              child: const Text('Manuelle Eingabe'),
            ),
          ],
        );
      },
    );
  }

  // PopUp when trying to scan without being logged in
  void logInToScan(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Melden sie sich zuerst an',
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/login');
                      },
                      child: const Text('Anmelden'),
                    ),
                    const SizedBox(width: 8.0),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Abbrechen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


Future<void> showManualEntryPopUpWithFoodInfo(BuildContext context, productData) async {
  print('showManualEntryPopUpWithFoodInfo called');

  final ManualEntryScreenState manualEntryScreenState = ManualEntryScreenState();


  TextEditingController productNameController = TextEditingController();
  TextEditingController expirationDateController = TextEditingController();

  // Set default values for the case when properties are not present
  productNameController.text = productData?['product_name'] ?? '';
  expirationDateController.text = productData?['expiration_date'] ??
      manualEntryScreenState.expirationDateController;

  TextEditingController brandNameController = TextEditingController(
      text: productData?['brands'] ?? 'N/A');
  TextEditingController ingredientsController = TextEditingController(
      text: productData?['ingredients_text'] ?? 'N/A');
  TextEditingController quantityController = TextEditingController(
      text: productData?['quantity'] ?? 'N/A');
  TextEditingController nutriscoreController = TextEditingController(
      text: productData?['nutriscore_grade'] ?? 'N/A');

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Manuelle Eingabe erforderlich'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Produktname'),
                validator: (value) =>
                    manualEntryScreenState.validateProductName(value),
              ),
              TextFormField(
                controller: expirationDateController,
                decoration: const InputDecoration(
                    labelText: 'Verfallsdatum (YYYY-MM-DD)'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    manualEntryScreenState.validateExpirationDate(value),
              ),
              TextField(
                controller: brandNameController,
                decoration: const InputDecoration(labelText: 'Markenname'),
              ),
              TextField(
                controller: ingredientsController,
                decoration: const InputDecoration(labelText: 'Zutaten'),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Menge'),
              ),
              TextField(
                controller: nutriscoreController,
                decoration: const InputDecoration(labelText: 'Nutriscore'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              // Validiere die manuell eingegebenen Daten
              String? productNameError = manualEntryScreenState
                  .validateProductName(productNameController.text);
              String? expirationDateError = manualEntryScreenState
                  .validateExpirationDate(expirationDateController.text);

              if (productNameError == null && expirationDateError == null) {
                // Speichere die manuell eingegebenen Daten
                final CollectionReference foodItems = FirebaseFirestore.instance
                    .collection('food_items');

                var nutriments = productData?['nutriments'] ?? {};
                var calValue = nutriments['energy-kcal_100g'];
                String calString = calValue != null
                    ? calValue.toString()
                    : 'N/A';

                var foodItem = {
                  'product_name': productNameController.text,
                  'image_url': productData?['image_url'] ??
                      'https://www.stadt-koeln.de/img/responsive/bilder-leichtesprache-lebensmittel_1024.jpg',
                  'expiration_date': expirationDateController.text,
                  'brand_name': brandNameController.text,
                  'ingredients': ingredientsController.text,
                  'cal': calString,
                  'quantity': quantityController.text,
                  'nutriscore': nutriscoreController.text,
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                };

                await foodItems.add(foodItem);
                Navigator.pop(context); // Schließe das Popup
              } else {
                // Zeige die Validierungsfehler an
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$productNameError\n$expirationDateError')));
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      );
    },
  );
}
