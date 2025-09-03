import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class TTSHelper {
  static Future<void> logAvailableVoices() async {
    try {
      final FlutterTts tts = FlutterTts();
      List<dynamic> voices = await tts.getVoices;
      
      if (!kIsWeb) {
      } else {
      }
      
      // Filter for English voices
      final englishVoices = voices.where((voice) => 
        voice['locale']?.toString().contains('en') ?? false
      ).toList();
      
      
      // Look for Siri voices on iOS
      if (!kIsWeb && Platform.isIOS) {
        final siriVoices = englishVoices.where((voice) => 
          voice['name']?.toString().toLowerCase().contains('siri') ?? false
        ).toList();
        
        for (var voice in siriVoices) {
        }
      }
      
      // Show first 10 English voices for reference
      for (var i = 0; i < englishVoices.length && i < 10; i++) {
        final voice = englishVoices[i];
      }
      
    } catch (e) {
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
        return true;
      } catch (e) {
        // Try next voice
        continue;
      }
    }
    
    return false;
  }
}
