import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'settings_screen.dart';
import 'settings_provider.dart';
import 'notifications.dart';q
import 'scanner_function.dart';
import 'firebase_options.dart';
import 'foodinfo_manuel.dart';

// Define ThemeData instances for Light and Dark Modes
final lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.teal,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: Colors.amber, // Accent color for the light theme
  ),
  appBarTheme: const AppBarTheme(
    color: Colors.teal, // Color of the AppBar in the light mode
    elevation: 4.0, // Shadow beneath the AppBar
  ),
  fontFamily: 'Montserrat', // Custom font
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.deepPurple,
  colorScheme: ColorScheme.fromSwatch(
    brightness: Brightness.dark,
  ).copyWith(
    secondary: Colors.lime,
  ),
  appBarTheme: const AppBarTheme(
    color: Colors.black, // Color of the AppBar in the dark mode
    elevation: 4.0, // Shadow beneath the AppBar
  ),
  fontFamily: 'Roboto', // Custom font
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _configureLocalTimeZone();

  UserProvider userProvider = UserProvider();
  await userProvider.checkLoginStatus();

  RequestPermission requestPermission = RequestPermission();
  await requestPermission.initializePermission();

  DailyNotifications dailyNotifications = DailyNotifications();
  await dailyNotifications.updateDailyNotification();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Configures the local timezone for the application
Future<void> _configureLocalTimeZone() async {
  // Initializes timezone information
  tz.initializeTimeZones();
  // Retrieves the name of the local timezone from Flutter
  final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
  // Sets the local timezone based on the obtained name
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
}

// MyApp is a StatelessWidget that defines the main structure of the Flutter application
class MyApp extends StatelessWidget {

  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return MaterialApp(
      theme: settingsProvider.darkModeEnabled ? darkTheme : lightTheme,
      home: const HomeScreen(),
      initialRoute: '/',
      routes: {
        '/settings': (context) => SettingsScreen(),
        '/profile': (context) => ProfileScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = ''; // Variable for search query

// The build method creates the UI for the HomeScreen view
  @override
  Widget build(BuildContext context) {
    Provider.of<UserProvider>(context, listen: false).checkLoginStatus(); // Checks login status when the view is loaded
    final settingsProvider = Provider.of<SettingsProvider>(context); // Accesses the SettingsProvider object using Provider.of

    // Returns the entire view with Scaffold and various widgets
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 110), // Increased spacing for TopBar
            child: Body(searchQuery: searchQuery),
          ),
          Positioned(
            top: 0, // TopBar at the top
            left: 0,
            right: 0,
            child: Container(
              height: 50, // Height of the TopBar
              color: Theme.of(context).primaryColor, // Main color of the theme
            ),
          ),
          Positioned(
            top: 66, // Positioned below the TopBar
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(34.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      borderRadius: BorderRadius.circular(30.0),
                      elevation: 4.0,
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Suchen...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search, color: Colors.black),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 24, color: Colors.white,),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/settings');
                    },
                  ),
                ],
              ),
            ),
          ),
          // Add button bottom right
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                showManualEntryPopup(context);
              },
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, size: 24, color: Colors.white),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Footer(),
    );
  }
}

class Body extends StatelessWidget {
  final double maxDays = 7.0;
  final String searchQuery; // Parameter for the search query

  Body({required this.searchQuery}); // Constructor for the search query

  @override
  Widget build(BuildContext context) {
    // Get the current user ID or email
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Container(
      height: 800,
      child: StreamBuilder(
        // Filter documents in the 'food_items' collection based on user ID or email
        stream: FirebaseFirestore.instance
            .collection('food_items')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          // Check connection state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Check if the snapshot has data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // No documents found
            return Center(
              child: Text(
                  Provider.of<UserProvider>(context).isLoggedIn
                      ? "Sie haben noch keine Produkte hinzugefügt."
                      : "Bitte melden Sie sich erst an, um Ihre Produkte anzuzeigen."
              ),
            );
          }

          var foodItemsList = snapshot.data!.docs;

          // Filter the food items list based on the search query
          var filteredFoodItems = foodItemsList.where((foodItem) {
            final productName = foodItem['product_name']?.toLowerCase() ?? '';
            return productName.contains(searchQuery);
          }).toList();

          return GridView.builder(
            key: UniqueKey(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 12.0,
            ),
            itemCount: filteredFoodItems.length, // Use the filtered list
            itemBuilder: (context, index) {
              var foodItem = filteredFoodItems[index];
              return FoodItemCard(foodItem, maxDays);
            },
          );
        },
      ),
    );
  }
}

class FoodItemCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> foodItem;
  final double maxDays;

  FoodItemCard(this.foodItem, this.maxDays);

  @override
  Widget build(BuildContext context) {
    // Extract relevant information from the foodItem
    final url = foodItem['image_url'];
    final expirationDateStr = foodItem['expiration_date'];
    final brandName = foodItem['brand_name'];
    final cal_1 = foodItem['cal'];
    final ingredients_1 = foodItem['ingredients'];
    final productName = foodItem['product_name'];
    final quantity_1 = foodItem['quantity'];
    final nutriscore = foodItem['nutriscore'];

    // Convert expirationDateStr to a DateTime object
    final expirationDate = expirationDateStr != null ? DateTime.parse(expirationDateStr) : null;

    // Calculate the remaining days until the expiration date
    final remainingDays = expirationDate != null ? expirationDate.difference(DateTime.now()).inDays : 0;

    // Calculate progress for the linear progress bar
    final double progress = remainingDays >= 0 ? remainingDays / maxDays : 0.0;

    // Set the progress bar color based on the progress
    Color progressColor;
    if (remainingDays >= 0) {
      if (progress <= 0.2) {
        progressColor = Colors.red;
      } else if (progress <= 0.5) {
        progressColor = Colors.yellow;
      } else {
        progressColor = Colors.green;
      }
    } else {
      // If the expiration date is negative, set progress to 0 and color to red
      progressColor = Colors.red;
    }

    return InkWell(
      onTap: () {
        // Show a popup with detailed information about the food item
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.white70, // Set background color to light blue
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    // Show various information about the food item
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.local_fire_department),
                            Text('$cal_1 kcal'),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.line_weight),
                            Text('$quantity_1'),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.assessment),
                            Text(nutriscore ?? 'N/A'), // Display Nutriscore or 'N/A' if not available
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    // Show linear progress bar based on remaining shelf life
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                    const SizedBox(height: 8.0),
                    // Show remaining days and adjust color accordingly
                    Text(
                      'Verbleibende Haltbarkeit: \n$remainingDays Tag(e)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: remainingDays >= 0
                            ? Theme.of(context).textTheme.bodyText1?.color ?? Colors.black
                            : Colors.red,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      // Delete the food item on long press
      onLongPress: () => _showDeleteDialog(context, foodItem.id),
      // Generate the card view
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        elevation: 5.0,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Center(
                child: Text(
                    '$productName'
                ),
              ),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
              Text(
                remainingDays >= 0
                    ? 'Verbleibende Haltbarkeit: \n$remainingDays Tag(e)'
                    : 'Produkt ist abgelaufen: \n${remainingDays.abs()} Tag(e) ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: remainingDays >= 0
                      ?  Theme.of(context).textTheme.bodyText1?.color ?? Colors.black
                      : Colors.red,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Show a dialog for confirming the deletion of a food item
  void _showDeleteDialog(BuildContext context, String foodItemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Produkt löschen'),
          content: const Text('Möchten Sie dieses Produkt wirklich löschen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ), // End of TextButton (Cancel)
            TextButton(
              child: const Text('Löschen'),
              onPressed: () {
                _deleteFoodItem(foodItemId);
                Navigator.of(context).pop(); // Close the dialog and delete the product
              },
            ), // End of TextButton (Delete)
          ],
        ); // End of AlertDialog
      },
    ); // End of showDialog
  }

  Future<void> _deleteFoodItem(String foodItemId) async {
    try {
      await FirebaseFirestore.instance.collection('food_items').doc(foodItemId).delete();
    } catch (e) {
      print("Fehler beim Löschen des Produkts: $e");
    }
  } // End of _deleteFoodItem
}

class Footer extends StatelessWidget {
  final FoodInfoService foodInfoService = FoodInfoService();

