import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'FullScreenImage.dart';
import 'apk_installer_screen.dart';

class AppDetailScreen extends StatefulWidget {
  final Map<String, dynamic> app;

  AppDetailScreen({required this.app});

  @override
  _AppDetailScreenState createState() => _AppDetailScreenState();
}

class Review {
  final String email;
  final int rating;
  final String review;
  final String createdAt;

  Review({
    required this.email,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      email: json['email'],
      rating: int.parse(json['rating'].toString()),
      review: json['review'] ?? '',
      createdAt: json['created_at'],
    );
  }
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  double _downloadProgress = 0;
  bool _isDownloading = false;
  bool _downloadCompleted = false;
  List<Review> _reviews = [];

  final TextEditingController _reviewController = TextEditingController();
  double _selectedRating = 5.0;

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  Future<void> fetchReviews() async {
    try {
      final response = await Dio().get(
        "http://192.168.243.11:5000/get_reviews",
        queryParameters: {'app_id': widget.app['id']},
      );

      final data = response.data;

      if (data is List) {
        setState(() {
          _reviews = data
              .map((item) => Review.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        });
      } else {
        print("Expected a list, but got: ${data.runtimeType}");
      }
    } catch (e) {
      print("Error fetching reviews: $e");
    }
  }

  Future<void> _submitReview() async {
    final reviewText = _reviewController.text.trim();
    if (reviewText.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Review cannot be empty")));
      return;
    }

    try {
      final response = await Dio().post(
        "http://192.168.243.11:5000/submit_review",
        data: {
          'app_id': widget.app['id'],
          'email': 'rahul@example.com',
          'rating': _selectedRating.round(),
          'review': reviewText,
        },
      );

      if (response.data['success']) {
        _reviewController.clear();
        setState(() {
          _selectedRating = 5;
        });
        fetchReviews();
      } else {
        throw Exception(response.data['error']);
      }
    } catch (e) {
      print("Error submitting review: $e");
    }
  }

  String formatName(String email) {
    final namePart = email.split('@')[0];
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  Future<void> _downloadApk(String apkFile) async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied ||
          await Permission.manageExternalStorage.isPermanentlyDenied) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Storage permission is required')),
          );
          return;
        }
      }
    }

    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
        _downloadCompleted = false;
      });

      final dio = Dio();
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);

      final filePath = '${downloadsDir.path}/$apkFile';
      final url = "http://192.168.243.11:5000/uploads/$apkFile";

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
        _downloadCompleted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download complete! Opening installer...')),
      );
       // Wait for snackbar to be shown
    await Future.delayed(Duration(seconds: 1));

    // Navigate to installation screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => ApkInstallerScreen(filePath: filePath),
    //   ),
    // );
      await OpenFile.open(filePath);
    } catch (e) {
      print("Download error: $e");
      setState(() {
        _isDownloading = false;
        _downloadCompleted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    return Scaffold(
      appBar: AppBar(title: Text(app['app_name'])),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(app['icon_url']),
              ),
            ),
            SizedBox(height: 16),
            Text(
              app['app_name'],
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text("Rating: ${app['average_rating'] ?? 'N/A'} ⭐",
                textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text("Size: ${app['apk_size'] ?? '0.0'} MB",
                textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _isDownloading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        value: _downloadProgress,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.download),
              label: Text(_isDownloading
                  ? "${(_downloadProgress * 100).toStringAsFixed(0)}%"
                  : _downloadCompleted
                      ? "Downloaded"
                      : "Download"),
              onPressed: _isDownloading
                  ? null
                  : () => _downloadApk(app['apk_file']),
              style: ElevatedButton.styleFrom(
                backgroundColor: _downloadCompleted ? Colors.green : null,
              ),
            ),
            SizedBox(height: 16),
            Text("Description",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(app['description'] ?? "No description available"),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (app['screenshot1'] != null &&
                        app['screenshot1'].toString().isNotEmpty)
                      
                      GestureDetector(
                    onTap: () {
                    Navigator.push(
                    context,
              MaterialPageRoute(
                builder: (context) => FullScreenImage(
                  imageUrl: "http://192.168.243.11:5000/uploads/${app['screenshot1']}",
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Image.network(
              "http://192.168.243.11:5000/uploads/${app['screenshot1']}",
              height: 280,
              width: 150,
              fit: BoxFit.cover,
            ),
          ),
        ),
                    if (app['screenshot2'] != null && app['screenshot2'].toString().isNotEmpty)
  GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(
            imageUrl: "http://192.168.243.11:5000/uploads/${app['screenshot2']}",
          ),
        ),
      );
    },
    child: Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Image.network(
        "http://192.168.243.11:5000/uploads/${app['screenshot2']}",
        height: 280,
        width: 150,
        fit: BoxFit.cover,
      ),
    ),
  ),

                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text("Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ..._reviews.map((review) {
              final name = formatName(review.email);
              return ListTile(
                leading: CircleAvatar(child: Text(name[0])),
                title: Text("$name ⭐ ${review.rating}"),
                subtitle: Text(review.review),
                trailing: Text(review.createdAt.split(' ')[0]),
              );
            }).toList(),
            Divider(),
            Text("Write a Review",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _reviewController,
              decoration: InputDecoration(
                labelText: "Your review",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 10),
            Text("Rating: ${_selectedRating.round()}", style: TextStyle(fontSize: 16)),
            Slider(
              value: _selectedRating,
              min: 1,
              max: 5,
              divisions: 4,
              label: _selectedRating.round().toString(),
              onChanged: (value) {
                setState(() {
                  _selectedRating = value;
                });
              },
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _submitReview,
              icon: Icon(Icons.send),
              label: Text("Submit Review"),
            )
          ],
        ),
      ),
    );
  }
}
