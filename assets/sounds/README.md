# Sound Effects

This directory should contain sound effect files for the Roll and Read game.

## Required Sound Files:
- `dice_roll.wav` or `dice_roll.mp3` - Dice rolling sound effect (1-2 seconds)
- `word_select.wav` or `word_select.mp3` - Word selection sound (short click/beep)
- `word_steal.wav` or `word_steal.mp3` - Word stealing sound (triumphant chime)

## Sound Specifications:
- Format: WAV or MP3
- Sample Rate: 44.1kHz recommended
- Bit Depth: 16-bit minimum
- Duration: 0.5-2 seconds for most effects
- Volume: Normalized to prevent clipping

## Implementation:
To enable real sound effects, uncomment the relevant lines in `lib/services/sound_service.dart` and add the sound files to this directory.