  @override
  Widget build(BuildContext context) {
    // Check the login status when building the widget
    Provider.of<UserProvider>(context, listen: false).checkLoginStatus();

    // Get the current route name
    String currentRoute = ModalRoute.of(context)!.settings.name ?? '';

    // Determine the current index based on the route and login status
    int currentIndex = 0; // Default to home

    if (currentRoute == '/') {
      currentIndex = 0; // Home
    } else if (currentRoute == '/profile') {
      currentIndex = 2; // Profile
    }

    return BottomNavigationBar(
      backgroundColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.white70,
      selectedItemColor: Theme.of(context).colorScheme.secondary,
      currentIndex: currentIndex,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Startseite',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt_outlined),
          label: 'Scannen',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
            break;
          case 1:
            if (Provider.of<UserProvider>(context, listen: false).isLoggedIn) {
              foodInfoService.scanAndSaveToFirestore(context);
            } else {
              foodInfoService.logInToScan(context);
            }
            break;
          case 2:
            Navigator.of(context).pushNamed('/profile');
            break;
        }
      },
    );
  }
}

// UserProfile is a simple class representing user profile information
class UserProfile {
  static String name = '';
  static String surname = '';
  static String email = '';
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Check the login status when building the widget
    checkLoginStatus(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        automaticallyImplyLeading: false, // Prevents the back arrow from being displayed
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${UserProfile.name}'),
            Text('Vorname: ${UserProfile.surname}'),
            Text('E-Mail: ${UserProfile.email}'),
          ],
        ),
      ),
      bottomNavigationBar: Footer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _signOut(context);
        },
        child: const Icon(Icons.exit_to_app),
      ),
    );
  }
// Function to check the login status and navigate to the login page if the user is not logged in
  void checkLoginStatus(BuildContext context) async {
    bool isLoggedIn = await LocalStorage.isLoggedIn;

    if (!isLoggedIn) {
      // User is not logged in, navigate back to the login page
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
// Function to sign out the user and navigate to the login page
  void _signOut(BuildContext context) async {
    try {
      // Sign out from Firebase authentication
      await FirebaseAuth.instance.signOut();

      // Navigate to the login page after logout
      Navigator.of(context).pushReplacementNamed('/login');
      await UserPreferences.setLoggedIn(false);
    } catch (e) {
      print('Fehler beim Abmelden: $e');
    }

    // Set the login status to false in local storage
    await LocalStorage.setLoggedIn(false);

    // Navigate back to the login page
    Navigator.of(context).pushReplacementNamed('/login');
  }
}

// UserPreferences is a class responsible for managing user preferences using SharedPreferences
class UserPreferences {
  static const String isLoggedInKey = 'isLoggedIn';
  // Get the login status from SharedPreferences
  static Future<bool> get isLoggedIn async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isLoggedInKey) ?? false;
  }
  // Set the login status in SharedPreferences
  static Future<void> setLoggedIn(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isLoggedInKey, value);
  }
}
// LocalStorage is a class similar to UserPreferences, used for managing local storage of user preferences
class LocalStorage {
  static const String isLoggedInKey = 'isLoggedIn';
  // Get the login status from local storage
  static Future<bool> get isLoggedIn async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(isLoggedInKey) ?? false;
  }
  // Set the login status in local storage
  static Future<void> setLoggedIn(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(isLoggedInKey, value);
  }
}
// UserProvider is a ChangeNotifier class handling the user's login status and notifying listeners
class UserProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  // Getter for the login status
  bool get isLoggedIn => _isLoggedIn;
  // Check the login status and notify listeners
  Future<void> checkLoginStatus() async {
    _isLoggedIn = await UserPreferences.isLoggedIn;
    notifyListeners();
  }
  // Set the login status to true and notify listeners
  void login() async {
    _isLoggedIn = true;
    notifyListeners();
    await UserPreferences.setLoggedIn(true);
  }
  // Logout the user by signing out from Firebase authentication and updating the login status
  void logout() async {
    try {
      // Sign out from Firebase authentication
      await FirebaseAuth.instance.signOut();

      // Set the local login status to false and notify listeners
      _isLoggedIn = false;
      notifyListeners();
      // Set the login status to false in local storage
      await UserPreferences.setLoggedIn(false);
    } catch (e) {
      print('Fehler beim Abmelden: $e');
    }
  }
}

