import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Profile')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('User Name: John Doe', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            Text('Email: johndoe@example.com'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, child: Text('Edit Profile')),
            ElevatedButton(onPressed: () {}, child: Text('Logout')),
          ],
        ),
      ),
    );
  }
}
