import '../services/firestore_service.dart';
import '../models/player_colors.dart';
import '../utils/safe_print.dart';

/// Utility to fix duplicate student colors for a teacher
class ColorFixer {
  static Future<void> fixDuplicateColorsForTeacher(String teacherId) async {
    safePrint('🔧 Starting color fix for teacher $teacherId');
    
    try {
      // Get all students for this teacher
      final students = await FirestoreService.getStudentsForTeacher(teacherId);
      safePrint('👥 Found ${students.length} students');
      
      // Group students by color to find duplicates
      final Map<int, List<String>> colorGroups = {};
      for (final student in students) {
        final colorValue = student.playerColor.value;
        if (!colorGroups.containsKey(colorValue)) {
          colorGroups[colorValue] = [];
        }
        colorGroups[colorValue]!.add(student.studentId);
      }
      
      // Find colors with duplicates
      final duplicateColors = colorGroups.entries
          .where((entry) => entry.value.length > 1)
          .toList();
      
      safePrint('🎨 Found ${duplicateColors.length} colors with duplicates');
      
      if (duplicateColors.isEmpty) {
        safePrint('✅ No duplicate colors found!');
        return;
      }
      
      // Get available colors
      final availableColors = PlayerColors.getAvailableColorsForStudents()
          .map((pc) => pc.color)
          .toList();
      
      // Track used colors
      final Set<int> usedColorValues = {};
      
      // For each duplicate color group, keep the first student and reassign others
      for (final duplicateGroup in duplicateColors) {
        final duplicateStudentIds = duplicateGroup.value;
        final originalColor = duplicateGroup.key;
        
        safePrint('🔄 Fixing duplicate color ${originalColor.toRadixString(16)} for students: $duplicateStudentIds');
        
        // Keep the first student with this color
        usedColorValues.add(originalColor);
        
        // Reassign colors for the rest
        for (int i = 1; i < duplicateStudentIds.length; i++) {
          final studentId = duplicateStudentIds[i];
          
          // Find next available color
          final newColor = availableColors.firstWhere(
            (color) => !usedColorValues.contains(color.value),
            orElse: () => availableColors.first, // Fallback if we run out
          );
          
          usedColorValues.add(newColor.value);
          
          // Update the student's color in the database
          await FirestoreService.updateStudentColor(studentId, newColor);
          safePrint('✅ Updated student $studentId to color ${newColor.value.toRadixString(16)}');
        }
      }
      
      safePrint('🎉 Color fix completed successfully!');
      
    } catch (e) {
      safePrint('❌ Error fixing colors: $e');
      rethrow;
    }
  }
}