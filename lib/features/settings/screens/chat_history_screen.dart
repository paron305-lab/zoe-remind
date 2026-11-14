import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/chat_message.dart';
import 'package:zoe_remind/database/repositories/chat_history_repository.dart';
import 'package:zoe_remind/features/settings/widgets/settings_dialogs.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

/// Settings › Privacy & Memory › Chat history.
/// Listahan ng usapan kay Zoe (pinakabago sa taas) + Clear all.
/// Route: /settings/chat-history
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _repo = ChatHistoryRepository();
  SettingsPalette get _p => SettingsPalette(ZoeTheme.isDark);
  List<ChatConversation> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ChatHistoryRepository.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ChatHistoryRepository.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.conversations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading chat history failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAll() async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: 'Clear chat history?',
      message: 'Mabubura ang lahat ng usapan ninyo ni Zoe. Hindi ito mababawi.',
      confirmLabel: 'Clear',
    );
    if (!ok) return;
    try {
      await _repo.clearAll();
      if (mounted) ZoeSnack.show(context, 'Chat history cleared');
    } catch (e) {
      if (mounted) ZoeSnack.show(context, "Couldn't clear the chat history.", error: true);
    }
  }

  Future<void> _delete(ChatConversation c) async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: 'Delete this chat?',
      message: '"${c.title}" · ${c.messageCount} messages',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await _repo.deleteConversation(c.id);
      if (mounted) ZoeSnack.show(context, 'Chat deleted');
    } catch (e) {
      if (mounted) ZoeSnack.show(context, "Couldn't delete the chat.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return SettingsSubScaffold(
      palette: p,
      title: 'Chat history',
      actions: [
        if (_items.isNotEmpty)
          TextButton(
            onPressed: _clearAll,
            child: Text('Clear all', style: SettingsText.button.copyWith(color: p.coral)),
          ),
      ],
      child: _loading
          ? Center(child: CircularProgressIndicator(color: p.accent))
          : _items.isEmpty
              ? SettingsEmptyState(
                  palette: p,
                  icon: Icons.forum_outlined,
                  title: 'Wala pang chat history',
                  body: 'Dito lalabas ang mga usapan ninyo ni Zoe. '
                      'Naka-save lang ito sa phone mo.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final c = _items[i];
                    return SettingsListCard(
                      palette: p,
                      title: c.title,
                      body: c.lastMessage,
                      meta: '${c.messageCount} messages · ${relativeDay(c.updatedAt)}',
                      onTap: () => context.push('/settings/chat-history/${c.id}'),
                      onLongPress: () => _delete(c),
                    );
                  },
                ),
    );
  }
}

/// Basahin ang isang usapan (read-only).
/// Route: /settings/chat-history/:id
class ChatConversationScreen extends StatefulWidget {
  final int conversationId;
  const ChatConversationScreen({super.key, required this.conversationId});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  SettingsPalette get _p => SettingsPalette(ZoeTheme.isDark);
  List<ChatMessage> _messages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final msgs = await ChatHistoryRepository().messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading conversation failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return SettingsSubScaffold(
      palette: p,
      title: 'Chat',
      child: _loading
          ? Center(child: CircularProgressIndicator(color: p.accent))
          : _messages.isEmpty
              ? SettingsEmptyState(
                  palette: p,
                  icon: Icons.forum_outlined,
                  title: 'Walang laman',
                  body: 'Na-delete na siguro ang usapang ito.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    return Align(
                      alignment: m.fromZoe ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: m.fromZoe ? p.card : p.accent,
                          borderRadius: BorderRadius.circular(20),
                          border: m.fromZoe ? Border.all(color: p.divider) : null,
                        ),
                        child: Text(
                          m.content,
                          style: SettingsText.body(p).copyWith(
                            color: m.fromZoe ? p.ink : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ───────────────────────── shared sub-screen widgets ─────────────────────────

/// Scaffold ng Settings sub-screens (Chat history, Memories): back + title.
class SettingsSubScaffold extends StatelessWidget {
  final SettingsPalette palette;
  final String title;
  final List<Widget> actions;
  final Widget child;

  const SettingsSubScaffold({
    super.key,
    required this.palette,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        title: Text(title,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: p.ink)),
        actions: actions,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

class SettingsEmptyState extends StatelessWidget {
  final SettingsPalette palette;
  final IconData icon;
  final String title;
  final String body;

  const SettingsEmptyState({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: p.iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: p.accent, size: 38),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: SettingsText.tileTitle(p)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: SettingsText.body(p)),
          ],
        ),
      ),
    );
  }
}

/// Card sa listahan: title · 2-line preview · meta.
class SettingsListCard extends StatelessWidget {
  final SettingsPalette palette;
  final String title;
  final String body;
  final String meta;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final int titleMaxLines;

  const SettingsListCard({
    super.key,
    required this.palette,
    required this.title,
    required this.body,
    required this.meta,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.titleMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: SettingsText.tileTitle(p).copyWith(fontSize: 17)),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SettingsText.body(p)),
                    ],
                    const SizedBox(height: 8),
                    Text(meta,
                        style: SettingsText.body(p)
                            .copyWith(fontSize: 13, color: p.sectionLabel)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today" / "Yesterday" / "Nov 3".
String relativeDay(DateTime t, {DateTime? now}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base = '${months[t.month - 1]} ${t.day}';
  return t.year == n.year ? base : '$base, ${t.year}';
}