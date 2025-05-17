// import 'package:flutter/material.dart';
// import 'package:apk_installer/apk_installer.dart';

// class ApkInstallerScreen extends StatefulWidget {
//   final String filePath;

//   const ApkInstallerScreen({required this.filePath, Key? key}) : super(key: key);

//   @override
//   _ApkInstallerScreenState createState() => _ApkInstallerScreenState();
// }

// class _ApkInstallerScreenState extends State<ApkInstallerScreen> {
//   @override
//   void initState() {
//     super.initState();
//     Future.delayed(Duration(milliseconds: 500), () async {
//       try {
//         await ApkInstaller.installApk(filePath: widget.filePath);
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error installing APK: $e')),
//           );
//         }
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Installing APK")),
//       body: Center(child: Text("Installing APK...")),
//     );
//   }
// }
