import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The reusable ✨ floating button that opens the AI assistant from anywhere.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open assistant',
      child: FloatingActionButton(
        heroTag: 'assistant_fab',
        backgroundColor: HousepitalColors.orange,
        foregroundColor: Colors.white,
        tooltip: 'Open assistant',
        onPressed: () => Navigator.pushNamed(context, '/assistant'),
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }
}
