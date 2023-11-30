import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart';

// Pop-up for manual input of food information
void showManualEntryPopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return const AlertDialog(
        content: ManualEntryScreen(),
      );
    },
  );
}

// Input fields for the popup for manual entry. is called up in showManualEntryPopup
class ManualEntryScreen extends StatefulWidget {

  const ManualEntryScreen({Key? key}) : super(key: key);

  @override
  ManualEntryScreenState createState() => ManualEntryScreenState();
}

class ManualEntryScreenState extends State<ManualEntryScreen> {
  final ManualFoodInfoEntry manualEntry = ManualFoodInfoEntry();

  // Create controllers for each text field
  final TextEditingController productNameController = TextEditingController();
  // final TextEditingController imageUrlController = TextEditingController();
  final TextEditingController expirationDateController = TextEditingController();
  final TextEditingController brandNameController = TextEditingController();
  // final TextEditingController ingredientsController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  String? selectedNutriscore;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Validators
  String? validateProductName(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field cannot be empty';
    }
    if (value.length > 50) {
      return 'Maximum length is 50 characters';
    }
    return null;
  }

  String? validateExpirationDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field cannot be empty';
    }

    // Validate the date format
    final RegExp dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(value)) {
      return 'Invalid date format (use YYYY-MM-DD)';
    }

    // Validate the actual existence of the date
    DateTime? parsedDate = DateTime.tryParse(value);
    if (parsedDate == null) {
      return 'Invalid date';
    }

    return null;
  }

  String? validateBrandName(String? value) {
    if (value != null && value.length > 50) {
      return 'Maximum length is 50 characters';
    }
    return null;
  }

  String? validateCalories(String? value) {
    if (value != null && value.isNotEmpty) {
      // Validate that it contains only digits and has at most 5 characters
      final RegExp numericRegex = RegExp(r'^\d+$');
      if (!numericRegex.hasMatch(value) || value.length > 5) {
        return 'Invalid calories format';
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Initialize expirationDateController with the current year and month
    final DateTime now = DateTime.now();
    final String currentYearMonth = '${now.year}-${_addLeadingZero(now.month)}-';
    expirationDateController.text = currentYearMonth;
  }
  // make sure that month always has two characters
  String _addLeadingZero(int value) {
    return value < 10 ? '0$value' : '$value';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Padding(
    padding: const EdgeInsets.all(16.0),
    child: SingleChildScrollView(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    Form(
    key: _formKey,
    child: Column(
    children: [
              TextFormField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Produkt Name'),
                validator: validateProductName,
                onChanged: (value) {
                  setState(() {
                    manualEntry.productName = value;
                  });
                },
              ),
              // TextFormField(
              //   decoration: InputDecoration(labelText: 'Image URL'),
              //   onChanged: (value) {
              //     manualEntry.imageUrl = value;
              //   },
              // ),
              TextFormField(
                controller: expirationDateController,
                decoration: const InputDecoration(
                    labelText: 'Verfallsdatum (YYYY-MM-DD)',),
                keyboardType: TextInputType.number,
                validator: validateExpirationDate,
                onChanged: (value) {
                  setState(() {
                    manualEntry.expirationDate = value;
                  });
                },
              ),
              TextFormField(
                controller: brandNameController,
                decoration: const InputDecoration(labelText: 'Marke'),
                validator: validateBrandName,
                onChanged: (value) {
                  manualEntry.brandName = value;
                },
              ),
              // TextFormField(
              //   decoration: InputDecoration(labelText: 'Ingredients'),
              //   onChanged: (value) {
              //     manualEntry.ingredients = value;
              //   },
              // ),
              TextFormField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Kalorien'),
                validator: validateCalories,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  setState(() {
                    manualEntry.calories = value;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Menge'),
                onChanged: (value) {
                  manualEntry.quantity = value;
                },
              ),
              DropdownButtonFormField<String>(
                value: selectedNutriscore,
                onChanged: (value) {
                  setState(() {
                    selectedNutriscore = value;
                    manualEntry.nutriscore = value ?? '';
                  });
                },
                decoration: const InputDecoration(labelText: 'Nutriscore'),
                items: ['A', 'B', 'C', 'D', 'E', ''].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (validateForm()) {
                    await manualEntry.saveManuelEntryToFirestore(context);
                  }
                },
                child: const Text('Speichern'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  _resetValues();
                  Navigator.of(context).pop();
                },
                child: const Text('Abbrechen'),
              ),
              const SizedBox(height: 16),
                ],
              ),
            ),
    ],
          ),
    ),
    ),
    );
  }

    bool validateForm() {
      if (_formKey.currentState?.validate() ?? false) {
        _formKey.currentState?.save();
        return true;
      }
      return false;
    }

    // Function for resetting the values
  void _resetValues() {
    setState(() {
      productNameController.text = '';
      expirationDateController.text = '';
      brandNameController.text = '';
      caloriesController.text = '';
      quantityController.text = '';
      selectedNutriscore = null;
    });

    // Clear the manualEntry values
    manualEntry.productName = '';
    manualEntry.expirationDate = '';
    manualEntry.brandName = '';
    manualEntry.calories = '';
    manualEntry.quantity = '';
    manualEntry.nutriscore = '';
  }
}

class ManualFoodInfoEntry {
  String productName = '';
  String imageUrl = '';
  String expirationDate = '';
  String brandName = '';
  String ingredients = '';
  String quantity = '';
  String calories = '';
  String nutriscore = '';


  // Save data from manuel input to Firestore
  Future<void> saveManuelEntryToFirestore(BuildContext context) async {

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final CollectionReference foodItems =
        FirebaseFirestore.instance.collection('food_items');

        await foodItems.add({
          'product_name': productName.isNotEmpty ? productName : 'N/A',
          'image_url': imageUrl.isNotEmpty ? imageUrl : 'https://www.stadt-koeln.de/img/responsive/bilder-leichtesprache-lebensmittel_1024.jpg',
          'expiration_date': expirationDate.isNotEmpty ? expirationDate : 'N/A',
          'brand_name': brandName.isNotEmpty ? brandName : 'N/A',
          'ingredients': ingredients.isNotEmpty ? ingredients : 'N/A',
          'quantity': quantity.isNotEmpty ? quantity : 'N/A',
          'cal': calories.isNotEmpty ? calories : 'N/A',
          'nutriscore': nutriscore.isNotEmpty ? nutriscore : 'N/A',
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'email': UserProfile.email,// Include user ID for security/rules if needed
        });
        Navigator.of(context).pop();
      }
    } catch (e) {
      showPopupManuelSaveError(context, 'Speichern nicht möglich:$e'
          'Versuchen sie es erneut oder wenden sie'
          ' sich an den Herausgeber der App');
      Navigator.of(context).pop();
    }
  }

  // PopUp that the save did not work
  void showPopupManuelSaveError(BuildContext context, String message) {
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
              child: const Text('Nochmal Versuchen'),
            ),
          ],
        );
      },
    );
  }
}