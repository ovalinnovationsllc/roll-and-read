import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/firestore_service.dart';
import '../services/game_session_service.dart';
import '../services/game_state_service.dart';
import '../services/ai_word_service.dart';
import '../models/game_state_model.dart';

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
    int maxPlayers = 2; // Default to 2 players

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
                  // No validator - game name is optional
                ),
                const SizedBox(height: 16),
                // Player count selection
                Row(
                  children: [
                    const Icon(Icons.group, color: Colors.grey),
                    const SizedBox(width: 12),
                    const Text('Number of Players:'),
                    const SizedBox(width: 16),
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
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Use AI Generated Words'),
                  subtitle: Text(useAIWords 
                      ? 'AI will create words based on your prompt'
                      : 'Use default word grid'),
                  value: useAIWords,
                  onChanged: (value) {
                    setDialogState(() {
                      useAIWords = value;
                    });
                  },
                  activeColor: Colors.blue.shade600,
                ),
                if (useAIWords) ...[
                  const SizedBox(height: 16),
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
                            // Only validate if AI words are enabled
                            if (!useAIWords) return null;
                            
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a prompt for AI word generation';
                            }
                            if (value.trim().length < 10) {
                              return 'Please provide a more detailed prompt';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          const SizedBox(height: 16), // Align with text field
                          _buildVoiceRecordButton(
                            controller: wordPromptController,
                            setDialogState: setDialogState,
                          ),
                        ],
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
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Game Instructions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• A unique 6-character Game ID will be generated\n'
                        '• Share the Game ID with students\n' 
                        '• Up to ${maxPlayers == 1 ? "1 student" : "2 students"} can join this game\n'
                        '• You can start the game once ${maxPlayers == 1 ? "the player joins" : "players join"}',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
                      // Validate based on current state
                      if (useAIWords) {
                        // Only validate form if AI words are enabled
                        if (!formKey.currentState!.validate()) return;
                      }
                      
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
                        
                        final gameSession = await GameSessionService.createGameSession(
                          createdBy: widget.adminUser.id,
                          gameName: gameName,
                          useAIWords: useAIWords,
                          aiPrompt: useAIWords ? wordPromptController.text.trim() : null,
                          difficulty: useAIWords ? selectedDifficulty : null,
                          maxPlayers: maxPlayers,
                        );
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Game "${gameSession.gameName}" created!\nGame ID: ${gameSession.gameId}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 8),
                              action: SnackBarAction(
                                label: 'COPY ID',
                                textColor: Colors.white,
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: gameSession.gameId));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Game ID ${gameSession.gameId} copied to clipboard!'),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                          // Games list will update automatically via StreamBuilder
                        }
                      } catch (e) {
                        print('Error creating game: $e');
                        if (mounted) {
                          Navigator.pop(context);
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

  Future<void> _startGame(GameSessionModel game) async {
    try {
      await GameSessionService.startGameSession(game.gameId);
      // Games list will update automatically via StreamBuilder
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game "${game.gameName}" has been started!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting game: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGame(GameSessionModel game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text('Are you sure you want to delete "${game.gameName}"?\n\nThis action cannot be undone.'),
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
      try {
        await GameSessionService.deleteGameSession(game.gameId);
        // Games list will update automatically via StreamBuilder
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game "${game.gameName}" deleted'),
              backgroundColor: AppColors.mediumBlue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error deleting game'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.adminBackground,
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
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

          // Pending Pronunciations Section - Always at top for immediate visibility
          StreamBuilder<List<GameSessionModel>>(
            stream: GameSessionService.listenToGamesByAdmin(widget.adminUser.id),
            builder: (context, gamesSnapshot) {
              if (!gamesSnapshot.hasData) return const SizedBox.shrink();
              
              final activeGames = gamesSnapshot.data!
                  .where((game) => game.status == GameStatus.inProgress)
                  .toList();
              
              if (activeGames.isEmpty) return const SizedBox.shrink();
              
              return _buildGlobalPronunciationsSection(activeGames, isTablet);
            },
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
            height: 200, // Fixed height for games section
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

                final games = snapshot.data ?? [];

                if (games.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.games_outlined,
                            size: isTablet ? 48 : 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No games created yet',
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
                                  Row(
                                    children: [
                                      Text(
                                        'Games: ${user.gamesPlayed}',
                                        style: TextStyle(
                                          fontSize: isTablet ? 12 : 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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
                                      _showUserDetails(user, isTablet);
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
                              onTap: () {
                                _showUserDetails(user, isTablet);
                              },
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
      case GameStatus.completed:
        statusColor = Colors.blue;
        statusText = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      case GameStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _showGameDetailsDialog(game, isTablet);
        },
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.gameName,
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: game.gameId));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Game ID ${game.gameId} copied!'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  game.gameId,
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.copy,
                                  size: isTablet ? 12 : 10,
                                  color: Colors.blue.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (game.players.isNotEmpty)
                          Text(
                            game.players.map((p) => p.displayName).join(', '),
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameDetailsDialog(GameSessionModel game, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<GameSessionModel?>(
        stream: GameSessionService.listenToGameSession(game.gameId),
        initialData: game,
        builder: (context, snapshot) {
          final currentGame = snapshot.data ?? game;
          
          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(currentGame.gameName)),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: currentGame.gameId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Game ID ${currentGame.gameId} copied to clipboard!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentGame.gameId,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.copy,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isTablet ? 500 : 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${currentGame.status.toString().split('.').last}'),
                  Text('Max Players: ${currentGame.maxPlayers}'),
                  Text('Current Players: ${currentGame.players.length}/${currentGame.maxPlayers}'),
                  if (currentGame.players.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Players:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...currentGame.players.map((player) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text('• ${player.displayName}'),
                    )).toList(),
                  ],
                  
                  // Show pending pronunciations for active games
                  if (currentGame.status == GameStatus.inProgress) ...[
                    const SizedBox(height: 16),
                    _buildPronunciationSection(currentGame),
                  ],
                  
                  const SizedBox(height: 8),
                  Text('Created: ${_formatDateTime(currentGame.createdAt)}'),
                  if (currentGame.startedAt != null)
                    Text('Started: ${_formatDateTime(currentGame.startedAt!)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (currentGame.status == GameStatus.waitingForPlayers && currentGame.players.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startGame(currentGame);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start Game'),
                ),
              if (currentGame.status == GameStatus.waitingForPlayers || currentGame.status == GameStatus.inProgress)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteGame(currentGame);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isTablet,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: isTablet ? 28 : 24,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(UserModel user, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              user.isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: user.isAdmin ? Colors.red.shade700 : Colors.green.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                user.displayName,
                style: TextStyle(fontSize: isTablet ? 20 : 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Email', user.emailAddress, isTablet),
                    _buildDetailRow('PIN', user.pin, isTablet),
                    _buildDetailRow('Role', user.isAdmin ? 'Teacher' : 'Student', isTablet),
                    _buildDetailRow(
                      'Member Since',
                      _formatDateTime(user.createdAt),
                      isTablet,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Gaming Statistics Section
              if (!user.isAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: isTablet ? 20 : 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Gaming Statistics',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              'Games Played',
                              user.gamesPlayed.toString(),
                              Icons.videogame_asset,
                              Colors.green,
                              isTablet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatBox(
                              'Games Won',
                              user.gamesWon.toString(),
                              Icons.emoji_events,
                              AppColors.mediumBlue,
                              isTablet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              'Words Read',
                              user.wordsCorrect.toString(),
                              Icons.abc,
                              Colors.purple,
                              isTablet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatBox(
                              'Win Rate',
                              user.gamesPlayed > 0 
                                ? '${(user.gamesWon / user.gamesPlayed * 100).toStringAsFixed(1)}%'
                                : '0%',
                              Icons.trending_up,
                              Colors.red,
                              isTablet,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.red.shade600,
                        size: isTablet ? 24 : 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This user has administrator privileges and can create games and manage users.',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: AppColors.adminPrimary,
                            fontStyle: FontStyle.italic,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isTablet ? 15 : 13,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 15 : 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    int hour = dateTime.hour;
    String period = 'AM';
    if (hour >= 12) {
      period = 'PM';
      if (hour > 12) hour -= 12;
    }
    if (hour == 0) hour = 12;
    
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${hour}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  
  Widget _buildPronunciationSection(GameSessionModel game) {
    return StreamBuilder<GameStateModel?>(
      stream: GameStateService.getGameStateStream(game.gameId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final gameState = snapshot.data!;
        final pendingPronunciations = gameState.pendingPronunciations;
        
        if (pendingPronunciations.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Pronunciations:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...pendingPronunciations.entries.map((entry) {
              final cellKey = entry.key;
              final attempt = entry.value;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${attempt.playerName} → "${attempt.word}"',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approvePronunciation(game.gameId, cellKey, game.playerIds),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Correct'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _rejectPronunciation(game.gameId, cellKey, game.playerIds),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Wrong'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
  
  Future<void> _approvePronunciation(String gameId, String cellKey, List<String> playerIds) async {
    try {
      await GameStateService.approvePronunciation(
        gameId: gameId, 
        cellKey: cellKey, 
        playerIds: playerIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pronunciation approved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _rejectPronunciation(String gameId, String cellKey, List<String> playerIds) async {
    try {
      await GameStateService.rejectPronunciation(
        gameId: gameId, 
        cellKey: cellKey, 
        playerIds: playerIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pronunciation rejected.'),
            backgroundColor: AppColors.mediumBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: isTablet ? 24 : 20,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalPronunciationsSection(List<GameSessionModel> activeGames, bool isTablet) {
    return StreamBuilder<List<GameStateModel?>>(
      stream: _combineGameStateStreams(activeGames),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        // Collect all pending pronunciations from all games
        final allPendingPronunciations = <Map<String, dynamic>>[];
        
        for (int i = 0; i < activeGames.length; i++) {
          final gameState = snapshot.data![i];
          if (gameState != null && gameState.pendingPronunciations.isNotEmpty) {
            gameState.pendingPronunciations.forEach((cellKey, attempt) {
              allPendingPronunciations.add({
                'game': activeGames[i],
                'cellKey': cellKey,
                'attempt': attempt,
              });
            });
          }
        }
        
        if (allPendingPronunciations.isEmpty) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.priority_high,
                      color: Colors.red.shade700,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pronunciation Approvals Needed',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Text(
                          '${allPendingPronunciations.length} student${allPendingPronunciations.length == 1 ? '' : 's'} waiting for your decision',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...allPendingPronunciations.map((data) {
                final game = data['game'] as GameSessionModel;
                final cellKey = data['cellKey'] as String;
                final attempt = data['attempt'] as PronunciationAttempt;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${attempt.playerName} → "${attempt.word}"',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Game: ${game.gameName}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 12 : 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approvePronunciation(game.gameId, cellKey, game.playerIds),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Correct'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _rejectPronunciation(game.gameId, cellKey, game.playerIds),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Wrong'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Stream<List<GameStateModel?>> _combineGameStateStreams(List<GameSessionModel> games) {
    if (games.isEmpty) {
      return Stream.value([]);
    }
    
    final streams = games.map((game) => 
      GameStateService.getGameStateStream(game.gameId)
    ).toList();
    
    return Stream.periodic(const Duration(milliseconds: 500), (i) => null)
        .asyncMap((_) async {
          final futures = streams.map((stream) => stream.first).toList();
          return await Future.wait(futures);
        });
  }

  Widget _buildVoiceRecordButton({
    required TextEditingController controller,
    required Function(VoidCallback) setDialogState,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isRecording = false;
        
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecording 
                ? Colors.red.withOpacity(0.1)
                : AppColors.gamePrimary.withOpacity(0.1),
          ),
          child: IconButton(
            onPressed: () async {
              if (!isRecording) {
                await _startVoiceRecording(
                  controller: controller,
                  onResult: (text) {
                    setDialogState(() {
                      // Text already set in controller by onResult callback
                    });
                  },
                  onStart: () {
                    setState(() {
                      isRecording = true;
                    });
                  },
                  onStop: () {
                    setState(() {
                      isRecording = false;
                    });
                  },
                );
              } else {
                _stopVoiceRecording();
                setState(() {
                  isRecording = false;
                });
              }
            },
            icon: Icon(
              isRecording ? Icons.stop : Icons.mic,
              color: isRecording ? Colors.red : AppColors.gamePrimary,
              size: 24,
            ),
            tooltip: isRecording ? 'Stop Recording' : 'Voice Input',
          ),
        );
      },
    );
  }
}