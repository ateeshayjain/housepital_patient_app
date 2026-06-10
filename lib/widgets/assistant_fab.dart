import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The reusable ✨ floating button that opens the AI assistant from anywhere.
///
/// Liquid Glass: tinted-glass control — translucent brand orange over a
/// backdrop blur, soft floating shadow. The icon stays white for contrast
/// (orange @85% over any background keeps the glyph clearly legible).
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open assistant',
      child: Tooltip(
        message: 'Open assistant',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: HousepitalColors.orange.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Material(
                color: HousepitalColors.orange.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pushNamed(context, '/assistant'),
                  child: const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
