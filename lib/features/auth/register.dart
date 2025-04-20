import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartvest/core/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For the Google icon
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add Firestore instance


  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        if (_passwordController.text.trim() == _confirmPasswordController.text.trim()) {
          UserCredential? userCredential = await _authService.signUpWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

          if (userCredential != null) {
            print('Registration successful! User ID: ${userCredential.user?.uid}');
            // Check if the user's profile is completed in Firestore
            final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
            final profileCompleted = userDoc.data()?['profileCompleted'] ?? false;
            if (profileCompleted) {
              Navigator.pushReplacementNamed(context, '/dashboard'); // Use the named route
            }
            else{
              Navigator.pushReplacementNamed(context, '/welcome');
            }
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Passwords do not match.';
          });
          return;
        }
      } catch (e) {
        print('Registration error: $e');
        setState(() {
          _isLoading = false;
          if (e is FirebaseAuthException) {
            _errorMessage = _handleFirebaseAuthError(e.code);
          } else {
            _errorMessage = 'Registration failed. Please try again.';
          }
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final UserCredential? userCredential = await _authService.signUpWithGoogle(context);
      if (userCredential != null) {
        print('Google sign-up successful! User ID: ${userCredential.user?.uid}');
        // Check if the user's profile is completed in Firestore
        final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        final profileCompleted = userDoc.data()?['profileCompleted'] ?? false;
        if (profileCompleted) {
          Navigator.pushReplacementNamed(context, '/dashboard'); // Use the named route
        }
        else{
          Navigator.pushReplacementNamed(context, '/welcome'); // Use the named route
        }
      }
    } catch (e) {
      print('Google sign-up error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to sign up with Google. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _handleFirebaseAuthError(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'The email address is already in use by another account.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'Registration failed. Please check your information and try again.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),
                // Confirm Password Text Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),
                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Register'),
                ),
                const SizedBox(height: 10.0),
                // Google Sign-Up Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignUp,
                  icon: const FaIcon(FontAwesomeIcons.google, color: Colors.redAccent),
                  label: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('Sign up with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
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
                // Navigate to Login Screen
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Go back to the login screen
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

