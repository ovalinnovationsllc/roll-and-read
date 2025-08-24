import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/firestore_service.dart';
import '../services/game_session_service.dart';
import '../services/ai_word_service.dart';

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
  List<GameSessionModel> _games = [];
  bool _loadingGames = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadGames();
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

  Future<void> _loadGames() async {
    final games = await GameSessionService.getGamesByAdmin(widget.adminUser.id);
    if (mounted) {
      setState(() {
        _games = games;
        _loadingGames = false;
      });
    }
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
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Admin User'),
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
                                backgroundColor: Colors.orange,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  TextFormField(
                    controller: wordPromptController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Word Prompt for AI',
                      hintText: 'Example: "Animals that live in the ocean" or "Words with long vowel sounds"',
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Game ID ${gameSession.gameId} copied to clipboard!'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                          // Refresh games list
                          _loadGames();
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
      _loadGames(); // Refresh the games list
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
              backgroundColor: Colors.red.shade600,
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
        _loadGames(); // Refresh the games list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game "${game.gameName}" deleted'),
              backgroundColor: Colors.orange,
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
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
                _loadingGames = true;
              });
              _loadStatistics();
              _loadGames();
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
                        backgroundColor: Colors.red.shade700,
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
      body: Column(
        children: [
          // Admin Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.adminUser.displayName}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.adminUser.emailAddress,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
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

          // Games List
          if (_loadingGames)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 200, // Fixed height for games section
              child: _games.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _games.length,
                      itemBuilder: (context, index) {
                        final game = _games[index];
                        return _buildGameCard(game, isTablet);
                      },
                    ),
            ),
          
          // Users List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Users',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Swipe left to manage',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: Key(user.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: Text(
                                    'Are you sure you want to delete ${user.displayName}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.id)
                              .delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${user.displayName} deleted'),
                            ),
                          );
                        },
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
                          subtitle: Text(
                            user.emailAddress,
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Games: ${user.gamesPlayed}',
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Words: ${user.wordsCorrect}',
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            _showUserDetails(user, isTablet);
                          },
                        ),
                      ),
                    );
                  },
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
        statusColor = Colors.orange;
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Game ID ${game.gameId} copied!'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.blue,
                              ),
                            );
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
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(game.gameName)),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: game.gameId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Game ID ${game.gameId} copied to clipboard!'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.blue,
                  ),
                );
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
                      game.gameId,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${game.status.toString().split('.').last}'),
            Text('Max Players: ${game.maxPlayers}'),
            Text('Current Players: ${game.players.length}/${game.maxPlayers}'),
            if (game.players.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Players:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...game.players.map((player) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${player.displayName}'),
              )).toList(),
            ],
            const SizedBox(height: 8),
            Text('Created: ${_formatDateTime(game.createdAt)}'),
            if (game.startedAt != null)
              Text('Started: ${_formatDateTime(game.startedAt!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (game.status == GameStatus.waitingForPlayers && game.players.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startGame(game);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Game'),
            ),
          if (game.status == GameStatus.waitingForPlayers || game.status == GameStatus.inProgress)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteGame(game);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
        ],
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
                    _buildDetailRow('Role', user.isAdmin ? 'Admin' : 'Student', isTablet),
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
                              Colors.orange,
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
                            color: Colors.red.shade700,
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
          if (!user.isAdmin)
            ElevatedButton(
              onPressed: () async {
                final updatedUser = user.copyWith(isAdmin: true);
                await FirestoreService.updateUser(updatedUser);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.displayName} is now an admin'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Make Admin'),
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
}