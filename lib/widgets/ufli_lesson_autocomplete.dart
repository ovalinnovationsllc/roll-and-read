import 'package:flutter/material.dart';
import '../services/ufli_lessons_service.dart';

class UFLILessonAutocomplete extends StatelessWidget {
  final UFLILesson? selectedLesson;
  final Function(UFLILesson?) onLessonSelected;
  final String? hintText;

  const UFLILessonAutocomplete({
    Key? key,
    this.selectedLesson,
    required this.onLessonSelected,
    this.hintText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<UFLILesson>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return UFLILessonsService.getAllLessons().take(10);
            }
            return UFLILessonsService.searchLessons(textEditingValue.text);
          },
          displayStringForOption: (UFLILesson lesson) {
            final lessonNum = lesson.subLesson != null 
                ? '${lesson.lessonNumber}${lesson.subLesson}' 
                : lesson.lessonNumber.toString();
            return 'Lesson $lessonNum: ${lesson.displayName}';
          },
          onSelected: (UFLILesson lesson) {
            onLessonSelected(lesson);
          },
          fieldViewBuilder: (BuildContext context,
                             TextEditingController textEditingController,
                             FocusNode focusNode,
                             VoidCallback onFieldSubmitted) {
            // Set initial value if there's a selected lesson
            if (selectedLesson != null && textEditingController.text.isEmpty) {
              final lessonNum = selectedLesson!.subLesson != null 
                  ? '${selectedLesson!.lessonNumber}${selectedLesson!.subLesson}' 
                  : selectedLesson!.lessonNumber.toString();
              textEditingController.text = 'Lesson $lessonNum: ${selectedLesson!.displayName}';
            }

            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Search UFLI Lessons',
                prefixIcon: const Icon(Icons.search),
                hintText: hintText ?? 'Type to search lessons (e.g., "Short A", "Lesson 35")',
                border: const OutlineInputBorder(),
                suffixIcon: selectedLesson != null 
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          textEditingController.clear();
                          onLessonSelected(null);
                        },
                      )
                    : null,
              ),
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
            );
          },
          optionsViewBuilder: (BuildContext context,
                               AutocompleteOnSelected<UFLILesson> onSelected,
                               Iterable<UFLILesson> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300, maxWidth: 500),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final UFLILesson lesson = options.elementAt(index);
                      final lessonNum = lesson.subLesson != null 
                          ? '${lesson.lessonNumber}${lesson.subLesson}' 
                          : lesson.lessonNumber.toString();
                      return InkWell(
                        onTap: () {
                          onSelected(lesson);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lesson $lessonNum: ${lesson.displayName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lesson.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lesson.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lesson.skill,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
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
          },
        ),
        const SizedBox(height: 8),
        if (selectedLesson != null) ...[
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
                    Icon(Icons.check_circle, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected: ${selectedLesson!.displayName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedLesson!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            '💡 Start typing to search from 126 UFLI lessons (13-128)',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }
}