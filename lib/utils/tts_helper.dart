import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class TTSHelper {
  static Future<void> logAvailableVoices() async {
    try {
      final FlutterTts tts = FlutterTts();
      List<dynamic> voices = await tts.getVoices;
      
      print('===== Available TTS Voices =====');
      print('Total voices found: ${voices.length}');
      if (!kIsWeb) {
        print('Platform: ${Platform.operatingSystem}');
      } else {
        print('Platform: Web');
      }
      print('');
      
      // Filter for English voices
      final englishVoices = voices.where((voice) => 
        voice['locale']?.toString().contains('en') ?? false
      ).toList();
      
      print('English voices: ${englishVoices.length}');
      
      // Look for Siri voices on iOS
      if (!kIsWeb && Platform.isIOS) {
        final siriVoices = englishVoices.where((voice) => 
          voice['name']?.toString().toLowerCase().contains('siri') ?? false
        ).toList();
        
        print('\n--- Siri Voices ---');
        for (var voice in siriVoices) {
          print('Name: ${voice['name']}');
          print('Locale: ${voice['locale']}');
          print('');
        }
      }
      
      // Show first 10 English voices for reference
      print('\n--- Sample English Voices ---');
      for (var i = 0; i < englishVoices.length && i < 10; i++) {
        final voice = englishVoices[i];
        print('${i + 1}. Name: ${voice['name']}, Locale: ${voice['locale']}');
      }
      
      print('================================');
    } catch (e) {
      print('Error getting voices: $e');
    }
  }
  
  static Future<bool> setIOSVoice(FlutterTts tts) async {
    if (kIsWeb || !Platform.isIOS) return false;
    
    // List of Siri voice 3 identifiers to try
    // Note: Siri voice numbering and availability varies by iOS version
    final siriVoiceNames = [
      // iOS 15+ Siri voices (Voice 3 is typically the third option)
      "com.apple.voice.compact.en-US.Siri_Female_en-US_compact",
      "com.apple.ttsbundle.siri_female_en-US_compact",
      "com.apple.ttsbundle.siri_Nicky_en-US_compact",
      "com.apple.voice.enhanced.en-US.Siri",
      "com.apple.ttsbundle.siri_Martha_en-US_compact",
      
      // Try generic Siri names
      "Siri Female (United States)",
      "Siri Voice 3",
      "Nicky",
      
      // Fallback to other good voices
      "Samantha",
      "Alex",
      "Victoria",
    ];
    
    for (final voiceName in siriVoiceNames) {
      try {
        await tts.setVoice({"name": voiceName, "locale": "en-US"});
        print('Successfully set iOS voice to: $voiceName');
        return true;
      } catch (e) {
        // Try next voice
        continue;
      }
    }
    
    print('Could not set any preferred iOS voice, using system default');
    return false;
  }
}