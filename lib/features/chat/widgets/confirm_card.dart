import 'package:flutter/material.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/chat/widgets/chat_bubbles.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// "Create this reminder?" — [Edit] [Cancel] [Accept].
/// Pagkatapos: "Saved ✓ · View"  o  "Cancelled".
class ConfirmCard extends StatelessWidget {
  final ConfirmEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onAccept;
  final VoidCallback onView;

  const ConfirmCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onCancel,
    required this.onAccept,
    required this.onView,
  });

  String get _question => switch (entry.kind) {
        DraftKind.reminder => 'Create this reminder?',
        DraftKind.task => 'Add this task?',
        DraftKind.note => 'Save this note?',
      };

  String get _savedLabel => switch (entry.kind) {
        DraftKind.reminder => 'Reminder saved',
        DraftKind.task => 'Task added',
        DraftKind.note => 'Note saved',
      };

  String get _title => switch (entry.kind) {
        DraftKind.reminder => entry.reminder!.title,
        DraftKind.task => entry.task!.title,
        DraftKind.note => Note.titleFrom(entry.note!.title, entry.note!.content),
      };

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    final cancelled = status == DraftStatus.cancelled;
    final saved = status == DraftStatus.saved;

    final (headerText, headerColor, headerFill, headerIcon) = switch (status) {
      DraftStatus.saved => (_savedLabel, HomeColors.mint, HomeColors.mintLight, Icons.check_circle_rounded),
      DraftStatus.cancelled => ('Cancelled', HomeColors.navInactive, ChatColors.cancelFill, Icons.block_rounded),
      _ => (_question, HomeColors.lavender, ChatColors.cardHeader, null),
    };

    return ZoeRow(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: ChatColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── header band
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: headerFill,
              padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
              child: Row(
                children: [
                  if (headerIcon != null) ...[
                    Icon(headerIcon, color: headerColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(headerText, style: ChatText.cardHeader.copyWith(color: headerColor)),
                  ),
                  if (saved && entry.edited)
                    Text('edited', style: ChatText.pill.copyWith(color: HomeColors.mint)),
                ],
              ),
            ),
            // ── body
            Opacity(
              opacity: cancelled ? 0.5 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${draftEmoji(_title, entry.kind)} $_title',
                      style: ChatText.cardTitle.copyWith(
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _details(),
                  ],
                ),
              ),
            ),
            // ── actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: switch (status) {
                DraftStatus.pending || DraftStatus.saving => _actions(status == DraftStatus.saving),
                DraftStatus.saved => Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(_viewLabel, style: ChatText.button),
                      style: TextButton.styleFrom(foregroundColor: HomeColors.lavender),
                    ),
                  ),
                DraftStatus.cancelled => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _viewLabel => switch (entry.kind) {
        DraftKind.reminder => 'View in Home',
        DraftKind.task => 'View in Tasks',
        DraftKind.note => 'View note',
      };

  Widget _details() {
    switch (entry.kind) {
      case DraftKind.reminder:
        final d = entry.reminder!;
        return Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _Meta(Icons.calendar_today_outlined, d.date == null ? '—' : ZoeDate.short(d.date!)),
            _Meta(Icons.access_time_rounded, d.time == null ? '—' : ZoeDate.prettyTime(d.time!)),
            if (d.repeat != ReminderRepeat.none) _Meta(Icons.sync_alt_rounded, _repeat(d.repeat)),
          ],
        );
      case DraftKind.task:
        final d = entry.task!;
        return Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _Meta(Icons.calendar_today_outlined, d.date == null ? 'No date' : ZoeDate.short(d.date!)),
            _Meta(Icons.access_time_rounded,
                d.date == null || d.time == null ? 'Any time' : ZoeDate.prettyTime(d.time!)),
          ],
        );
      case DraftKind.note:
        final d = entry.note!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(d.content, maxLines: 4, overflow: TextOverflow.ellipsis, style: ChatText.cardMeta),
        );
    }
  }

  String _repeat(ReminderRepeat r) => switch (r) {
        ReminderRepeat.none => '',
        ReminderRepeat.daily => 'Every day',
        ReminderRepeat.weekly => 'Weekly',
        ReminderRepeat.monthly => 'Monthly',
      };

  Widget _actions(bool saving) {
    return Row(
      children: [
        Expanded(
          child: _CardButton(
            label: 'Edit',
            color: HomeColors.lavender,
            fill: ChatColors.cardHeader,
            onTap: saving ? null : onEdit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CardButton(
            label: 'Cancel',
            color: HomeColors.inkSoft,
            fill: ChatColors.cancelFill,
            onTap: saving ? null : onCancel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CardButton(
            label: 'Accept',
            color: Colors.white,
            gradient: ChatColors.userBubble,
            loading: saving,
            onTap: saving ? null : onAccept,
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: HomeColors.inkSoft),
        const SizedBox(width: 6),
        Text(text, style: ChatText.cardMeta),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? fill;
  final Gradient? gradient;
  final bool loading;
  final VoidCallback? onTap;

  const _CardButton({
    required this.label,
    required this.color,
    this.fill,
    this.gradient,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      height: 50,
      decoration: BoxDecoration(color: fill, gradient: gradient, borderRadius: radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(label, style: ChatText.button.copyWith(color: color)),
          ),
        ),
      ),
    );
  }
}