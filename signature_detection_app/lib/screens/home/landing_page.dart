import 'package:flutter/material.dart';
import 'package:signature_detection_app/screens/home/main_page.dart';

class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.brightness == Brightness.dark
              ? Colors.blueGrey[900]
              : const Color.fromARGB(255, 202, 202, 202),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Welcome to Sign Language Detection!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'This app will help you identify and validate Sign Language.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  backgroundColor:
                      theme.brightness == Brightness.dark
                          ? Colors.blueAccent
                          : Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Start', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
