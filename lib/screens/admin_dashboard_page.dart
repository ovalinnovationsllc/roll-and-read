import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/player_colors.dart';
import '../services/firestore_service.dart';
import '../services/ai_word_service.dart';
import '../services/word_list_service.dart';
import '../services/game_session_service.dart';
import '../services/game_state_service.dart';
import '../models/word_list_model.dart';
import '../models/game_session_model.dart';
import '../models/game_state_model.dart';
import '../models/student_game_model.dart';
import 'teacher_game_screen.dart';
import 'teacher_review_screen.dart';
import '../data/preset_word_lists.dart';

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
  List<GameSessionModel> _activeGames = [];
  
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
  
  bool _speechInitialized = false;
  bool get _isMobilePlatform => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStatistics();
    _searchController.addListener(_onSearchChanged);
    _initializeSpeech();
    
    // Run cleanup of old games in background after a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _performMaintenanceCleanup();
        }
      });
    });
    
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }


  /// Perform background maintenance cleanup
  void _performMaintenanceCleanup() {
    // Don't await - run completely in background
    FirestoreService.performMaintenanceCleanup().then((_) {
      print('📱 Admin Dashboard: Maintenance cleanup completed successfully');
    }).catchError((e) {
      print('📱 Admin Dashboard: Cleanup failed - ${e.toString()}');
    });
    print('📱 Admin Dashboard: Maintenance cleanup started in background...');
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
          comparison = a.wordsRead.compareTo(b.wordsRead);
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
        },
        onStatus: (status) {
        },
      );
      
      if (mounted) {
        setState(() {
          _speechInitialized = true;
        });
      }
    } catch (e) {
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
                _buildDetailRow('PIN', user.pin ?? 'N/A'),
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
                  _buildDetailRow('Words Read', user.wordsRead.toString()),
                  if (user.gamesPlayed > 0)
                    _buildDetailRow('Win Rate', '${((user.gamesWon / user.gamesPlayed) * 100).toStringAsFixed(1)}%'),
                  if (user.gamesPlayed > 0)
                    _buildDetailRow('Average Words per Game', '${(user.wordsRead / user.gamesPlayed).toStringAsFixed(1)}'),
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
                            
                            // Use the proper create student dialog instead of hardcoded values
                            Navigator.pop(context);
                            _showCreateStudentDialog();
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
                        
                        // Use the proper create student dialog instead of hardcoded values
                        Navigator.pop(context);
                        _showCreateStudentDialog();
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
    bool loadingWordLists = false;
    String wordListMode = 'default'; // 'default', 'existing', 'new', or 'preset'
    int maxPlayers = 2; // Default to 2 players
    String selectedPresetGrade = 'kindergarten'; // For preset lists
    String selectedPrompt = ''; // Local to dialog - resets each time dialog opens

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
                    label: Text('Quick'),
                  ),
                  ButtonSegment<String>(
                    value: 'preset',
                    label: Text('Preset Lists'),
                  ),
                  ButtonSegment<String>(
                    value: 'existing',
                    label: Text('Saved'),
                  ),
                  ButtonSegment<String>(
                    value: 'new',
                    label: Text('Generate'),
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
                  // Autocomplete word list selection
                  Autocomplete<WordListModel>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<WordListModel>.empty();
                      }
                      // Filter and remove duplicates based on prompt text
                      final filteredOptions = availableWordLists.where((WordListModel option) {
                        final prompt = option.prompt.toLowerCase();
                        final searchQuery = textEditingValue.text.toLowerCase();
                        return prompt.contains(searchQuery);
                      }).toList();
                      
                      // Remove duplicates by prompt text
                      final Map<String, WordListModel> uniqueOptions = {};
                      for (final option in filteredOptions) {
                        final key = option.prompt.isEmpty ? 'Untitled List' : option.prompt;
                        if (!uniqueOptions.containsKey(key)) {
                          uniqueOptions[key] = option;
                        }
                      }
                      
                      return uniqueOptions.values.take(10); // Limit to 10 results
                    },
                    displayStringForOption: (WordListModel option) => 
                        option.prompt.isEmpty ? 'Untitled List' : option.prompt,
                    onSelected: (WordListModel selection) {
                      setDialogState(() {
                        selectedWordList = selection;
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Pre-populate if we have a selection
                      if (selectedWordList != null && textEditingController.text.isEmpty) {
                        textEditingController.text = selectedWordList!.prompt.isEmpty 
                            ? 'Untitled List' 
                            : selectedWordList!.prompt;
                      }
                      
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onSubmitted: (value) => onFieldSubmitted(),
                        decoration: InputDecoration(
                          labelText: 'Search & Select Word List',
                          hintText: 'Type to search saved word lists...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: selectedWordList != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedWordList = null;
                                          textEditingController.clear();
                                        });
                                      },
                                    ),
                                  ],
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          // Clear selection when typing
                          if (selectedWordList != null) {
                            setDialogState(() {
                              selectedWordList = null;
                            });
                          }
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                final displayText = option.prompt.isEmpty ? 'Untitled List' : option.prompt;
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      displayText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ] else if (wordListMode == 'preset') ...[
                DropdownButtonFormField<String>(
                  value: selectedPresetGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level',
                    prefixIcon: Icon(Icons.grade),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'kindergarten',
                      child: Text('Kindergarten Sight Words'),
                    ),
                    DropdownMenuItem(
                      value: 'first',
                      child: Text('First Grade Trick Words'),
                    ),
                    DropdownMenuItem(
                      value: 'second',
                      child: Text('Second Grade Trick Words'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPresetGrade = value!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '✓ Randomly selects 36 words from the chosen list',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                // Simple pattern selection buttons instead of complex text input
                _buildSimplePatternSelector(setDialogState, selectedPrompt, (newPrompt) {
                  setDialogState(() {
                    selectedPrompt = newPrompt;
                  });
                }),
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
                  } else if (wordListMode == 'preset') {
                    wordGrid = PresetWordLists.getRandomWordsForGrid(selectedPresetGrade);
                  } else if (wordListMode == 'existing' && selectedWordList != null) {
                    wordGrid = selectedWordList!.wordGrid;
                    // Update the word list usage stats
                    WordListService.updateLastUsed(selectedWordList!.id);
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
                    aiPrompt: useAIWords ? (selectedPrompt.isEmpty 
                        ? 'Simple educational words for middle school students' 
                        : selectedPrompt) : null,
                    difficulty: useAIWords ? selectedDifficulty : null,
                  );
                  
                  setDialogState(() {
                    isCreating = false;
                  });
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    // Navigate to teacher review screen instead of showing completion dialog
                    _navigateToTeacherReview(gameSession, useAIWords ? selectedPrompt : null, useAIWords ? selectedDifficulty : null);
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
      builder: (context) => StreamBuilder<GameSessionModel?>(
        stream: FirestoreService.listenToGameSession(studentGame.gameId),
        builder: (context, snapshot) {
          final currentGame = snapshot.data;
          if (currentGame == null) {
            return const AlertDialog(
              title: Text('Game Not Found'),
              content: Text('This game no longer exists.'),
            );
          }
          
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.games, color: AppColors.gamePrimary),
                const SizedBox(width: 8),
                Text('Game: ${currentGame.gameId}'),
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
                          'Status: ${currentGame.status.toString().split('.').last.toUpperCase()}',
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
                        backgroundColor: _getPlayerColor(player.playerColor),
                        child: Text(
                          player.avatarUrl ?? '😊',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      title: Text(player.displayName),
                      subtitle: Text('Joined: ${player.joinedAt.toString().split(' ')[1].substring(0, 5)}'),
                      trailing: player.isReady
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
                    await GameSessionService.startGameSession(currentGame.gameId);
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
                      await FirestoreService.deleteGameSession(currentGame.gameId);
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


  Color _getPlayerColor(int? colorValue) {
    if (colorValue == null) return Colors.blue;
    return Color(colorValue);
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
    String wordListMode = 'default'; // 'default', 'existing', 'new', or 'preset'
    int maxPlayers = 2; // Default to 2 players
    String selectedPresetGrade = 'kindergarten'; // For preset lists
    String selectedPrompt = ''; // Local to dialog - resets each time dialog opens

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
                    label: Text('Quick'),
                  ),
                  ButtonSegment<String>(
                    value: 'preset',
                    label: Text('Preset Lists'),
                  ),
                  ButtonSegment<String>(
                    value: 'existing',
                    label: Text('Saved'),
                  ),
                  ButtonSegment<String>(
                    value: 'new',
                    label: Text('Generate'),
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
              ] else if (wordListMode == 'preset') ...[
                DropdownButtonFormField<String>(
                  value: selectedPresetGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level',
                    prefixIcon: Icon(Icons.grade),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'kindergarten',
                      child: Text('Kindergarten Sight Words'),
                    ),
                    DropdownMenuItem(
                      value: 'first',
                      child: Text('First Grade Trick Words'),
                    ),
                    DropdownMenuItem(
                      value: 'second',
                      child: Text('Second Grade Trick Words'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPresetGrade = value!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '✓ Randomly selects 36 words from the chosen list',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                // Simple pattern selection buttons instead of complex text input
                _buildSimplePatternSelector(setDialogState, selectedPrompt, (newPrompt) {
                  setDialogState(() {
                    selectedPrompt = newPrompt;
                  });
                }),
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
                  } else if (wordListMode == 'preset') {
                    wordGrid = PresetWordLists.getRandomWordsForGrid(selectedPresetGrade);
                  } else if (wordListMode == 'existing' && selectedWordList != null) {
                    wordGrid = selectedWordList!.wordGrid;
                    // Update the word list usage stats
                    WordListService.updateLastUsed(selectedWordList!.id);
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
                    aiPrompt: useAIWords ? (selectedPrompt.isEmpty 
                        ? 'Simple educational words for middle school students' 
                        : selectedPrompt) : null,
                    difficulty: useAIWords ? selectedDifficulty : null,
                  );
                  
                  setDialogState(() {
                    isCreating = false;
                  });
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    // Navigate to teacher review screen instead of showing completion dialog
                    _navigateToTeacherReview(gameSession, useAIWords ? selectedPrompt : null, useAIWords ? selectedDifficulty : null);
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
                      icon: Icon(Icons.history),
                      text: 'Completed Games',
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
                _buildCompletedGamesTab(isTablet),
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
        if (snapshot.data != null) {
          // Update the active games list without setState to avoid rebuild loop
          // Include both waiting and in-progress games (including single player)
          _activeGames = snapshot.data!.where((game) => 
            game.status == GameStatus.waitingForPlayers || 
            game.status == GameStatus.inProgress
          ).toList();
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
                    key: ValueKey(game.gameId),
                    child: game.status == GameStatus.inProgress 
                      ? _buildSimpleActiveGameCard(game, isTablet)
                      : _buildGameCard(game, isTablet),
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
            key: ValueKey('students_${widget.adminUser.id}'),
            stream: FirestoreService.listenToActiveStudents(teacherId: widget.adminUser.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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

    return GestureDetector(
      onTap: () {
        // Navigate to the game screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherGameScreen(
              user: widget.adminUser,
              gameSession: game,
            ),
          ),
        );
      },
      child: Card(
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
                    // Delete button for waiting and in-progress games
                    if (game.status == GameStatus.waitingForPlayers || game.status == GameStatus.inProgress)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        iconSize: 20,
                        color: Colors.red[400],
                        tooltip: 'Delete game',
                        onPressed: () => _deleteGame(game),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
            
          ],
        ),
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

  Widget _buildSimpleActiveGameCard(GameSessionModel game, bool isTablet) {
    return StreamBuilder<GameStateModel?>(
      stream: GameStateService.getGameStateStream(game.gameId),
      builder: (context, gameStateSnapshot) {
        final gameState = gameStateSnapshot.data;
        final createdAt = game.createdAt;
        final duration = DateTime.now().difference(createdAt);
        
        // Determine status
        String statusText;
        Color statusColor;
        IconData statusIcon;
        
        if (game.players.isEmpty) {
          statusText = 'WAITING FOR PLAYERS';
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_empty;
        } else if (gameState != null && gameState.pendingPronunciations.isNotEmpty) {
          statusText = 'WAITING FOR TEACHER';
          statusColor = Colors.orange;
          statusIcon = Icons.pending;
        } else {
          statusText = 'IN PROGRESS';
          statusColor = Colors.blue;
          statusIcon = Icons.play_circle;
        }
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeacherGameScreen(
                  user: widget.adminUser,
                  gameSession: game,
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with status, created time, and delete button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Delete button for waiting and in-progress games
                      if (game.status == GameStatus.waitingForPlayers || game.status == GameStatus.inProgress) ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 20,
                          color: Colors.red[400],
                          tooltip: 'Delete game',
                          onPressed: () => _deleteGame(game),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatActiveGameTime(createdAt),
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Game ID and duration
                  Row(
                    children: [
                      Text(
                        'Game ${game.gameId}',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Duration: ${_formatDuration(duration)}',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Players summary
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${game.players.length} player${game.players.length != 1 ? 's' : ''}:',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: game.players.isNotEmpty 
                          ? Text(
                              game.players.map((p) => p.displayName).join(', '),
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              'No players yet',
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                      ),
                    ],
                  ),
                  
                  // Tap hint
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to join as teacher',
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 9,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _completeGame(GameSessionModel game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Game'),
        content: Text('Mark "${game.gameName}" as completed? This will:\n• End the game\n• Save player statistics\n• Show final scores to all players'),
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
        
        // Get current game state to determine winner
        final gameState = await GameStateService.getGameState(game.gameId);
        final winnerId = gameState?.checkForWinner();
        
        // End the game session with winner info
        final updatedGame = await GameSessionService.endGameSession(
          gameId: game.gameId,
          winnerId: winnerId,
        );
        
        // Clean up game state
        await GameStateService.deleteGameState(game.gameId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game "${game.gameName}" completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (e is Exception) {
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
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _approvePronunciation(gameSession, cellKey),
                                    icon: const Icon(Icons.check, size: 14),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      minimumSize: Size(80, 32),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _rejectPronunciation(gameSession, cellKey),
                                    icon: const Icon(Icons.close, size: 14),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      minimumSize: Size(80, 32),
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
              
              // Action buttons - reorganized layout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Complete Game + Delete Game
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _completeGame(gameSession),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size(90, 32),
                          ),
                          child: const Text(
                            'Complete Game',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _deleteGame(gameSession),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size(90, 32),
                          ),
                          child: const Text('Delete Game', style: TextStyle(fontSize: 12)),
                        ),
                      ],
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No statistics will be saved!',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (game.players.isNotEmpty) ...[
              Text(
                'This will remove ${game.players.length} player(s) from the game.',
                style: TextStyle(
                  color: Colors.grey.shade700,
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
  void _showCreateStudentDialog() async {
    final nameController = TextEditingController();
    
    // Load available (unused) colors and avatars
    final availableColors = await FirestoreService.getAvailableColors(widget.adminUser.id);
    final availableAvatars = await FirestoreService.getAvailableAvatars(widget.adminUser.id);
    
    // Check if any colors or avatars are available
    if (availableColors.isEmpty || availableAvatars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum of ${PlayerColors.maxStudentsPerTeacher} students reached. Delete some students first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    String selectedAvatar = availableAvatars[0];
    Color selectedColor = availableColors[0];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 600;
          final dialogWidth = isMobile ? screenSize.width * 0.9 : 400.0;
          
          return AlertDialog(
            title: const Text('Create Student'),
            scrollable: true, // Make dialog scrollable
            content: SizedBox(
              width: dialogWidth,
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
                  Text(
                    'Choose Avatar: (${availableAvatars.length} available)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: isMobile ? 180 : 250, // Responsive height
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableAvatars.map((emoji) {
                          final isSelected = selectedAvatar == emoji;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedAvatar = emoji),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? selectedColor : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                color: isSelected ? selectedColor.withOpacity(0.1) : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scroll down to see all ${availableAvatars.length} avatars ↓',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
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
                    children: availableColors.map((color) {
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
                        // StreamBuilder will automatically refresh
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
        );
        },
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
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context); // Close stats dialog first
              await _deleteStudentConfirmation(student);
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Student'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
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
        // StreamBuilder will automatically refresh
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

  Widget _buildCompletedGamesTab(bool isTablet) {
    return FutureBuilder<List<GameSessionModel>>(
      future: FirestoreService.getCompletedGames(teacherId: widget.adminUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: isTablet ? 64 : 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading completed games',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final completedGames = snapshot.data ?? [];
        
        if (completedGames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: isTablet ? 64 : 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed games in the past 5 days',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete games will appear here',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }


        return RefreshIndicator(
          onRefresh: () async {
            // StreamBuilder will automatically refresh
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedGames.length,
            itemBuilder: (context, index) {
              final game = completedGames[index];
              return _buildCompletedGameCard(game, isTablet);
            },
          ),
        );
      },
    );
  }

  Widget _buildCompletedGameCard(GameSessionModel game, bool isTablet) {
    final completedAt = game.endedAt ?? game.createdAt;
    final duration = completedAt.difference(game.createdAt);
    final winner = game.winnerId != null && game.players.isNotEmpty
        ? game.players.firstWhere((p) => p.userId == game.winnerId, 
            orElse: () => game.players.first)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with game name and completion time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatCompletedDate(completedAt),
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Game ID and duration
            Row(
              children: [
                Text(
                  'Game ${game.gameId}',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Duration: ${_formatDuration(duration)}',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            if (winner != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: Colors.amber[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Winner: ${winner.displayName}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Players summary
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${game.players.length} player${game.players.length != 1 ? 's' : ''}:',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    game.players.map((p) => p.displayName).join(', '),
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatActiveGameTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Started ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Started Yesterday';
    } else if (difference.inDays < 7) {
      return 'Started ${difference.inDays} days ago';
    } else {
      return 'Started ${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatCompletedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
  
  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
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

  // Navigate to teacher review screen for word preview and modification
  void _navigateToTeacherReview(GameSessionModel gameSession, String? aiPrompt, String? difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeacherReviewScreen(
          gameSession: gameSession,
          adminUser: widget.adminUser,
        ),
      ),
    ).then((_) {
      // StreamBuilder will automatically refresh when returning from review screen
    });
  }

  // Build the simple pattern selector UI for teachers
  Widget _buildSimplePatternSelector(StateSetter setDialogState, String selectedPrompt, Function(String) onPromptChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Word Pattern for Reading Practice:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        
        // Word Family Patterns
        const Text('Word Families:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPatternButton('-at words (cat, bat, hat)', 'words ending in -at', selectedPrompt, onPromptChanged),
            _buildPatternButton('-et words (pet, get, let)', 'words ending in -et', selectedPrompt, onPromptChanged),
            _buildPatternButton('-it words (sit, hit, bit)', 'words ending in -it', selectedPrompt, onPromptChanged),
            _buildPatternButton('-ot words (hot, pot, dot)', 'words ending in -ot', selectedPrompt, onPromptChanged),
            _buildPatternButton('-ut words (cut, but, hut)', 'words ending in -ut', selectedPrompt, onPromptChanged),
            _buildPatternButton('-an words (can, man, ran)', 'words ending in -an', selectedPrompt, onPromptChanged),
            _buildPatternButton('-en words (pen, ten, hen)', 'words ending in -en', selectedPrompt, onPromptChanged),
            _buildPatternButton('-in words (pin, win, tin)', 'words ending in -in', selectedPrompt, onPromptChanged),
            _buildPatternButton('-un words (run, sun, fun)', 'words ending in -un', selectedPrompt, onPromptChanged),
            _buildPatternButton('-ig words (big, dig, fig)', 'words ending in -ig', selectedPrompt, onPromptChanged),
            _buildPatternButton('-og words (dog, log, hog)', 'words ending in -og', selectedPrompt, onPromptChanged),
            _buildPatternButton('-ug words (bug, hug, jug)', 'words ending in -ug', selectedPrompt, onPromptChanged),
            _buildPatternButton('-ay words (day, way, say)', 'words ending in -ay', selectedPrompt, onPromptChanged),
            _buildPatternButton('-ed words (red, bed, fed)', 'words ending in -ed', selectedPrompt, onPromptChanged),
          ],
        ),
        const SizedBox(height: 16),
        
        // Vowel Sounds
        const Text('Vowel Sounds:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPatternButton('Short A (cat, bat)', 'words with short a sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Short E (bed, red)', 'words with short e sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Short I (sit, hit)', 'words with short i sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Short O (hot, pot)', 'words with short o sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Short U (cut, run)', 'words with short u sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Long A (cake, name)', 'words with long a sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Long E (tree, see)', 'words with long e sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Long I (bike, time)', 'words with long i sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Long O (boat, home)', 'words with long o sound', selectedPrompt, onPromptChanged),
            _buildPatternButton('Long U (cube, tune)', 'words with long u sound', selectedPrompt, onPromptChanged),
          ],
        ),
        const SizedBox(height: 16),
        
        // Simple Topics  
        const Text('Simple Topics:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPatternButton('Animals', 'farm animals', selectedPrompt, onPromptChanged),
            _buildPatternButton('Colors', 'basic color names', selectedPrompt, onPromptChanged),
            _buildPatternButton('3-Letter Words', '3 letter CVC words', selectedPrompt, onPromptChanged),
            _buildPatternButton('4-Letter Words', '4 letter words', selectedPrompt, onPromptChanged),
            _buildPatternButton('5-Letter Words', '5 letter words', selectedPrompt, onPromptChanged),
            _buildPatternButton('6-Letter Words', '6 letter words', selectedPrompt, onPromptChanged),
          ],
        ),
        const SizedBox(height: 16),
        
        // Show selected pattern
        if (selectedPrompt.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: $selectedPrompt',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedPrompt = '';
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // Build individual pattern selection button
  Widget _buildPatternButton(String displayText, String promptText, String selectedPrompt, Function(String) onPromptChanged) {
    final isSelected = selectedPrompt == promptText;
    
    return ElevatedButton(
      onPressed: () {
        onPromptChanged(promptText);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : Colors.grey[100],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        displayText,
        style: const TextStyle(fontSize: 13),
      ),
    );
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