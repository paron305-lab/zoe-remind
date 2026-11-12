import 'package:flutter/material.dart';
import 'package:zoe_remind/features/chat/controllers/zoe_chat_controller.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

enum ChatMenuAction { clear, history }

/// White header: Zoe avatar + name + status · language button · "…" menu.
/// Sumasampa sa likod ng status bar (walang SafeArea sa shell).
class ChatHeader extends StatelessWidget {
  final ZoeChatStatus status;
  final VoidCallback onLanguageTap;
  final ValueChanged<ChatMenuAction> onMenu;

  const ChatHeader({
    super.key,
    required this.status,
    required this.onLanguageTap,
    required this.onMenu,
  });

  (String, Color) get _statusLabel => switch (status) {
        ZoeChatStatus.ready => ('online · offline AI', ChatColors.online),
        ZoeChatStatus.thinking => ('Thinking…', HomeColors.lavender),
        ZoeChatStatus.preview => ('UI preview · no AI yet', ChatColors.amber),
        ZoeChatStatus.downloading => ('Getting my brain ready…', HomeColors.sky),
        ZoeChatStatus.noBrain => ('Sleeping · no brain yet', HomeColors.navInactive),
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final (label, color) = _statusLabel;

    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 8, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: HomeColors.divider)),
      ),
      child: Row(
        children: [
          ChatAvatar(
            size: 50,
            asset: status == ZoeChatStatus.thinking
                ? 'assets/images/zoe/thinking/03_thinking (2).png'
                : 'assets/images/logo/02_happy.png',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Zoe', style: ChatText.name),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          label,
                          key: ValueKey(label),
                          overflow: TextOverflow.ellipsis,
                          style: ChatText.status.copyWith(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chat language',
            onPressed: onLanguageTap,
            icon: const Icon(Icons.language_rounded, color: HomeColors.inkSoft, size: 28),
          ),
          PopupMenuButton<ChatMenuAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded, color: HomeColors.inkSoft, size: 28),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onSelected: onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ChatMenuAction.clear,
                child: _MenuRow(Icons.refresh_rounded, 'New chat'),
              ),
              PopupMenuItem(
                value: ChatMenuAction.history,
                child: _MenuRow(Icons.history_rounded, 'Chat history'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: HomeColors.lavender, size: 22),
        const SizedBox(width: 12),
        Text(label, style: ChatText.input),
      ],
    );
  }
}