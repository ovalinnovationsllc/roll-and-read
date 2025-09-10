import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/ufli_import_service.dart';
import '../services/pdf_extraction_service.dart';
import '../services/custom_word_list_service.dart';
import '../services/session_service.dart';

class UFLIImportScreen extends StatefulWidget {
  const UFLIImportScreen({Key? key}) : super(key: key);

  @override
  State<UFLIImportScreen> createState() => _UFLIImportScreenState();
}

class _UFLIImportScreenState extends State<UFLIImportScreen> {
  final TextEditingController _textController = TextEditingController();
  ImportStatusSummary? _importStatus;
  ImportResult? _lastImportResult;
  bool _isImporting = false;
  String _selectedImportFormat = 'Plain Text';

  final List<String> _importFormats = ['Plain Text', 'CSV'];

  @override
  void initState() {
    super.initState();
    _updateImportStatus();
  }

  void _updateImportStatus() {
    setState(() {
      _importStatus = UFLIImportService.getImportStatus();
    });
  }

  Future<void> _importWordLists() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter word lists to import')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _lastImportResult = null;
    });

    try {
      final currentUser = await SessionService.getUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to create word lists'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }
      
      // Parse the text to extract words
      final lines = _textController.text.trim().split('\n');
      final words = <String>[];
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty || trimmedLine.startsWith('[') || trimmedLine.startsWith('#')) {
          continue; // Skip empty lines, headers, and comments
        }
        
        // Handle CSV format
        if (_selectedImportFormat == 'CSV') {
          final csvWords = trimmedLine.split(',').map((w) => w.trim()).where((w) => w.isNotEmpty);
          words.addAll(csvWords);
        } else {
          // Plain text - each line is a word
          words.add(trimmedLine);
        }
      }
      
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No words found in the text'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }
      
      // Show dialog to get custom title
      final customDetails = await _showCustomListDialog(words);
      
      if (customDetails != null) {
        await CustomWordListService.createWordList(
          title: customDetails['title']!,
          words: words,
          createdBy: currentUser.id,
          gradeLevel: customDetails['gradeLevel']!.isEmpty ? null : customDetails['gradeLevel'],
          description: customDetails['description']!.isEmpty ? null : customDetails['description'],
        );
        
        setState(() {
          _isImporting = false;
          _textController.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created word list "${customDetails['title']}" with ${words.length} words'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isImporting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _lastImportResult = ImportResult(
          success: false,
          message: 'Import failed: $e',
          importedLists: [],
          skippedLists: [],
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating word list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _clearText() {
    setState(() {
      _textController.clear();
      _lastImportResult = null;
    });
  }

  Future<void> _uploadPDF() async {
    // Check if already importing
    if (_isImporting) return;
    
    setState(() {
      _isImporting = true;
      _lastImportResult = null;
    });

    try {
      print('Starting PDF upload process...');
      
      // Show loading indicator while processing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening file picker...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Extract text from PDF
      print('Calling PDFExtractionService.pickAndExtractPDF()...');
      final result = await PDFExtractionService.pickAndExtractPDF();
      print('PDF extraction result: ${result.success}, message: ${result.message}');
      
      if (!mounted) return;
      
      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isImporting = false;
          });
        }
        return;
      }

      // Get all extracted words
      final allWords = result.extractedWords.values.expand((words) => words).toList();
      
      // Show dialog to get custom title and details
      final customDetails = await _showCustomListDialog(allWords);
      
      if (customDetails != null) {
        // Create custom word list directly
        try {
          final currentUser = await SessionService.getUser();
          if (currentUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please log in to create word lists'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isImporting = false;
            });
            return;
          }
          
          await CustomWordListService.createWordList(
            title: customDetails['title']!,
            words: allWords,
            createdBy: currentUser.id,
            gradeLevel: customDetails['gradeLevel']!.isEmpty ? null : customDetails['gradeLevel'],
            description: customDetails['description']!.isEmpty ? null : customDetails['description'],
          );
          
          setState(() {
            _isImporting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created word list "${customDetails['title']}" with ${allWords.length} words'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to the previous screen
          Navigator.of(context).pop();
        } catch (e) {
          setState(() {
            _isImporting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating word list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          _isImporting = false;
        });
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, String>?> _showCustomListDialog(List<String> words) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedGradeLevel;

    return showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Add listener to title controller to update button state
          void updateButtonState() {
            setDialogState(() {});
          }
          
          titleController.addListener(updateButtonState);
          
          return AlertDialog(
          title: const Text('Create Custom Word List'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Found ${words.length} words. Give your word list a title:'),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'List Title *',
                    hintText: 'e.g., "My CVC Words", "Reading Practice Week 1"',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedGradeLevel,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pre-K', child: Text('Pre-K')),
                    DropdownMenuItem(value: 'Kindergarten', child: Text('Kindergarten')),
                    DropdownMenuItem(value: '1st Grade', child: Text('1st Grade')),
                    DropdownMenuItem(value: '2nd Grade', child: Text('2nd Grade')),
                    DropdownMenuItem(value: '3rd Grade', child: Text('3rd Grade')),
                    DropdownMenuItem(value: 'Elementary', child: Text('Elementary')),
                    DropdownMenuItem(value: 'Middle School', child: Text('Middle School')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedGradeLevel = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Notes about this word list...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: titleController.text.trim().isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'title': titleController.text.trim(),
                        'gradeLevel': selectedGradeLevel ?? '',
                        'description': descriptionController.text.trim(),
                      });
                    },
              child: const Text('Create'),
            ),
          ],
          );
        },
      ),
    ).then((result) {
      // Clean up listener when dialog closes
      titleController.dispose();
      descriptionController.dispose();
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word List Import'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Import Format Selection
            Row(
              children: [
                Text(
                  'Import Format:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedImportFormat,
                  items: _importFormats.map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Text(format),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedImportFormat = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _uploadPDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Upload PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearText,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text Input
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Word Lists Data',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: 'Paste your word lists here...',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Import Button
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _importWordLists,
              icon: _isImporting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isImporting ? 'Importing...' : 'Import Word Lists'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            // Import Result
            if (_lastImportResult != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  color: _lastImportResult!.success 
                      ? Colors.green[50] 
                      : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _lastImportResult!.success 
                                  ? Icons.check_circle 
                                  : Icons.error,
                              color: _lastImportResult!.success 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Import Result',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _lastImportResult!.toString(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Word List Import Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How to create custom word lists:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('EASIEST METHOD - Upload PDF:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('1. Click "Upload PDF" button'),
              const Text('2. Select your PDF file (UFLI or any other)'),
              const Text('3. Words will be automatically extracted'),
              const Text('4. Provide a custom title for your word list'),
              const Text('5. Optionally add grade level and description'),
              const Text('6. Click "Create" to save'),
              const SizedBox(height: 8),
              const Text('MANUAL METHOD:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('1. Type or paste your words in the text area'),
              const SizedBox(height: 8),
              const Text('2. Format options:'),
              const SizedBox(height: 4),
              const Text('Plain Text: One word per line'),
              const Text('CSV: Words separated by commas'),
              const SizedBox(height: 8),
              const Text('Example Plain Text:'),
              const Text('cat\nhat\nbat\nmat', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 8),
              const Text('Example CSV:'),
              const Text('cat, hat, bat, mat', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 8),
              const Text('3. Click "Import Word Lists"'),
              const Text('4. Provide a custom title for your list'),
              const Text('5. Click "Create" to save'),
              const SizedBox(height: 8),
              const Text('Your custom word lists will be saved and available when creating games.', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}