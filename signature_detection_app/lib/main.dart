import 'package:flutter/material.dart';
import 'package:signature_detection_app/screens/auth/login_page.dart';
import 'package:signature_detection_app/screens/auth/register_page.dart';
import 'package:signature_detection_app/screens/home/main_page.dart';
import 'package:signature_detection_app/screens/profile/profile_page.dart';
import 'package:signature_detection_app/screens/home/landing_page.dart';
import 'package:signature_detection_app/core/theme/app_theme.dart'; // your custom theme

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building MyApp');
    return MaterialApp(
      title: 'Signature Detection',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,

      // Set initial route
      initialRoute: '/login', // Check if this is correctly set
      onGenerateRoute: (settings) {
        print('Navigating to ${settings.name}');
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => LoginPage());
          case '/register':
            return MaterialPageRoute(builder: (context) => RegisterPage());
          case '/landing':
            return MaterialPageRoute(builder: (context) => LandingPage());
          case '/main':
            return MaterialPageRoute(builder: (context) => MainPage());
          case '/profile':
            return MaterialPageRoute(builder: (context) => ProfilePage());
          default:
            return MaterialPageRoute(
              builder: (context) => LoginPage(),
            ); // Fallback route
        }
      },
    );
  }
}
