import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../services/ai_word_service.dart';
import '../services/word_list_service.dart';
import '../services/game_session_service.dart';
import '../services/game_state_service.dart';
import '../models/word_list_model.dart';
import '../models/game_session_model.dart';
import '../models/game_state_model.dart';
import '../models/student_game_model.dart';
import '../services/student_game_service.dart';
import 'clean_multiplayer_screen.dart';
import 'roll_and_read_game.dart';
import 'simple_student_selector.dart';
import 'teacher_pronunciation_monitor.dart';
import '../widgets/animated_dice.dart';

class AdminDashboardPage extends StatefulWidget {
  final UserModel adminUser;

  const AdminDashboardPage({
    super.key,
    required this.adminUser,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _statistics;
  bool _loadingStats = true;
  
  // Default word grid with child-friendly 4-6 character words
  static const List<List<String>> defaultWordGrid = [
    ['fish', 'bird', 'bear', 'frog', 'duck', 'lamb'],
    ['jump', 'swim', 'ride', 'play', 'walk', 'sing'],
    ['blue', 'pink', 'green', 'black', 'white', 'brown'],
    ['happy', 'silly', 'quiet', 'brave', 'smart', 'kind'],
    ['ball', 'book', 'cake', 'door', 'tree', 'house'],
    ['smile', 'laugh', 'sleep', 'dream', 'dance', 'share'],
  ];
  
  // User management state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Monitor state - removed toggle functionality, monitors display automatically
  String _sortBy = 'name'; // 'name', 'email', 'created', 'games', 'words'
  bool _sortAscending = true;
  String _roleFilter = 'all'; // 'all', 'admin', 'student'

  // Speech-to-text state (mobile only)
  stt.SpeechToText? _speech;
  bool _speechEnabled = false;
  
  // Students stream for tab
  late Stream<List<StudentModel>> _studentsStream;
  bool _speechInitialized = false;
  bool get _isMobilePlatform => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatistics();
    _searchController.addListener(_onSearchChanged);
    _initializeSpeech();
    
    // Initialize students stream as broadcast stream
    _studentsStream = Stream.periodic(const Duration(seconds: 5), (_) async {
      return await FirestoreService.getAllActiveStudents();
    }).asyncMap((future) => future).asBroadcastStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  List<UserModel> _filterAndSortUsers(List<UserModel> users) {
    // Filter by search query
    var filteredUsers = users.where((user) {
      if (_searchQuery.isEmpty) return true;
      return user.displayName.toLowerCase().contains(_searchQuery) ||
             user.emailAddress.toLowerCase().contains(_searchQuery);
    }).toList();
    
    // Filter by role
    if (_roleFilter != 'all') {
      filteredUsers = filteredUsers.where((user) {
        if (_roleFilter == 'admin') return user.isAdmin;
        if (_roleFilter == 'student') return !user.isAdmin;
        return true;
      }).toList();
    }
    
    // Sort users
    filteredUsers.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
          break;
        case 'email':
          comparison = a.emailAddress.toLowerCase().compareTo(b.emailAddress.toLowerCase());
          break;
        case 'created':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'games':
          comparison = a.gamesPlayed.compareTo(b.gamesPlayed);
          break;
        case 'won':
          comparison = a.gamesWon.compareTo(b.gamesWon);
          break;
        case 'words':
          comparison = a.wordsCorrect.compareTo(b.wordsCorrect);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
    return filteredUsers;
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this user?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(user.emailAddress),
                  const SizedBox(height: 4),
                  Text(
                    user.isAdmin ? 'Teacher' : 'Student',
                    style: TextStyle(
                      color: user.isAdmin ? AppColors.adminPrimary : AppColors.studentPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // For local storage, we don't need to delete admin users
      final success = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '${user.displayName} deleted successfully' 
                : 'Failed to delete ${user.displayName}'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
      if (success) {
        // Refresh statistics
        setState(() {
          _loadingStats = true;
        });
        _loadStatistics();
      }
    }
  }

  void _showEditUserDialog(UserModel user, bool isTablet) {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.emailAddress);
    final pinController = TextEditingController(text: user.pin);
    final formKey = GlobalKey<FormState>();
    bool isAdmin = user.isAdmin;
    bool isUpdating = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submitForm() async {
            if (!formKey.currentState!.validate()) return;
            
            setDialogState(() {
              isUpdating = true;
            });
            
            try {
              final updatedUser = user.copyWith(
                displayName: nameController.text.trim(),
                emailAddress: emailController.text.trim(),
                pin: pinController.text.trim(),
                isAdmin: isAdmin,
              );
              
              // For local storage, admin user updates are handled in session
              final success = true;
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                        ? '${user.displayName} updated successfully' 
                        : 'Failed to update ${user.displayName}'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                setDialogState(() {
                  isUpdating = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating user: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          }
          
          return AlertDialog(
          title: const Text('Edit User'),
          content: SizedBox(
            width: isTablet ? 400 : 300,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value.trim())) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!formKey.currentState!.validate() || isUpdating) return;
                      // Trigger the update user action
                      submitForm();
                    },
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: Icon(Icons.lock),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a PIN';
                      }
                      if (value.trim().length != 4) {
                        return 'PIN must be exactly 4 digits';
                      }
                      if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                        return 'PIN must contain only numbers';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Teacher'),
                    subtitle: const Text('Give teacher privileges'),
                    value: isAdmin,
                    onChanged: (value) {
                      setDialogState(() {
                        isAdmin = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () => submitForm(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminPrimary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await FirestoreService.getUserStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _statistics = {'totalStudents': 0, 'totalGames': 0, 'totalWordsRead': 0, 'activeStudents': 0};
          _loadingStats = false;
        });
      }
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();
      
      // Try to initialize speech recognition on all platforms
      // The speech_to_text plugin handles permissions internally
      _speechEnabled = await _speech!.initialize(
        onError: (error) {
          print('Speech error: ${error.errorMsg}');
        },
        onStatus: (status) {
          print('Speech status: $status');
        },
      );
      
      if (mounted) {
        setState(() {
          _speechInitialized = true;
        });
      }
    } catch (e) {
      print('Speech initialization error: $e');
      if (mounted) {
        setState(() {
          _speechEnabled = false;
          _speechInitialized = true;
        });
      }
    }
  }

  Future<void> _startVoiceRecording({
    required TextEditingController controller,
    required Function(String) onResult,
    required VoidCallback onStart,
    required VoidCallback onStop,
  }) async {
    if (!_speechEnabled || !_speechInitialized || _speech == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice recording not available. Please make sure microphone permissions are granted.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    onStart();
    
    try {
      await _speech!.listen(
        onResult: (result) {
          if (result.finalResult) {
            controller.text = result.recognizedWords;
            onResult(result.recognizedWords);
            onStop();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print('Error starting voice recording: $e');
      onStop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start voice recording. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showUserDetailsDialog(UserModel user, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: user.isAdmin
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              child: Icon(
                user.isAdmin
                    ? Icons.admin_panel_settings
                    : Icons.person,
                color: user.isAdmin
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: isTablet ? 500 : 350,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Email', user.emailAddress),
                _buildDetailRow('PIN', user.pin),
                _buildDetailRow('Account Type', user.isAdmin ? 'Administrator' : 'Student'),
                _buildDetailRow('Created', _formatDate(user.createdAt)),
                const SizedBox(height: 16),
                
                // Only show game stats for non-admin users
                if (!user.isAdmin) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Game Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Games Played', user.gamesPlayed.toString()),
                  _buildDetailRow('Games Won', user.gamesWon.toString()),
                  _buildDetailRow('Words Read Correctly', user.wordsCorrect.toString()),
                  if (user.gamesPlayed > 0)
                    _buildDetailRow('Win Rate', '${((user.gamesWon / user.gamesPlayed) * 100).toStringAsFixed(1)}%'),
                  if (user.gamesPlayed > 0)
                    _buildDetailRow('Average Words per Game', '${(user.wordsCorrect / user.gamesPlayed).toStringAsFixed(1)}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(user, isTablet);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  void _stopVoiceRecording() {
    _speech?.stop();
  }


  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isAdmin = false;
    bool isCreating = false;
    
    // Generate initial random PIN
    String _generateRandomPin() {
      final random = Random();
      return (1000 + random.nextInt(9000)).toString(); // Generates 1000-9999
    }
    
    pinController.text = _generateRandomPin();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    hintText: 'Enter student name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'student@school.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) async {
                          if (!formKey.currentState!.validate() || isCreating) return;
                          
                          setDialogState(() {
                            isCreating = true;
                          });
                          
                          try {
                            // Check if student name already exists
                            final existingStudents = await FirestoreService.getAllActiveStudents();
                            final existingUser = existingStudents
                                .where((s) => s.displayName.toLowerCase() == nameController.text.trim().toLowerCase())
                                .firstOrNull;
                            
                            if (existingUser != null) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User with this email already exists'),
                                    backgroundColor: AppColors.mediumBlue,
                                  ),
                                );
                              }
                              setDialogState(() {
                                isCreating = false;
                              });
                              return;
                            }
                            
                            // Create student
                            final user = await FirestoreService.createStudent(
                              teacherId: widget.adminUser.id,
                              displayName: nameController.text.trim(),
                              avatarUrl: '🙂', // Default avatar
                              playerColor: Colors.blue, // Default color
                            );
                            
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Student ${user?.displayName ?? 'Unknown'} created successfully'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() {
                                isCreating = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error creating user: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: '4-Digit PIN',
                          hintText: '1234',
                          prefixIcon: Icon(Icons.lock),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a PIN';
                          }
                          if (value.trim().length != 4) {
                            return 'PIN must be exactly 4 digits';
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                            return 'PIN must contain only numbers';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setDialogState(() {
                          pinController.text = _generateRandomPin();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Generate Random PIN',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.success.withOpacity(0.1),
                        foregroundColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Teacher'),
                  subtitle: const Text('Give admin privileges'),
                  value: isAdmin,
                  onChanged: (value) {
                    setDialogState(() {
                      isAdmin = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isCreating 
                  ? null 
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      
                      setDialogState(() {
                        isCreating = true;
                      });
                      
                      try {
                        // Check if student name already exists
                        final existingStudents = await FirestoreService.getAllActiveStudents();
                        final existingUser = existingStudents
                            .where((s) => s.displayName.toLowerCase() == nameController.text.trim().toLowerCase())
                            .firstOrNull;
                        
                        if (existingUser != null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User with this email already exists'),
                                backgroundColor: AppColors.mediumBlue,
                              ),
                            );
                          }
                          setDialogState(() {
                            isCreating = false;
                          });
                          return;
                        }
                        
                        // Create student
                        final user = await FirestoreService.createStudent(
                          teacherId: widget.adminUser.id,
                          displayName: nameController.text.trim(),
                          avatarUrl: '🙂', // Default avatar
                          playerColor: Colors.blue, // Default color
                        );
                        
                        if (mounted) {
                          Navigator.pop(context);
                          if (user != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Student ${user.displayName} created successfully'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                            // Refresh statistics
                            setState(() {
                              _loadingStats = true;
                            });
                            _loadStatistics();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to create user'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error creating user'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                      ),
                    )
                  : const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateStudentGameDialog() {
    bool isCreating = false;
    String selectedDifficulty = 'elementary';
    WordListModel? selectedWordList;
    List<WordListModel> availableWordLists = [];
    List<WordListModel> filteredWordLists = [];
    String wordListSearchQuery = '';
    final wordListSearchController = TextEditingController();
    final wordPromptController = TextEditingController();
    bool loadingWordLists = false;
    String wordListMode = 'default'; // 'default', 'existing', or 'new'
    int maxPlayers = 2; // Default to 2 players

    // Filter word lists based on search query
    void filterWordLists(String query, StateSetter setDialogState) {
      setDialogState(() {
        wordListSearchQuery = query;
        if (query.isEmpty) {
          filteredWordLists = availableWordLists;
        } else {
          filteredWordLists = availableWordLists.where((wordList) {
            return wordList.prompt.toLowerCase().contains(query.toLowerCase());
          }).toList();
        }
      });
    }

    // Load existing word lists
    void loadWordLists(StateSetter setDialogState) async {
      if (loadingWordLists) return;
      setDialogState(() {
        loadingWordLists = true;
      });
      try {
        final wordLists = await WordListService.getAllWordLists();
        if (mounted) {
          setDialogState(() {
            availableWordLists = wordLists;
            filteredWordLists = wordLists; // Initially show all
            loadingWordLists = false;
          });
        }
      } catch (e) {
        setDialogState(() {
          loadingWordLists = false;
        });
      }
    }


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word list selection - simplified
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'default',
                    label: Text('Quick Game'),
                  ),
                  ButtonSegment<String>(
                    value: 'existing',
                    label: Text('Saved List'),
                  ),
                  ButtonSegment<String>(
                    value: 'new',
                    label: Text('Generate New'),
                  ),
                ],
                selected: {wordListMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setDialogState(() {
                    wordListMode = newSelection.first;
                  });
                  if (wordListMode == 'existing' && availableWordLists.isEmpty) {
                    loadWordLists(setDialogState);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Player count selection
              const Text(
                'Number of Players',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('1 Player'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('2 Players'),
                    icon: Icon(Icons.people),
                  ),
                ],
                selected: {maxPlayers},
                onSelectionChanged: (Set<int> newSelection) {
                  setDialogState(() {
                    maxPlayers = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Show options based on selected mode
              if (wordListMode == 'existing') ...[
                if (loadingWordLists)
                  const CircularProgressIndicator()
                else if (availableWordLists.isEmpty)
                  const Text('No saved word lists found.')
                else ...[
                  // Search field for filtering word lists
                  TextField(
                    controller: wordListSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search Word Lists',
                      hintText: 'Type to search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: wordListSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                wordListSearchController.clear();
                                filterWordLists('', setDialogState);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => filterWordLists(value, setDialogState),
                  ),
                  const SizedBox(height: 8),
                  // Filtered dropdown
                  DropdownButtonFormField<WordListModel>(
                    value: selectedWordList,
                    decoration: const InputDecoration(
                      labelText: 'Select Word List',
                      prefixIcon: Icon(Icons.list),
                    ),
                    hint: Text(filteredWordLists.isEmpty 
                        ? 'No matching word lists' 
                        : 'Choose a saved word list'),
                    items: filteredWordLists
                        .map((wordList) => DropdownMenuItem(
                              value: wordList,
                              child: Text(
                                wordList.prompt.isEmpty ? 'Untitled List' : wordList.prompt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedWordList = value;
                      });
                    },
                  ),
                ],
              ] else if (wordListMode == 'new') ...[
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Reading Level',
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: AIWordService.getDifficultyLevels()
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level.replaceAll('-', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDifficulty = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: wordPromptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Word Theme/Topic for AI',
                    hintText: 'e.g., "simple animals", "easy action words", "basic colors"',
                    prefixIcon: Icon(Icons.lightbulb),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                const Text(
                  '✓ Start a quick game with a default list of simple words',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                setDialogState(() {
                  isCreating = true;
                });
                
                try {
                  // Auto-generate game name
                  final now = DateTime.now();
                  String period = now.hour >= 12 ? 'PM' : 'AM';
                  int hour = now.hour;
                  if (hour > 12) hour -= 12;
                  if (hour == 0) hour = 12;
                  String gameName = 'Game ${now.month}/${now.day} ${hour}:${now.minute.toString().padLeft(2, '0')} $period';
                  
                  // Get word grid based on selected mode
                  List<List<String>>? wordGrid;
                  bool useAIWords = false;
                  
                  if (wordListMode == 'default') {
                    wordGrid = _getDefaultSimpleWordGrid();
                  } else if (wordListMode == 'existing' && selectedWordList != null) {
                    wordGrid = selectedWordList!.wordGrid;
                  } else if (wordListMode == 'new') {
                    useAIWords = true;
                  }
                  
                  // Create the game session
                  final gameSession = await GameSessionService.createGameSession(
                    createdBy: widget.adminUser.id,
                    gameName: gameName,
                    maxPlayers: maxPlayers,
                    wordGrid: wordGrid,
                    useAIWords: useAIWords,
                    aiPrompt: useAIWords ? (wordPromptController.text.trim().isEmpty 
                        ? 'Simple educational words for middle school students' 
                        : wordPromptController.text.trim()) : null,
                    difficulty: useAIWords ? selectedDifficulty : null,
                  );
                  
                  setDialogState(() {
                    isCreating = false;
                  });
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showGameCreatedDialog(gameSession);
                  }
                } catch (e) {
                  setDialogState(() {
                    isCreating = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create game: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: isCreating 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Game'),
            ),
          ],
        ),
      ),
    );
  }
  void _showStudentGameCreatedDialog(StudentGameModel studentGame) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppColors.success),
            const SizedBox(width: 8),
            const Text('Game Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.gamePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gamePrimary, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'Game Code',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    studentGame.gameCode,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gamePrimary,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Students can join by:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Opening the app\n'
              '2. Tapping "Join Game"\n'
              '3. Entering this code',
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 16),
            Text(
              'Players: 0/${studentGame.maxPlayers}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showStudentGameManagement(studentGame);
            },
            child: const Text('Manage Game'),
          ),
        ],
      ),
    );
  }

  void _showStudentGameManagement(StudentGameModel studentGame) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<StudentGameModel?>(
        stream: StudentGameService.getGameStream(studentGame.gameId),
        builder: (context, snapshot) {
          final currentGame = snapshot.data ?? studentGame;
          
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.games, color: AppColors.gamePrimary),
                const SizedBox(width: 8),
                Text('Game: ${currentGame.gameCode}'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentGame.isWaiting 
                          ? AppColors.primary.withOpacity(0.1)
                          : currentGame.isActive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          currentGame.isWaiting 
                              ? Icons.hourglass_empty
                              : currentGame.isActive
                                  ? Icons.play_circle
                                  : Icons.check_circle,
                          color: currentGame.isWaiting 
                              ? AppColors.primary
                              : currentGame.isActive
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status: ${currentGame.gameMode.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Players List
                  Text(
                    'Players (${currentGame.players.length}/${currentGame.maxPlayers}):',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  if (currentGame.players.isEmpty)
                    const Text(
                      'No players joined yet',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...currentGame.players.map((player) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getPlayerColor(player.avatarColor),
                        child: Icon(
                          _getPlayerIcon(player.avatarIcon),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(player.playerName),
                      subtitle: Text('Slot ${player.playerSlot}'),
                      trailing: player.isConnected
                          ? Icon(Icons.circle, color: Colors.green, size: 12)
                          : Icon(Icons.circle, color: Colors.red, size: 12),
                    )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (currentGame.isWaiting && currentGame.canStart)
                ElevatedButton(
                  onPressed: () async {
                    await StudentGameService.startGame(currentGame.gameId);
                  },
                  child: const Text('Start Game'),
                ),
              if (currentGame.isWaiting)
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Game'),
                        content: const Text('Are you sure? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await StudentGameService.deleteGame(currentGame.gameId);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Delete Game'),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _getPlayerColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return AppColors.primary;
      case 'purple': return Colors.purple;
      case 'orange': return AppColors.primary;
      default: return Colors.blue;
    }
  }

  IconData _getPlayerIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'cat': return Icons.pets;
      case 'dog': return Icons.pets;
      case 'star': return Icons.star;
      case 'heart': return Icons.favorite;
      case 'butterfly': return Icons.flutter_dash;
      case 'sun': return Icons.wb_sunny;
      default: return Icons.person;
    }
  }

  // Default simple word grid for students with reading difficulties
  List<List<String>> _getDefaultSimpleWordGrid() {
    // Simple 3-5 letter words organized into a 6x6 grid
    return [
      ['CAT', 'DOG', 'SUN', 'HAT', 'BIG', 'RED'],
      ['RUN', 'FUN', 'TOP', 'BOX', 'COW', 'PIG'],
      ['BALL', 'BOOK', 'FISH', 'CAKE', 'JUMP', 'TREE'],
      ['BIRD', 'MOON', 'BOAT', 'RING', 'PARK', 'WAVE'],
      ['HAPPY', 'WATER', 'HOUSE', 'TRAIN', 'SMILE', 'LIGHT'],
      ['BREAD', 'CHAIR', 'MUSIC', 'PAINT', 'GRASS', 'BEACH'],
    ];
  }

  void _showCreateGameDialog() {
    bool isCreating = false;
    String selectedDifficulty = 'elementary';
    WordListModel? selectedWordList;
    List<WordListModel> availableWordLists = [];
    bool loadingWordLists = false;
    String wordListMode = 'default'; // 'default', 'existing', or 'new'
    int maxPlayers = 2; // Default to 2 players
    final wordPromptController = TextEditingController();

    // Load existing word lists
    void loadWordLists(StateSetter setDialogState) async {
      if (loadingWordLists) return;
      setDialogState(() {
        loadingWordLists = true;
      });
      try {
        final wordLists = await WordListService.getAllWordLists();
        if (mounted) {
          setDialogState(() {
            availableWordLists = wordLists;
            loadingWordLists = false;
          });
        }
      } catch (e) {
        setDialogState(() {
          loadingWordLists = false;
        });
      }
    }


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word list selection - simplified
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'default',
                    label: Text('Quick Game'),
                  ),
                  ButtonSegment<String>(
                    value: 'existing',
                    label: Text('Saved List'),
                  ),
                  ButtonSegment<String>(
                    value: 'new',
                    label: Text('Generate New'),
                  ),
                ],
                selected: {wordListMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setDialogState(() {
                    wordListMode = newSelection.first;
                  });
                  if (wordListMode == 'existing' && availableWordLists.isEmpty) {
                    loadWordLists(setDialogState);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Player count selection
              const Text(
                'Number of Players',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('1 Player'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('2 Players'),
                    icon: Icon(Icons.people),
                  ),
                ],
                selected: {maxPlayers},
                onSelectionChanged: (Set<int> newSelection) {
                  setDialogState(() {
                    maxPlayers = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Show options based on selected mode
              if (wordListMode == 'existing') ...[
                if (loadingWordLists)
                  const CircularProgressIndicator()
                else if (availableWordLists.isEmpty)
                  const Text('No saved word lists found.')
                else
                  DropdownButtonFormField<WordListModel>(
                    value: selectedWordList,
                    decoration: const InputDecoration(
                      labelText: 'Select Word List',
                      prefixIcon: Icon(Icons.list),
                    ),
                    hint: const Text('Choose a saved word list'),
                    items: availableWordLists
                        .map((wordList) => DropdownMenuItem(
                              value: wordList,
                              child: Text(
                                wordList.prompt.isEmpty ? 'Untitled List' : wordList.prompt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedWordList = value;
                      });
                    },
                  ),
              ] else if (wordListMode == 'new') ...[
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Reading Level',
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: AIWordService.getDifficultyLevels()
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level.replaceAll('-', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDifficulty = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: wordPromptController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Word Theme/Topic for AI',
                    hintText: 'e.g., "simple animals", "easy action words", "basic colors"',
                    prefixIcon: Icon(Icons.lightbulb),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                const Text(
                  '✓ Start a quick game with a default list of simple words',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                setDialogState(() {
                  isCreating = true;
                });
                
                try {
                  // Auto-generate game name
                  final now = DateTime.now();
                  String period = now.hour >= 12 ? 'PM' : 'AM';
                  int hour = now.hour;
                  if (hour > 12) hour -= 12;
                  if (hour == 0) hour = 12;
                  String gameName = 'Game ${now.month}/${now.day} ${hour}:${now.minute.toString().padLeft(2, '0')} $period';
                  
                  // Get word grid based on selected mode
                  List<List<String>>? wordGrid;
                  bool useAIWords = false;
                  
                  if (wordListMode == 'default') {
                    wordGrid = _getDefaultSimpleWordGrid();
                  } else if (wordListMode == 'existing' && selectedWordList != null) {
                    wordGrid = selectedWordList!.wordGrid;
                  } else if (wordListMode == 'new') {
                    useAIWords = true;
                  }
                  
                  // Create the game session
                  final gameSession = await GameSessionService.createGameSession(
                    createdBy: widget.adminUser.id,
                    gameName: gameName,
                    maxPlayers: maxPlayers,
                    wordGrid: wordGrid,
                    useAIWords: useAIWords,
                    aiPrompt: useAIWords ? (wordPromptController.text.trim().isEmpty 
                        ? 'Simple educational words for middle school students' 
                        : wordPromptController.text.trim()) : null,
                    difficulty: useAIWords ? selectedDifficulty : null,
                  );
                  
                  setDialogState(() {
                    isCreating = false;
                  });
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showGameCreatedDialog(gameSession);
                  }
                } catch (e) {
                  setDialogState(() {
                    isCreating = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create game: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: isCreating 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Game'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: AppColors.adminBackground,
      appBar: AppBar(
        title: const Text(
          "Teacher Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          // Create game button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateStudentGameDialog(),
            tooltip: 'Create Game',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadingStats = true;
              });
              _loadStatistics();
            },
            tooltip: 'Refresh',
          ),
          // Firebase status button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showFirebaseStatus(),
            tooltip: 'Firebase Status',
          ),
          // Logout button
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
                        foregroundColor: AppColors.onPrimary,
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
      body: Column(
        children: [
          // Teacher Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.adminPrimary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.adminUser.displayName.isEmpty ? 'Teacher' : widget.adminUser.displayName}',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.onPrimary,
                  labelColor: AppColors.onPrimary,
                  unselectedLabelColor: AppColors.onPrimary.withOpacity(0.7),
                  labelStyle: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.gamepad_outlined),
                      text: 'Active Games',
                    ),
                    Tab(
                      icon: Icon(Icons.people_outline),
                      text: 'Students',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveGamesTab(isTablet),
                _buildStudentsTab(isTablet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGamesTab(bool isTablet) {
    return StreamBuilder<List<GameSessionModel>>(
      stream: GameSessionService.listenToGamesByAdmin(widget.adminUser.id),
      builder: (context, snapshot) {
        print('📱 StreamBuilder: connectionState=${snapshot.connectionState}, hasError=${snapshot.hasError}, data=${snapshot.data?.length ?? 0} games');
        if (snapshot.data != null) {
          for (final game in snapshot.data!) {
            print('  📱 Game ${game.gameId}: ${game.players.length}/${game.maxPlayers} players, status=${game.status}');
          }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading active games...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading games',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.red.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final games = snapshot.data ?? [];
        print('📱 StreamBuilder: Received ${games.length} games');
        
        if (games.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gamepad_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active games',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button above to create a new game',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        print('📱 StreamBuilder: Showing games section with ${games.length} active games');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Games Section Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Games (${games.length})',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'Tap cards to manage',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Games List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return KeyedSubtree(
                    key: ValueKey('${game.gameId}_${game.players.length}'),
                    child: _buildGameCard(game, isTablet),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudentsTab(bool isTablet) {
    return Column(
      children: [
        // Students Management Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Students',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateStudentDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),

        // Students List
        Expanded(
          child: StreamBuilder<List<StudentModel>>(
            stream: _studentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading students...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading students',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.red.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final students = snapshot.data ?? [];

              if (students.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No students yet',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Add Student" above to get started',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return _buildStudentCard(student, isTablet);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createGameSession(String gameName, List<List<String>> wordGrid, int maxPlayers, bool useAIWords, String wordListMode) async {
    try {
      final gameSession = await GameSessionService.createGameSession(
        createdBy: widget.adminUser.id,
        gameName: gameName,
        useAIWords: useAIWords,
        wordGrid: wordGrid,
        maxPlayers: maxPlayers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game "${gameName}" created! Game ID: ${gameSession.gameId}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating game: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGameCard(GameSessionModel game, bool isTablet) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (game.status) {
      case GameStatus.waitingForPlayers:
        statusColor = AppColors.mediumBlue;
        statusText = 'Waiting (${game.players.length}/${game.maxPlayers})';
        statusIcon = Icons.hourglass_empty;
        print('🎯 Building card for game ${game.gameId}: statusText="$statusText", players=${game.players.length}, maxPlayers=${game.maxPlayers}');
        break;
      case GameStatus.inProgress:
        statusColor = Colors.green;
        statusText = 'In Progress';
        statusIcon = Icons.play_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with game name, status and action buttons
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.gameName,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${game.gameId}',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (game.status == GameStatus.inProgress) ...[
                      IconButton(
                        onPressed: () => _completeGame(game),
                        icon: const Icon(Icons.check_circle_outline),
                        color: Colors.green.shade600,
                        tooltip: 'Complete Game',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        iconSize: isTablet ? 20 : 18,
                      ),
                      IconButton(
                        onPressed: () => _endGame(game),
                        icon: const Icon(Icons.stop_circle),
                        color: AppColors.primary,
                        tooltip: 'End Game',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        iconSize: isTablet ? 20 : 18,
                      ),
                    ],
                    IconButton(
                      onPressed: () => _deleteGame(game),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red.shade600,
                      tooltip: 'Delete Game',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      iconSize: isTablet ? 20 : 18,
                    ),
                  ],
                ),
              ],
            ),
            
            // Enhanced game info for in-progress games
            if (game.status == GameStatus.inProgress) ...[
              const SizedBox(height: 16),
              // Game state info
              StreamBuilder<GameStateModel?>(
                stream: GameStateService.getGameStateStream(game.gameId),
                builder: (context, snapshot) {
                  final gameState = snapshot.data;
                  return _buildGameStateInfo(game, gameState, isTablet);
                },
              ),
              
              // Automatic inline monitor view for in-progress games
              if (game.status == GameStatus.inProgress) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monitor, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Teacher Monitor - ${game.gameName}',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Embedded teacher monitor - constrained height to prevent overflow
                      SizedBox(
                        height: 500, // Fixed height to prevent RenderFlex overflow
                        child: StreamBuilder<GameSessionModel?>(
                          stream: GameSessionService.getGameSessionStream(game.gameId),
                          initialData: game,
                          builder: (context, snapshot) {
                            final currentGame = snapshot.data ?? game;
                            return _buildEmbeddedMonitor(currentGame);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGameStateInfo(GameSessionModel game, GameStateModel? gameState, bool isTablet) {
    if (gameState == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.refresh, color: Colors.grey.shade600, size: 16),
            const SizedBox(width: 8),
            Text(
              'Loading game state...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isTablet ? 14 : 12,
              ),
            ),
          ],
        ),
      );
    }

    // Helper function to get player color from playerColor int value
    Color getPlayerColor(PlayerInGame player, int fallbackIndex) {
      if (player.playerColor != null) {
        return Color(player.playerColor!);
      }
      // Fallback to index-based colors if no playerColor set
      final fallbackColors = [
        Colors.red.shade400,
        Colors.blue.shade400,
        Colors.green.shade400,
        Colors.purple.shade400,
      ];
      return fallbackColors[fallbackIndex % fallbackColors.length];
    }

    // Get current word being attempted
    String? currentWord;
    String? currentWordPlayer;
    if (gameState.pendingPronunciations.isNotEmpty) {
      final attempt = gameState.pendingPronunciations.values.first;
      currentWord = attempt.word;
      currentWordPlayer = attempt.playerName;
    }

    // Get whose turn it is
    String? currentTurnPlayerName;
    if (gameState.currentTurnPlayerId != null) {
      final currentPlayer = game.players
          .where((p) => p.userId == gameState.currentTurnPlayerId)
          .firstOrNull;
      currentTurnPlayerName = currentPlayer?.displayName;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Players section - give it full width
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Players header
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    color: Colors.blue.shade700,
                    size: isTablet ? 18 : 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Players:',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Players wrap - full width with better spacing
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: game.players.asMap().entries.map((entry) {
                  final index = entry.key;
                  final player = entry.value;
                  final score = gameState.playerScores[player.userId] ?? 0;
                  final playerColor = getPlayerColor(player, index);
                  final isCurrentTurn = gameState.currentTurnPlayerId == player.userId;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentTurn ? playerColor : playerColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: isCurrentTurn ? Border.all(color: playerColor, width: 2) : null,
                      boxShadow: isCurrentTurn ? [
                        BoxShadow(
                          color: playerColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrentTurn)
                          Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: isTablet ? 16 : 14,
                          ),
                        if (isCurrentTurn) const SizedBox(width: 6),
                        Text(
                          '${player.displayName} ($score)',
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.w500,
                            color: isCurrentTurn ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Current turn info
          if (currentTurnPlayerName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.green.shade700,
                  size: isTablet ? 18 : 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.green.shade700,
                      ),
                      children: [
                        TextSpan(
                          text: 'Turn: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: currentTurnPlayerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Current word info
          if (currentWord != null && currentWordPlayer != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  color: AppColors.primary,
                  size: isTablet ? 18 : 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: AppColors.primary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Attempting: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: '"$currentWord"',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(
                          text: ' by ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: currentWordPlayer,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _completeGame(GameSessionModel game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Game'),
        content: Text('Mark "${game.gameName}" as completed? This will end the game and show final scores to players.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('🎯 Starting game completion for ${game.gameId}');
        
        // Get current game state to determine winner
        final gameState = await GameStateService.getGameState(game.gameId);
        final winnerId = gameState?.checkForWinner();
        print('🏆 Winner determined: $winnerId');
        
        // End the game session with winner info
        print('📝 Calling endGameSession...');
        final updatedGame = await GameSessionService.endGameSession(
          gameId: game.gameId,
          winnerId: winnerId,
        );
        print('✅ Game session ended successfully. Status: ${updatedGame?.status}');
        
        // Clean up game state
        print('🧹 Cleaning up game state...');
        await GameStateService.deleteGameState(game.gameId);
        print('✅ Game state cleaned up');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game "${game.gameName}" completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('❌ Error completing game: $e'); 
        print('❌ Error type: ${e.runtimeType}');
        if (e is Exception) {
          print('❌ Exception details: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endGame(GameSessionModel game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game'),
        content: Text('End "${game.gameName}" without completing? Players will be returned to the lobby.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Game'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedGame = game.copyWith(status: GameStatus.cancelled);
        await GameSessionService.updateGameSession(updatedGame);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game "${game.gameName}" ended'),
            backgroundColor: AppColors.primary,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // Build an embedded version of the teacher monitor without Scaffold
  Widget _buildEmbeddedMonitor(GameSessionModel gameSession) {
    return StreamBuilder<GameStateModel?>(
      stream: GameStateService.getGameStateStream(gameSession.gameId),
      builder: (context, gameStateSnapshot) {
        final gameState = gameStateSnapshot.data;
        final winnerId = gameState?.checkForWinner();
        final hasWinner = winnerId != null;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              
              // Pronunciation Approval Section
              if (gameState?.pendingPronunciations.isNotEmpty ?? false)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.mic, size: 30, color: AppColors.primary),
                      const SizedBox(height: 8),
                      const Text(
                        'Pronunciation Pending',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...gameState!.pendingPronunciations.entries.map((entry) {
                        final cellKey = entry.key;
                        final attempt = entry.value;
                        final playerName = attempt.playerName;
                        final word = attempt.word;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$playerName is pronouncing: ${word.toUpperCase()}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _rejectPronunciation(gameSession, cellKey),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _approvePronunciation(gameSession, cellKey),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              
              // Game Log
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Game Log',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (gameState?.pronunciationLog.isNotEmpty == true)
                        Expanded(
                          child: ListView.builder(
                            itemCount: gameState!.pronunciationLog.length,
                            itemBuilder: (context, index) {
                              final logEntry = gameState.pronunciationLog[gameState.pronunciationLog.length - 1 - index]; // Show newest first
                              final player = gameSession.players.firstWhere(
                                (p) => p.userId == logEntry.playerId,
                                orElse: () => PlayerInGame(
                                  userId: logEntry.playerId,
                                  displayName: logEntry.playerName,
                                  emailAddress: '',
                                  joinedAt: DateTime.now(),
                                  wordsRead: 0,
                                  avatarUrl: null,
                                  playerColor: null,
                                  isReady: false,
                                ),
                              );
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: logEntry.approved ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: logEntry.approved ? Colors.green.shade200 : Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      logEntry.approved ? Icons.check_circle : Icons.cancel,
                                      size: 16,
                                      color: logEntry.approved ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${player.displayName}: "${logEntry.word}"',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatLogTime(logEntry.resolvedTime),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No pronunciation attempts yet\nGame log will appear here',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _endGame(gameSession),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('End Early', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _completeGame(gameSession),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Complete Game',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper methods for embedded monitor
  Future<void> _approvePronunciation(GameSessionModel gameSession, String cellKey) async {
    try {
      // Get player IDs from game session
      final playerIds = gameSession.players.map((p) => p.userId).toList();
      
      await GameStateService.approvePronunciation(
        gameId: gameSession.gameId,
        cellKey: cellKey,
        playerIds: playerIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pronunciation approved!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error approving pronunciation: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _rejectPronunciation(GameSessionModel gameSession, String cellKey) async {
    try {
      // Get player IDs from game session
      final playerIds = gameSession.players.map((p) => p.userId).toList();
      
      await GameStateService.rejectPronunciation(
        gameId: gameSession.gameId,
        cellKey: cellKey,
        playerIds: playerIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Pronunciation rejected'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error rejecting pronunciation: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteGame(GameSessionModel game) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${game.gameName}"?'),
            const SizedBox(height: 8),
            Text(
              'Game ID: ${game.gameId}',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.grey.shade600,
              ),
            ),
            if (game.players.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'This will remove ${game.players.length} player(s) from the game.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the game session
      await GameSessionService.deleteGameSession(game.gameId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game "${game.gameName}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting game: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Student Management Methods
  void _showCreateStudentDialog() {
    final nameController = TextEditingController();
    String selectedAvatar = StudentAvatars.animalEmojis[0];
    Color selectedColor = StudentAvatars.colors[0];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Student'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Student Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a student name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  
                  // Avatar Selection
                  const Text(
                    'Choose Avatar:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: StudentAvatars.animalEmojis.length,
                      itemBuilder: (context, index) {
                        final emoji = StudentAvatars.animalEmojis[index];
                        final isSelected = selectedAvatar == emoji;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedAvatar = emoji),
                          child: Container(
                            width: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? selectedColor : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Color Selection
                  const Text(
                    'Choose Color:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: StudentAvatars.colors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final student = await FirestoreService.createStudent(
                      teacherId: widget.adminUser.id,
                      displayName: nameController.text.trim(),
                      avatarUrl: selectedAvatar,
                      playerColor: selectedColor,
                    );

                    if (mounted) {
                      Navigator.of(context).pop();
                      if (student != null) {
                        setState(() {}); // Refresh the list
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Student "${student.displayName}" created successfully'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating student: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Student'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentModel student, bool isTablet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showStudentStatsDialog(student, isTablet),
        leading: CircleAvatar(
          backgroundColor: student.playerColor,
          child: Text(
            student.avatarUrl,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          student.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isTablet ? 16 : 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Games: ${student.gamesPlayed} • Won: ${student.gamesWon} • Words: ${student.wordsRead}',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last played: ${_formatDate(student.lastPlayedAt)}',
              style: TextStyle(
                fontSize: isTablet ? 11 : 9,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  void _showStudentStatsDialog(StudentModel student, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: student.playerColor,
              radius: isTablet ? 24 : 20,
              child: Text(
                student.avatarUrl,
                style: TextStyle(fontSize: isTablet ? 20 : 16),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                student.displayName,
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Games Played', '${student.gamesPlayed}', Icons.sports_esports, isTablet),
              const SizedBox(height: 12),
              _buildStatRow('Games Won', '${student.gamesWon}', Icons.emoji_events, isTablet),
              const SizedBox(height: 12),
              _buildStatRow('Words Read', '${student.wordsRead}', Icons.record_voice_over, isTablet),
              const SizedBox(height: 12),
              _buildStatRow('Last Played', _formatDate(student.lastPlayedAt), Icons.schedule, isTablet),
              const SizedBox(height: 12),
              _buildStatRow('Created', _formatDate(student.createdAt), Icons.calendar_today, isTablet),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // Close stats dialog first
              await _deleteStudentConfirmation(student);
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, bool isTablet) {
    return Row(
      children: [
        Icon(icon, size: isTablet ? 20 : 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }


  Future<void> _deleteStudentConfirmation(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${student.displayName}"?'),
            const SizedBox(height: 8),
            const Text(
              'This will permanently remove their account and all game history.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await FirestoreService.deleteStudent(student.studentId);
      final success = true;
      if (mounted) {
        setState(() {}); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Student "${student.displayName}" deleted'
                : 'Failed to delete student'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }


  // Helper method to convert word list to 6x6 grid format
  List<List<String>> _convertWordListToGrid(List<String> words) {
    // Ensure we have enough words by padding with default words if needed
    final allWords = List<String>.from(words);
    final defaultWords = defaultWordGrid.expand((row) => row).toList();
    
    while (allWords.length < 36) {
      allWords.addAll(defaultWords);
      if (allWords.length > 36) {
        allWords.removeRange(36, allWords.length);
      }
    }
    
    // Create 6x6 grid
    final grid = <List<String>>[];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        if (index < allWords.length) {
          row.add(allWords[index]);
        } else {
          row.add(defaultWords[index % defaultWords.length]);
        }
      }
      grid.add(row);
    }
    
    return grid;
  }

  // Show game created dialog for regular game sessions
  void _showGameCreatedDialog(GameSessionModel gameSession) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppColors.success),
            const SizedBox(width: 8),
            const Text('Game Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Game Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gameSession.gameId,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Students can join using this game code',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Game'),
            ),
          ),
        ],
      ),
    );
  }


  void _showFirebaseStatus() {
    final isReady = FirestoreService.isFirebaseReady;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isReady ? Icons.check_circle : Icons.error,
              color: isReady ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            const Text('Firebase Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Connection Status: '),
                Text(
                  isReady ? 'Ready' : 'Not Ready',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isReady ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isReady 
                  ? 'Firebase is properly initialized and ready for database operations.'
                  : 'Firebase is not ready. User data will be loaded from cache only.',
            ),
            if (!isReady) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Text(
                  'Try refreshing your profile or restart the app if Firebase issues persist.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to format log entry timestamps
  String _formatLogTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Student avatar constants
class StudentAvatars {
  static const List<String> animalEmojis = [
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊',
    '🐻', '🐼', '🐨', '🐯', '🦁', '🐮',
  ];
  
  static const List<Color> colors = [
    Colors.red,
    Colors.blue, 
    Colors.green,
    AppColors.primary,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];
}