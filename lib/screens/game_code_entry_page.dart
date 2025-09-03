import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../services/game_session_service.dart';
import 'student_selection_for_join.dart';

class GameCodeEntryPage extends StatefulWidget {
  const GameCodeEntryPage({super.key});

  @override
  State<GameCodeEntryPage> createState() => _GameCodeEntryPageState();
}

class _GameCodeEntryPageState extends State<GameCodeEntryPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateGameCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a game code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate that the game exists
      final game = await GameSessionService.getGameSession(code);
      if (game == null) {
        setState(() {
          _errorMessage = 'Game not found. Check the code and try again.';
          _isLoading = false;
        });
        return;
      }

      if (game.players.length >= game.maxPlayers) {
        setState(() {
          _errorMessage = 'This game is full. Try another code.';
          _isLoading = false;
        });
        return;
      }

      // Navigate to student selection with the game code
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudentSelectionForJoin(gameCode: code),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating game code: ${e.toString()}';
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Enter Game Code'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gamePrimary.withOpacity(0.1),
              AppColors.gameBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(keyboardVisible ? (isTablet ? 20 : 12) : (isTablet ? 40 : 24)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (keyboardVisible ? (isTablet ? 40 : 24) : (isTablet ? 80 : 48)),
                  ),
                  child: Column(
                    mainAxisAlignment: keyboardVisible ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(keyboardVisible ? (isTablet ? 25 : 20) : (isTablet ? 40 : 30)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gamePrimary.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!keyboardVisible) Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🎮', style: TextStyle(fontSize: isTablet ? 40 : 30)),
                                const SizedBox(width: 10),
                                Text('🎯', style: TextStyle(fontSize: isTablet ? 40 : 30)),
                                const SizedBox(width: 10),
                                Text('🌟', style: TextStyle(fontSize: isTablet ? 40 : 30)),
                              ],
                            ),
                            
                            SizedBox(height: keyboardVisible ? (isTablet ? 8 : 6) : (isTablet ? 20 : 16)),
                            
                            Text(
                              'Enter Game Code',
                              style: TextStyle(
                                fontSize: isTablet ? 28 : 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gamePrimary,
                              ),
                            ),
                            
                            SizedBox(height: isTablet ? 12 : 8),
                            
                            Text(
                              'Ask your teacher for the game code',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            
                            SizedBox(height: keyboardVisible ? (isTablet ? 20 : 16) : (isTablet ? 30 : 24)),
                            
                            // Game code input
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _errorMessage != null 
                                      ? AppColors.error 
                                      : AppColors.gamePrimary,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                color: AppColors.gameBackground,
                              ),
                              child: TextField(
                                controller: _codeController,
                                textAlign: TextAlign.center,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                                  UpperCaseTextFormatter(),
                                ],
                                maxLength: 6,
                                style: TextStyle(
                                  fontSize: isTablet ? 36 : 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: AppColors.gamePrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'ABC123',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary.withOpacity(0.5),
                                    letterSpacing: 4,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: isTablet ? 20 : 16,
                                    horizontal: 16,
                                  ),
                                  counterText: '',
                                ),
                                onChanged: (value) {
                                  if (_errorMessage != null) {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                onSubmitted: (_) => _validateGameCode(),
                              ),
                            ),
                            
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: AppColors.error),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            SizedBox(height: keyboardVisible ? (isTablet ? 20 : 16) : (isTablet ? 30 : 24)),
                            
                            // Continue button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _validateGameCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isTablet ? 20 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: isTablet ? 24 : 20,
                                        width: isTablet ? 24 : 20,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.arrow_forward,
                                            size: isTablet ? 28 : 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'CONTINUE',
                                            style: TextStyle(
                                              fontSize: isTablet ? 22 : 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      if (!keyboardVisible) SizedBox(height: isTablet ? 40 : 30),
                      
                      // Help section
                      if (!keyboardVisible) Container(
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: AppColors.warning,
                              size: isTablet ? 32 : 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Next Step',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'After entering the code, you\'ll select your name to join',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}