import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/ai_word_service.dart';
import '../services/word_list_service.dart';
import '../services/game_session_service.dart';
import '../models/word_list_model.dart';
import '../models/game_session_model.dart';
import 'multiplayer_roll_and_read.dart';
import 'roll_and_read_game.dart';
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

class _AdminDashboardPageState extends State<AdminDashboardPage> {
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
    _loadStatistics();
    _searchController.addListener(_onSearchChanged);
    _initializeSpeech();
  }

  @override
  void dispose() {
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
      final success = await FirestoreService.deleteUser(user.id);
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
              
              final success = await FirestoreService.updateUser(updatedUser);
              
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
    final stats = await FirestoreService.getUserStatistics();
    if (mounted) {
      setState(() {
        _statistics = stats;
        _loadingStats = false;
      });
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
                            // Check if user already exists
                            final existingUser = await FirestoreService.getUserByEmail(
                              emailController.text.trim(),
                            );
                            
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
                            
                            // Create user
                            final user = await FirestoreService.createUser(
                              email: emailController.text.trim(),
                              displayName: nameController.text.trim(),
                              pin: pinController.text.trim(),
                              isAdmin: isAdmin,
                            );
                            
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('User ${user?.displayName ?? 'Unknown'} created successfully with PIN: ${user?.pin ?? 'N/A'}'),
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
                        // Check if user already exists
                        final existingUser = await FirestoreService.getUserByEmail(
                          emailController.text.trim(),
                        );
                        
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
                        
                        // Create user
                        final user = await FirestoreService.createUser(
                          email: emailController.text.trim(),
                          displayName: nameController.text.trim(),
                          pin: pinController.text.trim(),
                          isAdmin: isAdmin,
                        );
                        
                        if (mounted) {
                          Navigator.pop(context);
                          if (user != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('User ${user.displayName} created successfully with PIN: ${user.pin}'),
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

  void _showCreateGameDialog() {
    final gameNameController = TextEditingController();
    final wordPromptController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;
    bool useAIWords = false;
    String selectedDifficulty = 'elementary';
    int maxPlayers = 2;
    WordListModel? selectedWordList;
    List<WordListModel> availableWordLists = [];
    bool loadingWordLists = false;
    String wordListMode = 'default'; // 'default', 'existing', or 'new'

    // Load existing word lists
    void loadWordLists() async {
      if (loadingWordLists) return;
      loadingWordLists = true;
      try {
        final wordLists = await WordListService.getAllWordLists();
        if (mounted) {
          availableWordLists = wordLists;
        }
      } catch (e) {
        print('Error loading word lists: $e');
      }
      loadingWordLists = false;
    }


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Game'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: gameNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Game Name (Optional)',
                    hintText: 'Reading Challenge 1',
                    prefixIcon: Icon(Icons.games),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Player count selection
                Row(
                  children: [
                    const Icon(Icons.group, color: Colors.grey),
                    const SizedBox(width: 12),
                    const Text('Players:'),
                    const SizedBox(width: 16),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(
                          value: 1,
                          label: Text('1'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment<int>(
                          value: 2,
                          label: Text('2'),
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
                  ],
                ),
                const SizedBox(height: 16),
                
                // Word list selection
                const Text('Word List:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'default',
                      label: Text('Default'),
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
                      if (wordListMode == 'existing' && availableWordLists.isEmpty) {
                        loadWordLists();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Show appropriate controls based on selected mode
                if (wordListMode == 'existing') ...[
                  if (loadingWordLists)
                    const CircularProgressIndicator()
                  else if (availableWordLists.isEmpty) ...[
                    const Text('No saved word lists found.'),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          loadWordLists();
                        });
                      },
                      child: const Text('Refresh'),
                    ),
                  ] else ...[
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wordList.prompt,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${wordList.difficulty.toUpperCase()} • Used ${wordList.timesUsed} times',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedWordList = value;
                        });
                      },
                      validator: (value) {
                        if (wordListMode == 'existing' && value == null) {
                          return 'Please select a word list';
                        }
                        return null;
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
                        selectedDifficulty = value ?? 'elementary';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: wordPromptController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Word Prompt for AI',
                            hintText: 'Describe the type of words you want the AI to generate',
                            prefixIcon: Icon(Icons.lightbulb),
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (wordListMode == 'new' && (value == null || value.trim().isEmpty)) {
                              return 'Please enter a prompt for AI word generation';
                            }
                            if (wordListMode == 'new' && value != null && value.trim().length < 10) {
                              return 'Please provide a more detailed prompt';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: AIWordService.getPromptTemplates()
                          .take(6)
                          .map((template) => ActionChip(
                                label: Text(
                                  template,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    wordPromptController.text = template;
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ]
                // Info section removed - simplified approach
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
                      // Validate form based on selected mode
                      if (!formKey.currentState!.validate()) return;
                      
                      setDialogState(() {
                        isCreating = true;
                      });
                      
                      try {
                        // Generate default game name if empty
                        String gameName = gameNameController.text.trim();
                        if (gameName.isEmpty) {
                          final now = DateTime.now();
                          int hour = now.hour;
                          String period = 'AM';
                          if (hour >= 12) {
                            period = 'PM';
                            if (hour > 12) hour -= 12;
                          }
                          if (hour == 0) hour = 12;
                          gameName = 'Game ${now.month}/${now.day} ${hour}:${now.minute.toString().padLeft(2, '0')} $period';
                        }
                        
                        List<List<String>> wordGrid = [];
                        
                        // Get word grid based on selected mode
                        if (wordListMode == 'default') {
                          // Use default word grid
                          wordGrid = defaultWordGrid;
                        } else if (wordListMode == 'existing') {
                          // Use selected existing word list
                          wordGrid = selectedWordList!.wordGrid;
                          // Increment usage count
                          await WordListService.incrementUsageCount(selectedWordList!.id);
                        } else {
                          // Generate new AI words
                          final prompt = wordPromptController.text.trim();
                          wordGrid = await AIWordService.generateWordGrid(
                            prompt: prompt,
                            difficulty: selectedDifficulty,
                          );
                          
                          // Save the new word list to Firebase for future use
                          final wordListModel = WordListModel.create(
                            prompt: prompt,
                            difficulty: selectedDifficulty,
                            wordGrid: wordGrid,
                            createdBy: widget.adminUser.id,
                          );
                          await WordListService.saveWordList(wordListModel);
                        }
                        
                        if (mounted) {
                          Navigator.pop(context);
                          
                          // Create game session that students can join
                          await _createGameSession(gameName, wordGrid, maxPlayers, wordListMode == 'new', wordListMode);
                        }
                      } catch (e) {
                        print('Error creating game: $e');
                        if (mounted) {
                          setDialogState(() {
                            isCreating = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating game: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateGameDialog(),
            tooltip: 'Create Game',
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showCreateUserDialog(),
            tooltip: 'Create User',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadingStats = true;
              });
              _loadStatistics();
              // Games list will refresh automatically via StreamBuilder
            },
            tooltip: 'Refresh',
          ),
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
                  'Welcome, ${widget.adminUser.displayName}',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.adminUser.emailAddress,
                  style: TextStyle(
                    color: AppColors.onPrimary.withOpacity(0.9),
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ],
            ),
          ),

          
          // Games Section Header  
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Games',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Tap to manage',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Games List with real-time updates
          SizedBox(
            height: 200,
            child: StreamBuilder<List<GameSessionModel>>(
              stream: GameSessionService.listenToGamesByAdmin(widget.adminUser.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading games: ${snapshot.error}',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.red.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allGames = snapshot.data ?? [];
                
                // Filter to only show active games (waiting for players or in progress)
                final games = allGames.where((game) => 
                  game.status == GameStatus.waitingForPlayers || 
                  game.status == GameStatus.inProgress
                ).toList();

                if (games.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            allGames.isEmpty ? 'No games created yet' : 'No active games',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return _buildGameCard(game, isTablet);
                  },
                );
              },
            ),
          ),
          
          // Users Management Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      'Tap to manage users',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Filter and Sort Controls
                Row(
                  children: [
                    // Role Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _roleFilter,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Users')),
                          DropdownMenuItem(value: 'admin', child: Text('Teachers Only')),
                          DropdownMenuItem(value: 'student', child: Text('Students Only')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _roleFilter = value ?? 'all';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Sort Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: InputDecoration(
                          labelText: 'Sort By',
                          prefixIcon: const Icon(Icons.sort),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'name', child: Text('Name')),
                          DropdownMenuItem(value: 'email', child: Text('Email')),
                          DropdownMenuItem(value: 'created', child: Text('Date Created')),
                          DropdownMenuItem(value: 'games', child: Text('Games Played')),
                          DropdownMenuItem(value: 'won', child: Text('Games Won')),
                          DropdownMenuItem(value: 'words', child: Text('Words Read')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value ?? 'name';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Sort Direction Toggle
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                        });
                      },
                      icon: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.blue.shade700,
                      ),
                      tooltip: _sortAscending ? 'Ascending' : 'Descending',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Users List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: FirestoreService.getAllUsers(),
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
                          size: isTablet ? 48 : 40,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error loading users: ${snapshot.error}',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.red.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                final allUsers = snapshot.data ?? [];
                final filteredUsers = _filterAndSortUsers(allUsers);
                
                if (allUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: isTablet ? 48 : 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: isTablet ? 48 : 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No users match your search',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  children: [
                    // Results summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${filteredUsers.length} of ${allUsers.length} users',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty || _roleFilter != 'all')
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _roleFilter = 'all';
                                  _sortBy = 'name';
                                  _sortAscending = true;
                                });
                              },
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Clear Filters'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Users list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _showUserDetailsDialog(user, isTablet),
                              leading: CircleAvatar(
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
                              title: Text(
                                user.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.emailAddress,
                                    style: TextStyle(
                                      fontSize: isTablet ? 14 : 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (user.isAdmin) 
                                    Text(
                                      'Administrator Account',
                                      style: TextStyle(
                                        fontSize: isTablet ? 12 : 10,
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else
                                    Row(
                                      children: [
                                        Text(
                                          'Games: ${user.gamesPlayed}',
                                          style: TextStyle(
                                            fontSize: isTablet ? 12 : 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Won: ${user.gamesWon}',
                                          style: TextStyle(
                                            fontSize: isTablet ? 12 : 10,
                                            color: Colors.green.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Words: ${user.wordsCorrect}',
                                          style: TextStyle(
                                            fontSize: isTablet ? 12 : 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'view':
                                      _showUserDetailsDialog(user, isTablet);
                                      break;
                                    case 'edit':
                                      _showEditUserDialog(user, isTablet);
                                      break;
                                    case 'delete':
                                      _confirmDeleteUser(user);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline),
                                        SizedBox(width: 12),
                                        Text('View Details'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 12),
                                        Text('Edit User'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 12),
                                        Text('Delete User', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: () => _launchGameboard(game),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
            ],
          ),
        ),
      ),
    );
  }

  void _launchGameboard(GameSessionModel game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text('Teacher View: ${game.gameName}'),
            backgroundColor: AppColors.adminPrimary,
            foregroundColor: AppColors.onPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: MultiplayerRollAndRead(
            user: widget.adminUser,
            gameSession: game,
            isTeacherMode: true,
          ),
        ),
      ),
    );
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

}