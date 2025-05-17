import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/animations.dart';
import '../data/bg_data.dart';
import '../utils/text_utils.dart';
import 'home.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  bool showOption = false;
  bool _isLogin = true;
  bool _isLoading = false;
  String _userType = 'student';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final String baseUrl = "http://192.168.243.11:5000";

  late AnimationController _popController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _popController,
      curve: Curves.elasticOut,
    );

    _popController.forward();
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_formKey.currentState!.validate()) {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      String confirmPassword = _confirmPasswordController.text.trim();

      setState(() => _isLoading = true);

      try {
        final url = Uri.parse(_isLogin ? "$baseUrl/login" : "$baseUrl/register");
        final body = {
          "email": email,
          "password": password,
          "type": _userType,
          if (!_isLogin) "username": email.split("@")[0],
          if (!_isLogin) "confirmPassword": confirmPassword,
        };

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: json.encode(body),
        );

        final data = json.decode(response.body);
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );

        if (response.statusCode == 200 && data['success']) {
          if (_isLogin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage(email: email, userType: _userType)),
            );
          } else {
            setState(() => _isLogin = true);
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Unable to connect to server.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 49,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: showOption
                  ? ShowUpAnimation(
                      delay: 100,
                      child: ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: bgList.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => setState(() => selectedIndex = index),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  selectedIndex == index ? Colors.white : Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.all(1),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage: AssetImage(bgList[index]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => setState(() => showOption = !showOption),
              child: showOption
                  ? const Icon(Icons.close, color: Colors.white, size: 30)
                  : CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage(bgList[selectedIndex]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bgList[selectedIndex]),
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.center,
        child: Form(
          key: _formKey,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              height: _isLogin ? 400 : 470,
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaY: 5, sigmaX: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Center(child: TextUtil(text: _isLogin ? "Login" : "Signup", weight: true, size: 30)),
                        const Spacer(),
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.black87,
                          value: _userType,
                          items: const [
                            DropdownMenuItem(value: 'student', child: Text("Student", style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'faculty', child: Text("Faculty", style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) => setState(() => _userType = val!),
                          decoration: const InputDecoration(
                            labelText: "User Type",
                            labelStyle: TextStyle(color: Colors.white),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                        ),
                        const Spacer(),
                        TextUtil(text: "Email"),
                        _buildInput(_emailController, Icons.mail, "email"),
                        const Spacer(),
                        TextUtil(text: "Password"),
                        _buildInput(_passwordController, Icons.lock, "password", isObscure: true),
                        if (!_isLogin) ...[
                          const Spacer(),
                          TextUtil(text: "Confirm Password"),
                          _buildInput(_confirmPasswordController, Icons.lock_outline, "confirm password", isObscure: true),
                        ],
                        const Spacer(),
                        _buildAuthButton(),
                        const Spacer(),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isLogin = !_isLogin);
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            },
                            child: TextUtil(
                              text: _isLogin ? "Don't have an account? REGISTER" : "Already have an account? LOGIN",
                              size: 12,
                              weight: true,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, IconData icon, String hint,
      {bool isObscure = false}) {
    return Container(
      height: 35,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white))),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          suffixIcon: Icon(icon, color: Colors.white),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $hint';
          if (hint == 'email' &&
              !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          if ((hint == 'password' || hint == 'confirm password') && value.length < 5) {
            return '$hint must be at least 5 characters';
          }
          if (hint == 'confirm password' && value != _passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAuthButton() {
    return GestureDetector(
      onTap: _handleAuth,
      child: Container(
        height: 40,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : TextUtil(text: _isLogin ? "Log In" : "Sign Up", color: Colors.black),
      ),
    );
  }
}
