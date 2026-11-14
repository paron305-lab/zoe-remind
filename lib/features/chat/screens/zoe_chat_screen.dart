import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/features/chat/controllers/zoe_chat_controller.dart';
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/chat/widgets/answer_card.dart';
import 'package:zoe_remind/features/chat/widgets/chat_bubbles.dart';
import 'package:zoe_remind/features/chat/widgets/chat_header.dart';
import 'package:zoe_remind/features/chat/widgets/chat_input_bar.dart';
import 'package:zoe_remind/features/chat/widgets/chat_states.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/chat/widgets/confirm_card.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';

/// Zoe Chat tab.
///
/// UI-first: gumagana ito ngayon gamit ang ChatPreviewBrain (simple rules).
/// Kapag handa na si Qwen + Sandbox, ang controller lang ang papalitan —
/// hindi ang mga widget dito.
class ZoeChatScreen extends StatefulWidget {
  const ZoeChatScreen({super.key});

  @override
  State<ZoeChatScreen> createState() => _ZoeChatScreenState();
}

class _ZoeChatScreenState extends State<ZoeChatScreen> {
  final _chat = ZoeChatController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_refresh);
    _chat.init();
  }

  @override
  void dispose() {
    _chat.removeListener(_refresh);
    _chat.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ───────────────────────── Actions ─────────────────────────

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _chat.send(text);
  }

  /// "Remind me…" → ilagay sa input. Buong tanong → i-send agad.
  void _suggestion(String s) {
    if (s.endsWith('…')) {
      _input.text = s.substring(0, s.length - 1);
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _focus.requestFocus();
    } else {
      _chat.send(s);
    }
  }

  Future<void> _edit(ConfirmEntry e) async {
    switch (e.kind) {
      case DraftKind.reminder:
        final id = await context.push<Object?>('/reminders/new', extra: e.reminder);
        if (id is int) await _chat.savedFromEditor(e, id);
      case DraftKind.task:
        final id = await context.push<Object?>('/tasks/new', extra: e.task);
        if (id is int) await _chat.savedFromEditor(e, id);
      case DraftKind.note:
        final draft = await showNoteDraftSheet(context, e.note!);
        if (draft != null) _chat.updateNote(e, draft);
    }
  }

  Future<void> _accept(ConfirmEntry e) async {
    final saved = await _chat.accept(e);
    if (!saved || !mounted) return;
    // May kulang na permission → hindi tutunog ang alarm. Ipakita ang Setup.
    if (e.kind == DraftKind.reminder && await ReminderPermissions.instance.shouldPrompt()) {
      if (mounted) await context.push('/reminders/setup');
    }
  }

  void _view(ConfirmEntry e) {
    switch (e.kind) {
      case DraftKind.reminder:
        context.go('/home');
      case DraftKind.task:
        context.go('/tasks');
      case DraftKind.note:
        if (e.savedId != null) context.push('/notes/edit/${e.savedId}');
    }
  }

  Future<void> _chip(ClarifyEntry c, ClarifyChip chip) async {
    var time = chip.time;
    if (time == null) {
      final next = DateTime.now().add(const Duration(hours: 1));
      time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: next.hour, minute: 0),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: HomeColors.lavender,
                  onPrimary: Colors.white,
                  surface: HomeColors.card,
                  onSurface: HomeColors.ink,
                ),
          ),
          child: child!,
        ),
      );
    }
    if (time != null) await _chat.pickTime(c, time);
  }

  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<ZoeLanguage>(
      context: context,
      backgroundColor: HomeColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text('Zoe Chat language', style: ChatText.title),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Naiintindihan pa rin ni Zoe ang English, Tagalog, at Taglish.',
                    style: ChatText.footnote),
              ),
              for (final l in ZoeLanguage.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(l.label, style: ChatText.cardTitle),
                  subtitle: Text(l.description, style: ChatText.footnote),
                  trailing: l == _chat.language
                      ? Icon(Icons.check_rounded, color: HomeColors.lavender)
                      : null,
                  onTap: () => Navigator.pop(ctx, l),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await _chat.setLanguage(picked);
  }

  void _menu(ChatMenuAction action) {
    switch (action) {
      case ChatMenuAction.clear:
        _chat.clearChat();
      case ChatMenuAction.history:
        context.push('/settings/chat-history');
    }
  }

  // ───────────────────────── UI ─────────────────────────

  String get _greeting {
    final h = DateTime.now().hour;
    if (_chat.language == ZoeLanguage.english) {
      return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
    }
    return h < 12 ? 'Magandang umaga' : (h < 18 ? 'Magandang hapon' : 'Magandang gabi');
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (ZoeTheme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(gradient: ChatColors.background),
        child: Column(
          children: [
            ChatHeader(
              status: chat.status,
              onLanguageTap: _pickLanguage,
              onMenu: _menu,
            ),
            if (chat.status == ZoeChatStatus.downloading)
              ChatBanner(
                icon: Icons.downloading_rounded,
                text: "Downloading Zoe's brain… pwede mo pa ring gamitin ang app.",
                color: HomeColors.sky,
                fill: HomeColors.skyLight,
                progress: true,
              )
            else if (chat.status == ZoeChatStatus.preview)
              ChatBanner(
                icon: Icons.science_outlined,
                text: 'UI preview — wala pang AI. Simple rules muna ang sagot ni Zoe.',
                color: ChatColors.amber,
                fill: ChatColors.amberLight,
                actionLabel: 'Brain',
                onAction: () => context.go('/settings'),
              ),
            Expanded(child: _body()),
            if (chat.canChat && !chat.loading) ...[
              if (chat.isEmpty) ...[
                SuggestionRow(items: chat.suggestions, onTap: _suggestion),
                const SizedBox(height: 10),
              ],
              ChatInputBar(
                controller: _input,
                focusNode: _focus,
                hint: chat.inputHint,
                enabled: chat.canChat,
                busy: chat.thinking,
                maxLength: ZoeChatController.maxInput,
                onSend: _send,
                onMic: () => ZoeSnack.show(context, 'Voice is coming in a later version 🎤'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final chat = _chat;
    if (chat.loading) {
      return Center(child: CircularProgressIndicator(color: HomeColors.lavender));
    }
    if (!chat.canChat) {
      return ChatNoBrain(onGetReady: () => context.go('/settings'));
    }
    if (chat.isEmpty) {
      return ChatWelcome(
        name: chat.userName,
        greeting: _greeting,
        body: chat.t(
          'Ask me to remind you, add a task, save a note, or ask what you did. '
              'Everything stays on your phone. 🔒',
          'Sabihin mo lang: remind, task, o note — o itanong kung ano ginawa mo. '
              'Lahat ng data mo ay nasa phone mo lang. 🔒',
        ),
      );
    }

    final items = chat.entries;
    // reverse: true → laging nasa baba ang bagong message (kahit bukas ang keyboard).
    return ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final entry = items[items.length - 1 - i];
        return KeyedSubtree(key: ValueKey(entry.id), child: _entry(entry));
      },
    );
  }

  Widget _entry(ChatEntry entry) => switch (entry) {
        TextEntry t when !t.fromZoe => UserBubble(t.text),
        TextEntry t => ZoeBubble(text: t.text, footnote: t.footnote),
        InfoEntry i => InfoPill(i.text),
        TypingEntry() => const TypingBubble(),
        ConfirmEntry c => ConfirmCard(
            entry: c,
            onEdit: () => _edit(c),
            onCancel: () => _chat.cancel(c),
            onAccept: () => _accept(c),
            onView: () => _view(c),
          ),
        ClarifyEntry c => ClarifyBubble(entry: c, onChip: (chip) => _chip(c, chip)),
        AnswerEntry a => AnswerCard(entry: a),
        ErrorEntry err => ErrorBubble(entry: err, onRetry: () => _chat.retry(err)),
      };
}

/// Note card [Edit] → bottom sheet (title + content). Hindi pa nase-save.
Future<NoteDraft?> showNoteDraftSheet(BuildContext context, NoteDraft draft) {
  return showModalBottomSheet<NoteDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _NoteDraftSheet(draft: draft),
  );
}

class _NoteDraftSheet extends StatefulWidget {
  final NoteDraft draft;
  const _NoteDraftSheet({required this.draft});

  @override
  State<_NoteDraftSheet> createState() => _NoteDraftSheetState();
}

class _NoteDraftSheetState extends State<_NoteDraftSheet> {
  late final _title = TextEditingController(text: widget.draft.title);
  late final _content = TextEditingController(text: widget.draft.content);

  @override
  void initState() {
    super.initState();
    _content.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  InputDecoration _box(String hint) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: ReminderText.fieldHint,
      counterText: '',
      filled: true,
      fillColor: HomeColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: b(const Color(0xFFB7ACEB), 1.5),
      focusedBorder: b(HomeColors.lavender, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSave = _content.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit note', style: ReminderText.screenTitle),
            const FieldLabel('Title (optional)'),
            TextField(
              controller: _title,
              maxLength: Note.maxTitle,
              textCapitalization: TextCapitalization.sentences,
              style: ReminderText.field,
              cursorColor: HomeColors.lavender,
              decoration: _box('Untitled note'),
            ),
            const FieldLabel('Note'),
            TextField(
              controller: _content,
              maxLength: Note.maxContent,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: ReminderText.field.copyWith(fontWeight: FontWeight.w500),
              cursorColor: HomeColors.lavender,
              decoration: _box('Write something…'),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Done',
              onTap: canSave
                  ? () => Navigator.pop(
                        context,
                        NoteDraft(title: _title.text.trim(), content: _content.text.trim()),
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}