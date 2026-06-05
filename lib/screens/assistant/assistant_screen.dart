import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/assistant_models.dart';
import '../../providers/assistant_provider.dart';
import 'assistant_executor.dart' show CallAction;

/// Full-screen Hinglish assistant: chat bubbles, a hard-confirm card for
/// side-effectful actions (call), a text field + mic input bar, and a
/// thinking / listening indicator.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Wire the side-effect callbacks once the screen is mounted. The provider
    // never performs side effects itself (keeps it testable) — the UI does.
    final provider = context.read<AssistantProvider>();
    provider.onPlaceCall = _dial;
    provider.onNavigate = _navigateTo;
  }

  Future<void> _dial(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // Dial unavailable (e.g. web / no dialer) — fail silently, never crash.
    }
  }

  void _navigateTo(String route) {
    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(AssistantProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    provider.sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sahayak'),
        backgroundColor: HousepitalColors.orange,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AssistantProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Expanded(
                child: provider.messages.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, i) =>
                            _Bubble(message: provider.messages[i]),
                      ),
              ),
              if (provider.isThinking) const _ThinkingIndicator(),
              if (provider.pendingConfirmation != null)
                _ConfirmCard(provider: provider),
              _InputBar(
                controller: _controller,
                provider: provider,
                onSend: () => _send(provider),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 48, color: HousepitalColors.orange),
            SizedBox(height: 16),
            Text(
              'Namaste! Main aapki madad ke liye hoon.\n'
              'Pooch sakte hain: "Iss mahine ka bill kitna hai?" ya '
              '"Health manager ko call karo".',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final AssistantMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser
              ? HousepitalColors.orange
              : HousepitalColors.greyLighter,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : HousepitalColors.black,
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Soch raha hoon…'),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final AssistantProvider provider;
  const _ConfirmCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final pending = provider.pendingConfirmation!;
    final icon = pending is CallAction
        ? Icons.phone
        : Icons.check_circle_outline;
    return Card(
      margin: const EdgeInsets.all(12),
      color: HousepitalColors.orangeLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: HousepitalColors.orangeDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pending.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: provider.cancelPending,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HousepitalColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: provider.confirmPending,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final AssistantProvider provider;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.provider,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final listening = provider.isListening;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: listening
                      ? 'Sun raha hoon…'
                      : 'Type karein ya mic dabayein…',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              iconSize: 28,
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: listening ? 'Stop listening' : 'Speak',
              color: listening ? HousepitalColors.error : HousepitalColors.orange,
              icon: Icon(listening ? Icons.stop : Icons.mic),
              onPressed: () =>
                  listening ? provider.stopVoice() : provider.startVoice(),
            ),
            IconButton(
              iconSize: 28,
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'Send',
              color: HousepitalColors.orange,
              icon: const Icon(Icons.send),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
