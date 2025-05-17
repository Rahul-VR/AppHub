import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'app_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String email;

  const SearchScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recommendedApps = [];
  bool _isLoading = false;
  int? userId;
  String? recommendedCategory;

  @override
  void initState() {
    super.initState();
    fetchUserId();
  }

  // Fetch user ID based on email
  Future<void> fetchUserId() async {
    try {
      final response = await Dio().get(
        'http://192.168.243.11:5000/get_user_id',
        queryParameters: {'email': widget.email},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          userId = data['user_id'];
        });

        // After getting the userId, fetch the category from search history
        if (userId != null) {
          fetchCategoryFromHistory();
        }
      }
    } catch (e) {
      print('Failed to fetch user ID: $e');
    }
  }

  // Fetch category from search history (if available)
  Future<void> fetchCategoryFromHistory() async {
    if (userId == null) return;

    try {
      final response = await Dio().get(
        'http://192.168.243.11:5000/get_category_from_history',
        queryParameters: {'user_id': userId.toString()},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          recommendedCategory = data['category'];
        });

        // If there's a category, fetch apps with that category
        if (recommendedCategory != null) {
          fetchAppsByCategory(recommendedCategory!);
        }
      }
    } catch (e) {
      print('Failed to fetch category from history: $e');
    }
  }

  // Fetch apps based on the category
  Future<void> fetchAppsByCategory(String category) async {
    try {
      final response = await Dio().get(
        'http://192.168.243.11:5000/get_apps_by_category',
        queryParameters: {'category': category},
      );

      if (response.statusCode == 200) {
        setState(() {
          _recommendedApps = List<Map<String, dynamic>>.from(response.data['apps'] ?? []);
        });
      }
    } catch (e) {
      print('Failed to fetch apps by category: $e');
    }
  }

  // Perform search based on the query entered
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || userId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await Dio().get(
        'http://192.168.243.11:5000/search_apps',
        queryParameters: {
          'query': query,
          'user_id': userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response.data['apps'] ?? []);
        });
      } else {
        print('Search failed');
      }
    } catch (e) {
      print('Error during search: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Apps')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by app name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _performSearch,
                  icon: Icon(Icons.search),
                  label: Text('Search'),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Show loading indicator or results for search
            _isLoading
                ? CircularProgressIndicator()
                : _searchResults.isEmpty
                    ? Text('No results found')
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final app = _searchResults[index];
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    app['icon_url'] ?? 'https://via.placeholder.com/40',
                                  ),
                                ),
                                title: Text(app['app_name'] ?? 'No Name'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Description: ${app['description'] ?? 'N/A'}"),
                                    Text(
                                      "Rating: ${double.tryParse(app['average_rating']?.toString() ?? '')?.toStringAsFixed(1) ?? 'N/A'} ⭐",
                                    ),
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
                      ),

            SizedBox(height: 16),

            // Recommended apps section
            if (_recommendedApps.isNotEmpty) ...[
              Text('Recommended Apps:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              SizedBox(
                height: 200, // Provide a fixed height for the recommended apps list
                child: ListView.builder(
                  itemCount: _recommendedApps.length,
                  itemBuilder: (context, index) {
                    final app = _recommendedApps[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(app['icon_url'] ?? 'https://via.placeholder.com/40'),
                        ),
                        title: Text(app['app_name'] ?? 'No Name'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Description: ${app['description'] ?? 'N/A'}"),
                            Text(
                              "Rating: ${double.tryParse(app['average_rating']?.toString() ?? '')?.toStringAsFixed(1) ?? 'N/A'} ⭐",
                            ),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
