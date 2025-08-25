import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/safe_print.dart';

class SoundService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _soundEnabled = true;

  // Enable/disable sounds
  static void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  static bool get isSoundEnabled => _soundEnabled;

  // Play dice rolling sound
  static Future<void> playDiceRoll() async {
    if (!_soundEnabled) return;
    
    try {
      // Play the dice rolling sound file
      await _audioPlayer.play(AssetSource('sounds/dice_rolling.mp3'));
    } catch (e) {
      safeError('Error playing dice roll sound: $e');
      // Fallback to haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  // Play word selection sound
  static Future<void> playWordSelect() async {
    if (!_soundEnabled) return;
    
    try {
      HapticFeedback.selectionClick();
      await _playSimpleBeep();
    } catch (e) {
      safeError('Error playing word select sound: $e');
    }
  }

  // Play word steal sound
  static Future<void> playWordSteal() async {
    if (!_soundEnabled) return;
    
    try {
      // Play two quick haptic feedbacks and beeps for stealing
      HapticFeedback.mediumImpact();
      await _playSimpleBeep();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.mediumImpact();
      await _playSimpleBeep();
    } catch (e) {
      safeError('Error playing word steal sound: $e');
    }
  }

  // Play a simple beep sound using a data URI
  static Future<void> _playSimpleBeep() async {
    try {
      // Simple beep sound as data URI
      const String beepSound = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSiGye/cdyEE';
      await _audioPlayer.play(UrlSource(beepSound));
    } catch (e) {
      // If audio fails, just use haptic feedback
      safePrint('Audio playback failed, using haptic only: $e');
    }
  }

  // Stop all sounds (not applicable for system sounds)
  static Future<void> stopAllSounds() async {
    // System sounds can't be stopped once started
  }

  // Dispose (not needed for system sounds)
  static Future<void> dispose() async {
    // No cleanup needed for system sounds
  }
}