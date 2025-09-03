import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PlayerAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final Color playerColor;
  final double size;
  final bool isCurrentTurn;
  final bool isCurrentUser;
  final bool showName;
  final double? fontSize;

  const PlayerAvatar({
    super.key,
    required this.displayName,
    required this.playerColor,
    this.avatarUrl,
    this.size = 60,
    this.isCurrentTurn = false,
    this.isCurrentUser = false,
    this.showName = true,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize ?? size * 0.4;
    final nameFontSize = size * 0.2;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SIMPLE circle with initial
        Container(
          width: isCurrentTurn ? size * 1.2 : size,
          height: isCurrentTurn ? size * 1.2 : size,
          decoration: BoxDecoration(
            color: playerColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              avatarUrl ?? displayName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        
        // SIMPLE name label
        if (showName) ...[
          SizedBox(height: size * 0.1),
          Text(
            displayName,
            style: TextStyle(
              fontSize: isCurrentTurn ? nameFontSize * 1.3 : nameFontSize,
              fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
              color: isCurrentTurn ? playerColor : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Compact version for tight spaces
class PlayerAvatarCompact extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final Color playerColor;
  final double size;
  final bool isCurrentTurn;
  final bool isCurrentUser;

  const PlayerAvatarCompact({
    super.key,
    required this.displayName,
    required this.playerColor,
    this.avatarUrl,
    this.size = 40,
    this.isCurrentTurn = false,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: displayName,
      child: Container(
        width: isCurrentTurn ? size * 1.2 : size,
        height: isCurrentTurn ? size * 1.2 : size,
        decoration: BoxDecoration(
          color: playerColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            avatarUrl ?? displayName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}