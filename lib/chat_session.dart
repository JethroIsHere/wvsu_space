import 'package:flutter/material.dart';

class ChatSessionScreen extends StatelessWidget {
  const ChatSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final mode = args?['mode'] ?? 'random';
    final keyword = args?['keyword'];
    final sessionId = args?['sessionId'];

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Session')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chat session stub'),
            const SizedBox(height: 8),
            Text('Mode: $mode'),
            if (sessionId != null) Text('Session: $sessionId'),
            if (keyword != null && (keyword as String).isNotEmpty)
              Text('Keyword: $keyword'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('End Session'),
            ),
          ],
        ),
      ),
    );
  }
}
