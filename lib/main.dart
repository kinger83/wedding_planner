import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:wedding_app/firebase_options.dart';
import 'package:wedding_app/screens/login_screen.dart';
import 'package:wedding_app/screens/rsvp_dashboard.dart';
import 'package:wedding_app/screens/guest_rsvp_page.dart';

void main() async {
  // Ensure Flutter bindings are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use path URL strategy for clean URLs
  setUrlStrategy(PathUrlStrategy());
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Start the app
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wedding App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Colors.green[200],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green[200] ?? Colors.green,
          primary: Colors.green[200] ?? Colors.green,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/dashboard': (context) => RSVPDashboard(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes for RSVP links
        if (settings.name != null && settings.name!.startsWith('/rsvp/')) {
          final rsvpId = settings.name!.substring(6); // Remove '/rsvp/'
          return MaterialPageRoute(
            builder: (context) => GuestRSVPPage(rsvpId: rsvpId),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}