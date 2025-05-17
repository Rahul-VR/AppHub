import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class HostScreen extends StatefulWidget {
  final String email;

  HostScreen({required this.email});

  @override
  _HostScreenState createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController _appNameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _featuresController = TextEditingController();
  TextEditingController _categoryController = TextEditingController();
  TextEditingController _newFeaturesController = TextEditingController();

  bool _isUpdate = false;
  List<String> _existingApps = [];
  String? _selectedApp;

  File? _screenshot1;
  File? _screenshot2;
  File? _certificate;
  File? _apkFile;
  File? _icon;

  @override
  void initState() {
    super.initState();
    fetchUserApps();
  }

  Future<void> fetchUserApps() async {
    final url = Uri.parse('http://192.168.243.11:5000/user_apps');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] && data['apps'] is List && data['apps'].isNotEmpty) {
          setState(() {
            _existingApps = List<String>.from(data['apps'].map((app) => app['app_name']));
          });
        } else {
          setState(() {
            _existingApps = [];
          });
          print("No apps found or invalid data format.");
        }
      }
    } catch (e) {
      print("Error fetching apps: $e");
    }
  }
  Future<void> _pickFile(String fileType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: fileType == "certificate" ? ["pdf"] : ["jpg", "png"],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        if (fileType == "screenshot1") _screenshot1 = File(result.files.first.path!);
        if (fileType == "screenshot2") _screenshot2 = File(result.files.first.path!);
        if (fileType == "certificate") _certificate = File(result.files.first.path!);
        if (fileType == "icon") _icon = File(result.files.first.path!);
      });
    }
  }

  Future<void> _pickApkFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _apkFile = File(result.files.first.path!);
      });
    }
  }

  Future<void> _uploadApp() async {
    if (_formKey.currentState!.validate()) {
      if (_isUpdate && (_selectedApp == null || !_existingApps.contains(_selectedApp))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select a valid existing app!")),
        );
        return;
      }

      var request = http.MultipartRequest('POST', Uri.parse('http://192.168.243.11:5000/upload_app'));

      request.fields['email'] = widget.email;
      request.fields['app_name'] = _appNameController.text;
      request.fields['category'] = _categoryController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['features'] = _featuresController.text;
      request.fields['is_update'] = _isUpdate.toString();

      if (_isUpdate) {
        request.fields['existing_app'] = _selectedApp!;
        request.fields['new_features'] = _newFeaturesController.text;
      }

      if (_screenshot1 != null) {
        request.files.add(await http.MultipartFile.fromPath('screenshot1', _screenshot1!.path));
      }
      if (_screenshot2 != null) {
        request.files.add(await http.MultipartFile.fromPath('screenshot2', _screenshot2!.path));
      }
      if (_certificate != null) {
        request.files.add(await http.MultipartFile.fromPath('certificate', _certificate!.path));
      }
      if (_apkFile != null) {
        request.files.add(await http.MultipartFile.fromPath('apk_file', _apkFile!.path));
      }
      if (_apkFile != null) {
        request.files.add(await http.MultipartFile.fromPath('icon', _icon!.path));
      }

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Successful!")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed!")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Host Your App"), backgroundColor: Colors.green),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _appNameController,
                decoration: InputDecoration(labelText: "App Name"),
                validator: (value) => value!.isEmpty ? "Enter App Name" : null,
              ),
              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                decoration: InputDecoration(labelText: "Category"),
                items: ['Music', 'Game', 'Entertainment', 'Education', 'Other']
                  .map((category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
              ))
                  .toList(),
                onChanged: (value) {
                  _categoryController.text = value!;
                },
                validator: (value) =>
                  value == null || value.isEmpty ? "Select a Category" : null,
              ),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: "Description"),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? "Enter Description" : null,
              ),
              SwitchListTile(
                title: Text("Is this an update?"),
                value: _isUpdate,
                onChanged: (value) {
                  setState(() {
                    _isUpdate = value;
                    if (!_isUpdate) _selectedApp = null;
                  });
                },
              ),
              if (_isUpdate)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: "Select Existing App"),
                      items: _existingApps.map((app) {
                        return DropdownMenuItem(value: app, child: Text(app));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedApp = value;
                        });
                      },
                      validator: (value) => value == null ? "Select an App" : null,
                    ),
                    TextFormField(
                      controller: _newFeaturesController,
                      decoration: InputDecoration(labelText: "New Features"),
                      maxLines: 3,
                      validator: (value) => _isUpdate && value!.isEmpty ? "Enter New Features" : null,
                    ),
                  ],
                ),
              if (!_isUpdate)
                TextFormField(
                  controller: _featuresController,
                  decoration: InputDecoration(labelText: "Features"),
                  maxLines: 3,
                  validator: (value) => !_isUpdate || value!.isNotEmpty ? null : "Enter Features",
                ),
              SizedBox(height: 10),
              Text("Upload Screenshots"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: () => _pickFile("screenshot1"), child: Text("Screenshot 1")),
                  ElevatedButton(onPressed: () => _pickFile("screenshot2"), child: Text("Screenshot 2")),
                  ElevatedButton(onPressed: () => _pickFile("icon"), child: Text("App Icon")),
                ],
              ),
              SizedBox(height: 10),
              ElevatedButton(onPressed: () => _pickFile("certificate"), child: Text("Upload Certificate")),
              SizedBox(height: 10),
              ElevatedButton(onPressed: _pickApkFile, child: Text("Upload APK")),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadApp,
                child: Text("Submit"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
