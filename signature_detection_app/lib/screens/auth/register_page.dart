import 'package:flutter/material.dart';
import 'package:signature_detection_app/services/api_services.dart'; // Import the API service
import 'dart:ui' as ui;
import 'package:flutter/services.dart'; // Import for system UI overlay

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    print("RegisterPage initialized");

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

  void _registerUser() async {
    // Validate form
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      print("awaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final userData = {
      "name": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": "user", // Hardcoded role
    };

    print("Sending registration request with data: $userData");

    try {
      final response = await ApiService.createUser(userData); // API call

      setState(() {
        _isLoading = false;
      });

      if (response != null) {
        print("Response from backend: $response");
        if (response['message'] == 'User created') {
          Navigator.pushReplacementNamed(
            context,
            '/login',
          ); // Navigate to login
        } else {
          setState(() {
            _errorMessage =
                response['error'] ?? 'Registration failed. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No response from server.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
      print("Error occurred: $e");
    }
  }

  String? _emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    const emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';
    final emailRegExp = RegExp(emailPattern);
    if (!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Updated code with Form widget wrapping the fields
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
                SizedBox(height: 40),
                // Glass effect register box
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
                                  : Colors.blueGrey.withOpacity(0.15),
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
                                      : Colors.white.withOpacity(0.5),
                              child: Form(
                                // Wrap form fields inside the Form widget
                                key: _formKey, // Use the form key here
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: InputDecoration(
                                        labelText: 'Name',
                                      ),
                                      validator:
                                          (value) =>
                                              value!.isEmpty
                                                  ? 'Name is required'
                                                  : null,
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _emailValidator,
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                      ),
                                      validator: _passwordValidator,
                                    ),
                                    SizedBox(height: 20),
                                    _isLoading
                                        ? CircularProgressIndicator()
                                        : ElevatedButton(
                                          onPressed: () {
                                            print("Register button pressed");
                                            _registerUser();
                                          },
                                          child: Text('Register'),
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
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/login',
                                        );
                                      },
                                      child: Text(
                                        "Already have an account? Login",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color:
                                              theme.brightness ==
                                                      Brightness.dark
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
