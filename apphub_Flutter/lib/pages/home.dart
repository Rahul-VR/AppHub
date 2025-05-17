import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login.dart';
import 'HomeScreen.dart'; 
import 'hostscreen.dart';
import 'searchscreen.dart';

class HomePage extends StatefulWidget {
  final String email;
  final String userType; // Added userType to handle student/faculty logic

  HomePage({required this.email, required this.userType});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String username = "Loading...";
  List<dynamic> uploadedApps = [];
  bool _isDropdownOpen = false;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    fetchProfile();
    fetchUserApps();

    _pages = [
      HomeScreen(email: widget.email),
      SearchScreen(email: widget.email),
      if (widget.userType == 'student') HostScreen(email: widget.email), // Host screen only for faculty
    ];
  }

  Future<void> fetchProfile() async {
    final url = Uri.parse('http://192.168.243.11:5000/profile');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": widget.email}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          username = data['username'];
        });
      }
    }
  }

  Future<void> fetchUserApps() async {
    final url = Uri.parse('http://192.168.243.11:5000/user_apps');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": widget.email}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          uploadedApps = data['apps'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/app_icon.png',
              height: 30,
            ),
            const SizedBox(width: 10),
            const Text('App Hub'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
      endDrawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(username.toUpperCase()),
              accountEmail: Text(widget.email),
              decoration: BoxDecoration(color: Colors.green),
            ),
            if (uploadedApps.isNotEmpty)
              ExpansionTile(
                leading: Icon(Icons.history),
                title: Text("Upload History"),
                initiallyExpanded: _isDropdownOpen,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isDropdownOpen = expanded;
                  });
                },
                children: uploadedApps.map((app) {
                  return ListTile(
                    title: Text(app['app_name']),
                    subtitle: Text("${app['description']}"),
                    trailing: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  );
                }).toList(),
              )
            else
              ListTile(
                leading: Icon(Icons.history),
                title: Text("No uploaded apps"),
              ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => AuthPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Colors.green,
        items: [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.search, title: 'Search'),
          if (widget.userType == 'student')
            TabItem(icon: Icons.cloud_upload, title: 'Host'), // Host only for student
        ],
        initialActiveIndex: _currentIndex,
        onTap: (int i) {
          setState(() {
      if (i < _pages.length) {
        _currentIndex = i; // Update the current page
      }
    });
        },
      ),
    );
  }
}




