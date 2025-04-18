import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartvest/core/services/auth_service.dart'; // Import your AuthService
import 'package:smartvest/config/app_routes.dart'; // Import your routes - Corrected import
import 'package:flutter/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); // Instance of AuthService
  bool _isLoading = false; // Track loading state
  String _errorMessage = ''; // To display errors

  // Function to handle login
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = ''; // Clear previous errors
      });

      try {
        UserCredential? userCredential = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (userCredential != null) {
          // Login successful, navigate to home or other screen
          print('Login successful! User ID: ${userCredential.user?.uid}');
          //Navigator.pushReplacementNamed(context, AppRoutes.home); // Use your route name
          Navigator.pushReplacementNamed(context, '/dashboard'); // Use the named route
        }
      } catch (e) {
        // Handle login errors
        print('Login error: $e');
        setState(() {
          _isLoading = false;
          if (e is FirebaseAuthException) {
            _errorMessage = _handleFirebaseAuthError(e.code);
          } else {
            _errorMessage = 'Login failed. Please try again.';
          }
        });
      } finally {
        if (mounted) { //check whether the state object is currently in a tree.
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _handleFirebaseAuthError(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Login failed. Please check your credentials and try again.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Email Text Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r"^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+.[a-z]{2,}$")
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),
              // Password Text Field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),
              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _login, // Disable when loading
                child: _isLoading
                    ? const CircularProgressIndicator() // Show loading indicator
                    : const Text('Login'),
              ),
              const SizedBox(height: 10.0),
              // Display error message
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20.0),
              // Navigate to Register Screen
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register'); // Use your route name
                },
                child: const Text('Don\'t have an account? Register'),
              ),
              // Navigate to Forgot Password Screen
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/forgot_password'); // Use your route name
                },
                child: const Text('Forgot Password?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