class LoginScreen extends StatelessWidget {
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  // Function to handle user login
  Future<void> loginUser(BuildContext context) async {
    try {
      // Check if email and password are provided
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw 'Bitte geben Sie E-Mail und Passwort ein.';
      }
      // Sign in user with provided email and password
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Load user data from the database and store it
      await loadUserData();

      // Set login status to true in local storage
      await LocalStorage.setLoggedIn(true);

      // Navigate user to the profile page
      Navigator.of(context).pushNamed('/profile');
    } catch (e) {
      print("Fehler bei der Benutzeranmeldung: $e");
      // Display error message
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Fehler'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
    // Print the current user's UID
    if (FirebaseAuth.instance.currentUser != null) {
      print("Angemeldeter Benutzer: ${FirebaseAuth.instance.currentUser!.uid}");
    } else {
      print("Kein Benutzer angemeldet");
    }
  }
  // Function to load user data from Firestore
  Future<void> loadUserData() async {
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        // Unique user ID (uid) of the logged-in user
        String userId = FirebaseAuth.instance.currentUser!.uid;

        // Get user data from Firestore database
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('User')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          // Save data in the UserProfile class
          final userData = userDoc.data() as Map<String, dynamic>;
          UserProfile.name = userData['name'] ?? '';
          UserProfile.surname = userData['surname'] ?? '';
          UserProfile.email = userData['email'] ?? '';
        }
      } catch (e) {
        print("Fehler beim Laden der Benutzerdaten: $e");
      }
    } else {
      print("Kein Benutzer angemeldet");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Passwort',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Call the method for user login
                loginUser(context);
              },
              style: ElevatedButton.styleFrom(
                primary: Theme.of(context).colorScheme.secondary,
              ),
              child: const Text('Anmelden'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/register'); // Zum Registrieren navigieren
              },
              style: TextButton.styleFrom(
                primary: Theme.of(context).colorScheme.secondary,
              ),
              child: const Text('Registrieren'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Footer(),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _surnameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();
  // Function to handle user registration
  Future<void> registerUser(BuildContext context) async {
    try {
      // Check if all fields are filled
      if (_nameController.text.isEmpty ||
          _surnameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        throw 'Bitte füllen Sie alle Felder aus.';
      }

      // Check if the email has the typical email format
      if (!RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(_emailController.text)) {
        throw 'Bitte geben Sie eine gültige E-Mail-Adresse ein.';
      }

      // Check if the email address is already in use in the database
      if (await isEmailInUse(_emailController.text)) {
        throw 'Die E-Mail-Adresse wird bereits verwendet.';
      }

      // Check password confirmation
      if (_passwordController.text != _confirmPasswordController.text) {
        throw 'Passwörter stimmen nicht überein';
      }

      // Check if the password meets the required criteria
      if (!isStrongPassword(_passwordController.text)) {
        throw 'Das Passwort muss mindestens 6 Zeichen lang sein und mindestens 1 Großbuchstaben, 1 Kleinbuchstaben, 1 Zahl und 1 Sonderzeichen enthalten.';
      }

      // Firebase authentication: Create user with email and password
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
          // Benutzerdaten in Firestore speichern
          'name': _nameController.text,
          'surname': _surnameController.text,
          'email': _emailController.text,
        });
      }

      print('Benutzer erfolgreich registriert.');

      // Navigate to the profile page
      Navigator.of(context).pushReplacementNamed('/profile');
    } catch (e) {
      print("Fehler bei der Benutzerregistrierung: $e");
      // Display error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fehler bei der Registrierung: $e'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // Check if the email address is already in use in the database
  Future<bool> isEmailInUse(String email) async {
    QuerySnapshot query = await FirebaseFirestore.instance.collection('User').where('email', isEqualTo: email).get();
    return query.docs.isNotEmpty;
  }
  // Note: This function is redundant since it is covered by the authentication function, but it doesn't harm either.

  // Check if the password meets the required criteria
  bool isStrongPassword(String password) {

    return password.length >= 6 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrieren'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildTextField(_nameController, 'Name'),
              const SizedBox(height: 20),
              buildTextField(_surnameController, 'Vorname'),
              const SizedBox(height: 20),
              buildTextField(_emailController, 'E-Mail', TextInputType.emailAddress),
              const SizedBox(height: 20),
              buildTextField(_passwordController, 'Passwort', TextInputType.visiblePassword, true),
              const SizedBox(height: 20),
              buildTextField(_confirmPasswordController, 'Passwort bestätigen', TextInputType.visiblePassword, true),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Call the method for user registration
                  registerUser(context);
                },
                style: ElevatedButton.styleFrom(
                  primary: Theme.of(context).colorScheme.secondary,
                ),
                child: const Text('Registrieren'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Footer(),
    );
  }

  // Build a text field with specified parameters
  Widget buildTextField(TextEditingController controller, String labelText,
      [TextInputType inputType = TextInputType.text, bool isPassword = false]) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: inputType,
      obscureText: isPassword,
    );
  }
}
