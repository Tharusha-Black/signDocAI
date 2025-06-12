import 'package:flutter/material.dart';
import 'package:signature_detection_app/screens/auth/register_page.dart'; // Import the RegisterPage
import 'package:signature_detection_app/services/api_services.dart'; // Import the API service
import 'dart:ui' as ui;
import 'package:flutter/services.dart'; // Import for system UI overlay

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();

    // Adjust status bar style based on the current theme
    _updateStatusBar();

    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start animation on init
    _controller.forward();
  }

  // Method to update the status bar
  void _updateStatusBar() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;

    if (brightness == Brightness.light) {
      // Light mode: Ensure dark icons and transparent status bar
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // Transparent status bar
          statusBarIconBrightness: Brightness.dark, // Dark icons for light mode
        ),
      );
    } else {
      // Dark mode: Ensure light icons and dark status bar background
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // Transparent status bar
          statusBarIconBrightness:
              Brightness.light, // Light icons for dark mode
        ),
      );
    }
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final response = await ApiService.login(
      _emailController.text,
      _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (response != null && response['message'] == 'Login successful') {
      // Redirect to landing page on success
      Navigator.pushReplacementNamed(context, '/landing');
    } else {
      // Display error message
      setState(() {
        _errorMessage = response?['error'] ?? 'An error occurred';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // Transparent app bar
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Column(
                  mainAxisSize:
                      MainAxisSize
                          .min, // Ensures the Column takes minimum space
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .center, // Center the content horizontally
                  children: [
                    Text(
                      'Sign Language', // First line
                      style: TextStyle(
                        fontSize:
                            theme.brightness == Brightness.dark
                                ? 50
                                : 50, // Slightly smaller than full title for clarity
                        fontWeight: FontWeight.bold,
                        color:
                            theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                    Text(
                      'Detector', // Second line
                      style: TextStyle(
                        fontSize:
                            theme.brightness == Brightness.dark
                                ? 50
                                : 50, // Same size as 'Signature'
                        fontWeight: FontWeight.bold,
                        color:
                            theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 60),

                // Glass effect login box
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _animation,
                      child: Container(
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color:
                              theme.brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.blueGrey.withOpacity(
                                    0.15,
                                  ), // More subtle in light mode
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: 10.0,
                              sigmaY: 10.0,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(16.0),
                              color:
                                  theme.brightness == Brightness.dark
                                      ? Colors.black.withOpacity(0.1)
                                      : Colors.white.withOpacity(
                                        0.5,
                                      ), // Slight dark overlay for glass effect
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      labelStyle: TextStyle(
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                      ),
                                    ),
                                    style: TextStyle(
                                      color:
                                          theme.brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: TextStyle(
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                      ),
                                    ),
                                    style: TextStyle(
                                      color:
                                          theme.brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.brightness == Brightness.dark
                                              ? Colors.blueAccent
                                              : Colors
                                                  .blueGrey, // Adjust button color based on theme
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child:
                                        _isLoading
                                            ? CircularProgressIndicator()
                                            : Text(
                                              'Login',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                  ),
                                  if (_errorMessage.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 16.0),
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RegisterPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Don't have an account? Sign Up",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.blue
                                                : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor:
          theme.brightness == Brightness.dark
              ? Colors.blueGrey[900]
              : const Color.fromARGB(
                255,
                202,
                202,
                202,
              ), // Lighter background for light mode
    );
  }
}
