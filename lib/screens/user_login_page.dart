import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';
import '../services/session_service.dart';
import '../utils/firebase_utils.dart';
import '../models/user_model.dart';
import 'roll_and_read_game.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }


  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final pin = _pinController.text.trim();
      
      // Wait for Firebase to be ready before attempting login
      await FirebaseUtils.waitForFirebaseReady();
      
      // Get user from Firestore
      final user = await FirestoreService.getUserByEmail(email);
      
      
      if (user == null) {
        setState(() {
          _errorMessage = 'User not found. Please check your email address or contact Mrs. Elson.';
          _isLoading = false;
        });
        return;
      }

      // Check PIN
      if (user.pin != pin) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        // Save user and current route for session persistence
        await SessionService.saveUser(user);
        await SessionService.saveCurrentRoute('/game-join');
        
        // Navigate to game join page using named route
        Navigator.pushReplacementNamed(context, '/game-join');
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('Firebase initialization timeout')) {
          _errorMessage = 'Connection timeout. Please check your internet connection and try again.';
        } else {
          _errorMessage = 'An error occurred. Please try again.';
        }
        _isLoading = false;
      });
    }
  }

  void _showUsersList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Available Users'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: StreamBuilder<List<UserModel>>(
            stream: FirestoreService.getAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              
              final users = snapshot.data ?? [];
              
              if (users.isEmpty) {
                return const Center(
                  child: Text('No users found'),
                );
              }
              
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.isAdmin ? AppColors.adminPrimary.withOpacity(0.1) : AppColors.studentPrimary.withOpacity(0.1),
                      child: Icon(
                        user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: user.isAdmin ? AppColors.adminPrimary : AppColors.studentPrimary,
                      ),
                    ),
                    title: Text(user.displayName),
                    subtitle: Text('${user.emailAddress}\nPIN: ${user.pin}'),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.pop(context);
                      _emailController.text = user.emailAddress;
                      _pinController.text = user.pin ?? '';
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: AppColors.studentBackground,
      appBar: AppBar(
        title: const Text('Student Login'),
        backgroundColor: AppColors.studentPrimary,
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
                        Icons.school,
                        size: isTablet ? 80 : 60,
                        color: AppColors.studentPrimary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email to start playing',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'student@school.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
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
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        enabled: !_isLoading,
                        maxLength: 4,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: '4-Digit PIN',
                          hintText: 'Enter your PIN',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your PIN';
                          }
                          if (value.length != 4) {
                            return 'PIN must be exactly 4 digits';
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                            return 'PIN must contain only numbers';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.mediumBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.mediumBlue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.mediumBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppColors.mediumBlue,
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
                            backgroundColor: AppColors.studentPrimary,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.pop(context);
                                  },
                            child: Text(
                              'Back to Home',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isTablet ? 16 : 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    _showUsersList();
                                  },
                            child: Text(
                              'Show Users',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: isTablet ? 16 : 14,
                              ),
                            ),
                          ),
                        ],
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

// Updated game screen that accepts a user
class RollAndReadGameWithUser extends StatefulWidget {
  final UserModel user;
  
  const RollAndReadGameWithUser({super.key, required this.user});

  @override
  State<RollAndReadGameWithUser> createState() => _RollAndReadGameWithUserState();
}

class _RollAndReadGameWithUserState extends State<RollAndReadGameWithUser> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${widget.user.displayName}!"),
        backgroundColor: AppColors.studentPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const RollAndReadGame(), // Your existing game
    );
  }
}