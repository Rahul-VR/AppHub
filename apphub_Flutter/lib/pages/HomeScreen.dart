import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String email;

  HomeScreen({required this.email});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> apps = [];

  @override
  void initState() {
    super.initState();
    fetchApps();
  }

  Future<void> fetchApps() async {
    final url = Uri.parse('http://192.168.243.11:5000/all_apps_with_ratings');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            apps = data['apps'];
          });
        }
      }
    } catch (e) {
      print("Error fetching apps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: apps.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(app['icon_url']),
                    ),
                    title: Text(app['app_name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Description: ${app['description']}"),
                        Text("Rating: ${double.tryParse(app['average_rating'].toString())?.toStringAsFixed(1) ?? 'N/A'} ⭐"),
                        Text("Size: ${app['apk_size'] ?? '0.0'} MB"),
                      ],
                    ),
                    trailing: Icon(Icons.check_circle, color: Colors.green),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppDetailScreen(app: app),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
