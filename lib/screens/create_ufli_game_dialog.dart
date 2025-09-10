import 'package:flutter/material.dart';
import '../services/ufli_lessons_service.dart';
import '../widgets/ufli_lesson_autocomplete.dart';
import '../services/game_session_service.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../config/app_colors.dart';

class CreateUFLIGameDialog extends StatefulWidget {
  final UserModel adminUser;
  final Function(GameSessionModel) onGameCreated;

  const CreateUFLIGameDialog({
    Key? key,
    required this.adminUser,
    required this.onGameCreated,
  }) : super(key: key);

  @override
  State<CreateUFLIGameDialog> createState() => _CreateUFLIGameDialogState();
}

class _CreateUFLIGameDialogState extends State<CreateUFLIGameDialog> {
  bool isCreating = false;
  String wordListMode = 'default'; // 'default' or 'preset'
  int maxPlayers = 2; // Default to 2 players
  UFLILesson? selectedUFLILesson;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Game'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Word list selection
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'default',
                label: Text('Quick'),
              ),
              ButtonSegment<String>(
                value: 'preset',
                label: Text('UFLI Lessons'),
              ),
            ],
            selected: {wordListMode},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                wordListMode = newSelection.first;
                selectedUFLILesson = null; // Reset lesson selection when switching modes
              });
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
              setState(() {
                maxPlayers = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Show options based on selected mode
          if (wordListMode == 'preset') ...[
            UFLILessonAutocomplete(
              selectedLesson: selectedUFLILesson,
              onLessonSelected: (UFLILesson? lesson) {
                setState(() {
                  selectedUFLILesson = lesson;
                });
              },
            ),
          ] else ...[
            Text(
              '✨ Quick mode uses safe preset words for immediate gameplay',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isCreating || (wordListMode == 'preset' && selectedUFLILesson == null) 
              ? null 
              : _createGame,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: isCreating 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Game'),
        ),
      ],
    );
  }

  Future<void> _createGame() async {
    if (isCreating) return;

    setState(() {
      isCreating = true;
    });

    try {
      List<List<String>> wordGrid;
      String gameName;

      if (wordListMode == 'preset' && selectedUFLILesson != null) {
        // Create UFLI lesson-based game
        final lessonNum = selectedUFLILesson!.subLesson != null 
            ? '${selectedUFLILesson!.lessonNumber}${selectedUFLILesson!.subLesson}' 
            : selectedUFLILesson!.lessonNumber.toString();
        
        gameName = 'Lesson $lessonNum: ${selectedUFLILesson!.displayName}';
        
        // For now, we'll generate a grid with safe words 
        // In the future, this should extract words from the PDF
        wordGrid = _generateSafeWordGrid();
      } else {
        // Quick mode
        gameName = 'Quick Game';
        wordGrid = _generateSafeWordGrid();
      }

      // Create the game session
      final gameSession = await GameSessionService.createGameSession(
        createdBy: widget.adminUser.id,
        gameName: gameName,
        wordGrid: wordGrid,
        maxPlayers: maxPlayers,
      );

      // Navigate back and notify parent
      Navigator.pop(context);
      widget.onGameCreated(gameSession);

    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isCreating = false;
        });
      }
    }
  }

  List<List<String>> _generateSafeWordGrid() {
    // Generate a simple 6x6 grid with safe words
    final words = [
      'cat', 'dog', 'sun', 'run', 'fun', 'big',
      'red', 'bed', 'pen', 'ten', 'hen', 'men',
      'sit', 'hit', 'pit', 'bit', 'fit', 'wit',
      'top', 'hop', 'pop', 'mop', 'cop', 'not',
      'bug', 'hug', 'mug', 'rug', 'jug', 'dug',
      'hat', 'bat', 'rat', 'mat', 'sat', 'pat',
    ];

    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        row.add(words[index]);
      }
      grid.add(row);
    }
    
    return grid;
  }
}