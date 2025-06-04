import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:wedding_app/screens/login_screen.dart';
import 'package:wedding_app/screens/rsvp_dashboard.dart';
import 'package:wedding_app/screens/guest_rsvp_page.dart';
import 'package:wedding_app/screens/photo_gallery_page.dart';

String? initialRSVPId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final path = Uri.base.path;
  if (path.contains('rsvp/')) {
    initialRSVPId = path.split('rsvp/').last;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wedding RSVP App',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final user = FirebaseAuth.instance.currentUser;
        final name = settings.name ?? '/';
        print('Generating route for: $name');

        if (initialRSVPId != null) {
          FirebaseAuth.instance.signOut();
          return MaterialPageRoute(
            builder: (_) => GuestRSVPPage(rsvpId: initialRSVPId!),
            maintainState: false,
          );
        }

        if (name == '/dashboard') {
          if (user == null) {
            return MaterialPageRoute(builder: (_) => LoginScreen());
          }
          return MaterialPageRoute(builder: (_) => RSVPDashboard());
        }

        if (user != null) {
          return MaterialPageRoute(
            builder: (_) => RSVPDashboard(),
            settings: RouteSettings(name: '/dashboard'),
          );
        }

        return MaterialPageRoute(builder: (_) => LoginScreen());
      },
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'firebase_options.dart';
// import 'package:wedding_app/screens/login_screen.dart';
// import 'package:wedding_app/screens/rsvp_dashboard.dart';
// import 'package:wedding_app/screens/guest_rsvp_page.dart';
// import 'package:wedding_app/screens/photo_gallery_page.dart';

// String? initialRSVPId;

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   final path = Uri.base.path;
//   if (path.contains('rsvp/')) {
//     initialRSVPId = path.split('rsvp/').last;
//   }

//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Wedding RSVP App',
//       navigatorKey: _navigatorKey,
//       theme: ThemeData(
//         primarySwatch: Colors.green,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       initialRoute: '/',
//       onGenerateRoute: (settings) {
//         final user = FirebaseAuth.instance.currentUser;
//         final name = settings.name ?? '/';
//         print('Generating route for: $name');

//         if (initialRSVPId != null) {
//           FirebaseAuth.instance.signOut();
//           return MaterialPageRoute(
//             builder: (_) => GuestRSVPPage(rsvpId: initialRSVPId!),
//             maintainState: false,
//           );
//         }

//         if (name == '/dashboard') {
//           if (user == null) {
//             return MaterialPageRoute(builder: (_) => LoginScreen());
//           }
//           return MaterialPageRoute(builder: (_) => RSVPDashboard());
//         }

//         if (user != null) {
//           return MaterialPageRoute(
//             builder: (_) => RSVPDashboard(),
//             settings: RouteSettings(name: '/dashboard'),
//           );
//         }

//         return MaterialPageRoute(builder: (_) => LoginScreen());
//       },
//     );
//   }
// }
