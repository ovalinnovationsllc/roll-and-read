import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../services/session_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'admin_dashboard_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberEmail = true;
  String? _errorMessage;
  bool _obscurePassword = true;
  static const String _savedEmailKey = 'roll_and_read_saved_teacher_email';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_savedEmailKey);
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
        setState(() {
          _rememberEmail = true;
        });
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  Future<void> _saveEmailIfNeeded(String email) async {
    try {
      if (_rememberEmail) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedEmailKey, email);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_savedEmailKey);
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }


  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // Save email if remember is checked
      await _saveEmailIfNeeded(email);
      
      UserModel? user;
      
      // Hybrid authentication: Firebase Auth first, fallback to email-only
      if (password == 'migrate123') {
        // Pre-migration fallback: email-only lookup
        user = await FirestoreService.getUserByEmail(email);
        if (user != null) {
          print('✅ Pre-migration email-only login successful');
        } else {
          setState(() {
            _errorMessage = 'Teacher email not found. Please check your email address.';
            _isLoading = false;
          });
          return;
        }
      } else {
        // Firebase Auth login
        try {
          final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          if (credential.user != null) {
            // Get user profile using Firebase UID
            user = await FirestoreService.getUserById(credential.user!.uid);
            if (user != null) {
              print('✅ Firebase Auth login successful');
            } else {
              // User authenticated but no profile found
              setState(() {
                _errorMessage = 'Teacher profile not found. Please contact support to complete setup.';
                _isLoading = false;
              });
              return;
            }
          }
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'Login failed. ';
          switch (e.code) {
            case 'user-not-found':
              errorMessage += 'No account found with this email. Use "migrate123" for pre-migration access.';
              break;
            case 'wrong-password':
              errorMessage += 'Incorrect password. Use "migrate123" for pre-migration access.';
              break;
            case 'invalid-email':
              errorMessage += 'Invalid email format.';
              break;
            case 'too-many-requests':
              errorMessage += 'Too many failed attempts. Please try again later.';
              break;
            default:
              errorMessage += 'Please try again or use "migrate123" for pre-migration access.';
          }
          
          setState(() {
            _errorMessage = errorMessage;
            _isLoading = false;
          });
          return;
        }
      }
      
      if (user == null) {
        setState(() {
          _errorMessage = 'User profile not found. Please contact support.';
          _isLoading = false;
        });
        return;
      }
      
      if (!user.isAdmin) {
        setState(() {
          _errorMessage = 'Access denied. Teacher privileges required.';
          _isLoading = false;
        });
        return;
      }
      
      if (mounted) {
        // Save user and current route for session persistence
        await SessionService.saveUser(user);
        await SessionService.saveCurrentRoute('/admin-dashboard');
        
        // Navigate to admin dashboard using named route
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      }
    } catch (e) {
      print('Login error: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showCreateTeacherDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    bool isCreating = false;
    bool obscurePassword = true;
    bool obscureConfirm = true;
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          return AlertDialog(
            title: const Text('Create New Teacher Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a secure teacher account to manage your classroom games and students.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher Name',
                      hintText: 'e.g., Mrs. Smith',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: !isCreating,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'teacher@school.edu',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    enabled: !isCreating,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'At least 6 characters',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    enabled: !isCreating,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                    ),
                    enabled: !isCreating,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isCreating ? null : () async {
                  // Validate input
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  final password = passwordController.text;
                  final confirmPassword = confirmPasswordController.text;
                  
                  if (name.isEmpty || email.isEmpty || password.isEmpty) {
                    setDialogState(() {
                      errorMessage = 'Please fill in all fields';
                    });
                    return;
                  }
                  
                  if (password != confirmPassword) {
                    setDialogState(() {
                      errorMessage = 'Passwords do not match';
                    });
                    return;
                  }
                  
                  if (password.length < 6) {
                    setDialogState(() {
                      errorMessage = 'Password must be at least 6 characters';
                    });
                    return;
                  }
                  
                  if (!email.contains('@') || !email.contains('.')) {
                    setDialogState(() {
                      errorMessage = 'Please enter a valid email address';
                    });
                    return;
                  }
                  
                  setDialogState(() {
                    isCreating = true;
                    errorMessage = null;
                  });
                  
                  try {
                    // Create user account
                    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                    
                    if (credential.user != null) {
                      // Update user profile
                      await credential.user!.updateDisplayName(name);
                      
                      // Create teacher profile
                      final firestoreUser = await FirestoreService.createTeacherWithFirebaseUID(
                        firebaseUID: credential.user!.uid,
                        email: email,
                        displayName: name,
                      );
                      
                      if (firestoreUser == null) {
                        throw Exception('Failed to create teacher profile');
                      }
                      
                      setDialogState(() {
                        isCreating = false;
                      });
                      
                      if (mounted) {
                        Navigator.of(context).pop();
                        // Show success dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                const Text('Account Created!'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your teacher account has been successfully created and is ready to use.',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person, color: Colors.green.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.email, color: Colors.green.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.green.shade800, size: 16),
                                            const SizedBox(width: 6),
                                            const Expanded(
                                              child: Text(
                                                'You can now login with your email and password',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: const Text(
                                  'Start Teaching!',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    setDialogState(() {
                      isCreating = false;
                      if (e is FirebaseAuthException) {
                        switch (e.code) {
                          case 'email-already-in-use':
                            errorMessage = 'This email address is already registered. Please use a different email or try logging in instead.';
                            break;
                          case 'invalid-email':
                            errorMessage = 'Please enter a valid email address.';
                            break;
                          case 'weak-password':
                            errorMessage = 'Please choose a stronger password with at least 6 characters.';
                            break;
                          case 'network-request-failed':
                            errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
                            break;
                          default:
                            errorMessage = 'Unable to create account. Please try again or contact support if the problem persists.';
                        }
                      } else if (e.toString().contains('permission-denied')) {
                        errorMessage = 'Account setup incomplete. Please contact your system administrator for assistance.';
                      } else if (e.toString().contains('network')) {
                        errorMessage = 'Network connection problem. Please check your internet and try again.';
                      } else {
                        errorMessage = 'Unable to complete account setup. Please try again in a few moments.';
                      }
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: isCreating 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Teacher'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: AppColors.adminBackground,
      appBar: AppBar(
        title: const Text('Teacher Login'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 500 : double.infinity,
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: isTablet ? 80 : 60,
                        color: AppColors.adminPrimary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Teacher Access',
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and password to access your account.',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'admin@example.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberEmail,
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _rememberEmail = value ?? false;
                              });
                            },
                            activeColor: AppColors.adminPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: _isLoading ? null : () {
                                setState(() {
                                  _rememberEmail = !_rememberEmail;
                                });
                              },
                              child: Text(
                                'Remember email for next time',
                                style: TextStyle(
                                  fontSize: isTablet ? 14 : 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: isTablet ? 56 : 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                _showCreateTeacherDialog(context);
                              },
                        child: Text(
                          'Create New Teacher',
                          style: TextStyle(
                            color: AppColors.adminPrimary,
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}