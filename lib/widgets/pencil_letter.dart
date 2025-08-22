import 'package:flutter/material.dart';

class PencilLetter extends StatelessWidget {
  final String letter;
  final double size;
  final double strokeWidth;

  const PencilLetter({
    super.key,
    required this.letter,
    this.size = 120,
    this.strokeWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.8, size),
      painter: PencilLetterPainter(
        letter: letter,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class PencilLetterPainter extends CustomPainter {
  final String letter;
  final double strokeWidth;

  PencilLetterPainter({
    required this.letter,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final blackPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pinkPaint = Paint()
      ..color = const Color(0xFFFF9494)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFFFFF9E6)
      ..style = PaintingStyle.fill;

    // Draw letter outline
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: size.height * 0.85,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position text in center
    final xOffset = (size.width - textPainter.width) / 2;
    final yOffset = (size.height - textPainter.height) / 2;

    // Create a path from the text
    final path = Path();
    
    // For simplicity, we'll draw the text with styled segments
    // This creates the pencil effect by drawing different parts in different colors
    
    // Draw background fill
    canvas.save();
    canvas.translate(xOffset, yOffset);
    
    // Draw the letter with gradient effect sections
    final totalHeight = size.height;
    final blackSection = totalHeight * 0.15;
    final yellowSection = totalHeight * 0.65;
    final pinkSection = totalHeight * 0.2;

    // Create clipping regions for each color section
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(-10, 0, size.width + 20, blackSection));
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(-10, blackSection, size.width + 20, yellowSection));
    final yellowTextPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: size.height * 0.85,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFD54F),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    yellowTextPainter.layout();
    yellowTextPainter.paint(canvas, Offset.zero);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(-10, blackSection + yellowSection, size.width + 20, pinkSection));
    final pinkTextPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: size.height * 0.85,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFF9494),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    pinkTextPainter.layout();
    pinkTextPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Draw outline
    final outlineTextPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: size.height * 0.85,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    outlineTextPainter.layout();
    outlineTextPainter.paint(canvas, Offset.zero);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PencilWordDisplay extends StatelessWidget {
  final String prefix;
  final String word;
  final double letterSize;
  final double spacing;

  const PencilWordDisplay({
    super.key,
    this.prefix = "Mrs.",
    required this.word,
    this.letterSize = 100,
    this.spacing = 70,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cursive prefix
        if (prefix.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Transform.rotate(
              angle: -0.05,
              child: Text(
                prefix,
                style: TextStyle(
                  fontSize: letterSize * 0.6,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        // Pencil letters
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < word.length; i++)
              Transform.translate(
                offset: Offset(i * spacing, 0),
                child: PencilLetter(
                  letter: word[i],
                  size: letterSize,
                ),
              ),
          ],
        ),
      ],
    );
  }
}