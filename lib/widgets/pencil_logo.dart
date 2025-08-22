import 'package:flutter/material.dart';

class PencilLogo extends StatelessWidget {
  final String teacherName;
  final double fontSize;
  
  const PencilLogo({
    super.key,
    this.teacherName = "Mrs. ELSON",
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shadow/outline effect
        Text(
          teacherName,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.black87,
            letterSpacing: fontSize * 0.15,
          ),
        ),
        // Main text with gradient
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87,
              const Color(0xFFFFC107), // Yellow/pencil color
              const Color(0xFFFFC107),
              const Color(0xFFFF9494), // Pink eraser color
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ).createShader(bounds),
          child: Text(
            teacherName,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: fontSize * 0.15,
            ),
          ),
        ),
      ],
    );
  }
}

class PencilStyleLogo extends StatelessWidget {
  final String prefix;
  final String name;
  final double fontSize;
  
  const PencilStyleLogo({
    super.key,
    this.prefix = "Mrs.",
    this.name = "ELSON",
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Prefix with cursive style
        Transform.rotate(
          angle: -0.05,
          child: Text(
            prefix,
            style: TextStyle(
              fontSize: fontSize * 0.8,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Main name with pencil effect
        Stack(
          children: [
            // Pencil body effect
            Text(
              name,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: fontSize * 0.2,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = Colors.black87,
              ),
            ),
            // Fill with gradient
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87,
                  const Color(0xFFFFD54F),
                  const Color(0xFFFFD54F),
                  const Color(0xFFFFAB91),
                ],
                stops: const [0.0, 0.25, 0.75, 1.0],
              ).createShader(bounds),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: fontSize * 0.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}