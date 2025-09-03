import 'package:flutter/material.dart';
import '../models/student_game_model.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/student_game_service.dart';
import '../services/game_state_service.dart';
import 'clean_multiplayer_screen.dart';

class StudentGameCompletionWrapper extends StatefulWidget {
  final StudentGameModel studentGame;
  final UserModel user;
  final GameSessionModel gameSession;
  final String gameName;

  const StudentGameCompletionWrapper({
    super.key,
    required this.studentGame,
    required this.user,
    required this.gameSession,
    required this.gameName,
  });

  @override
  State<StudentGameCompletionWrapper> createState() => _StudentGameCompletionWrapperState();
}

class _StudentGameCompletionWrapperState extends State<StudentGameCompletionWrapper> with WidgetsBindingObserver {
  late CleanMultiplayerScreen _gameWidget;
  bool _hasTrackedCompletion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _gameWidget = CleanMultiplayerScreen(
      user: widget.user,
      gameSession: widget.gameSession,
      isTeacherMode: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // When the game screen is disposed (user navigates away), 
    // track completion for teacher stats
    _trackGameCompletion();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track completion when app goes to background (covers home button, task switcher, etc.)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _trackGameCompletion();
    }
  }

  void _trackGameCompletion() async {
    if (_hasTrackedCompletion) return;
    _hasTrackedCompletion = true;

    try {
      // Get the actual game state to track real word counts from the shared game
      final gameState = await GameStateService.getGameState(widget.studentGame.gameId);
      final playerWordCounts = <String, int>{};
      
      if (gameState != null) {
        // Use actual scores from the shared game state
        for (final player in widget.studentGame.players) {
          playerWordCounts[player.playerId] = gameState.getPlayerScore(player.playerId);
        }
<<<<<<< HEAD
=======
        print('Got real word counts from shared game state: $playerWordCounts');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      } else {
        // Fallback: give participation points if we can't get game state
        for (final player in widget.studentGame.players) {
          playerWordCounts[player.playerId] = 3; // Participation score
        }
<<<<<<< HEAD
=======
        print('Using fallback participation scores');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      }
      
      await StudentGameService.completeStudentGame(
        gameId: widget.studentGame.gameId,
        playerWordCounts: playerWordCounts,
      );
      
<<<<<<< HEAD
    } catch (e) {
=======
      print('Tracked completion for student game ${widget.studentGame.gameId}');
    } catch (e) {
      print('Error tracking game completion: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Track completion when user navigates away
        _trackGameCompletion();
      },
      child: _gameWidget,
    );
  }
}