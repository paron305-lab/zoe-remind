import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/notes/widgets/note_dialogs.dart';
import 'package:zoe_remind/features/notes/widgets/note_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';

/// New / Edit Note — full screen, walang bottom nav.
/// Pops with 'saved', 'deleted', o null (cancel).
/// May tanong muna bago lumabas kapag may hindi pa nase-save.
class NoteEditorScreen extends StatefulWidget {
  final int? noteId;
  const NoteEditorScreen({super.key, this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _repo = NoteRepository();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _contentFocus = FocusNode();

  Note? _original;
  bool _pinned = false;
  late bool _loading = _isEdit; // bagong note → walang ilo-load
  bool _saving = false;

  /// true = pwede nang umalis kahit may binago (pagkatapos mag-save/discard).
  bool _allowPop = false;

  bool get _isEdit => widget.noteId != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(_refresh);
    _content.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    final id = widget.noteId;
    if (id == null) return;
    try {
      final note = await _repo.getById(id);
      if (!mounted) return;
      if (note == null) {
        _leave(null); // na-delete na pala
        return;
      }
      setState(() {
        _original = note;
        _title.text = note.title;
        _content.text = note.content;
        _pinned = note.pinned;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading note failed: $e');
      if (!mounted) return;
      ZoeSnack.show(context, "Couldn't open the note.", error: true);
      _leave(null);
    }
  }

  // ---------- state ----------

  bool get _isEmpty => _title.text.trim().isEmpty && _content.text.trim().isEmpty;

  /// May binago kumpara sa naka-save (o may na-type sa bagong note).
  bool get _dirty {
    final o = _original;
    if (o == null) return !_isEmpty || _pinned;
    return _title.text.trim() != o.title ||
        _content.text.trim() != o.content ||
        _pinned != o.pinned;
  }

  bool get _canSave => !_loading && !_saving && !_isEmpty && _dirty;

  // ---------- actions ----------

  void _leave(String? result) {
    setState(() => _allowPop = true);
    // hintayin ang rebuild para ma-update ang PopScope bago mag-pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<void> _back() async {
    if (!_dirty || _allowPop) {
      _leave(null);
      return;
    }
    final discard = await confirmDiscardNote(context);
    if (discard && mounted) _leave(null);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final o = _original;
      if (o == null) {
        await _repo.add(title: _title.text, content: _content.text, pinned: _pinned);
      } else {
        await _repo.update(o.copyWith(
          title: _title.text,
          content: _content.text,
          pinned: _pinned,
        ));
      }
      HapticFeedback.lightImpact();
      if (mounted) _leave('saved');
    } catch (e) {
      debugPrint('Saving note failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ZoeSnack.show(context, "Couldn't save the note. Please try again.", error: true);
    }
  }

  Future<void> _delete() async {
    final o = _original;
    if (o?.id == null) return;
    final ok = await confirmDeleteNote(context, o!.title);
    if (!ok || !mounted) return;
    try {
      await _repo.delete(o.id!);
      if (mounted) _leave('deleted');
    } catch (e) {
      debugPrint('Deleting note failed: $e');
      if (mounted) ZoeSnack.show(context, "Couldn't delete the note.", error: true);
    }
  }

  // ---------- UI ----------

  String? _metaText() {
    final o = _original;
    if (o == null) return null;
    final c = o.createdAtTime;
    final created =
        'Created ${ZoeDate.pretty(c)} · ${ZoeDate.prettyTime(TimeOfDay.fromDateTime(c))}';
    if (!o.wasEdited) return created;
    final u = o.updatedAtTime;
    return '$created\nEdited ${ZoeDate.relative(u)} · '
        '${ZoeDate.prettyTime(TimeOfDay.fromDateTime(u))}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaText();

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(); // Android back gesture habang may binago
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (ZoeTheme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: HomeColors.cream,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      ReminderBackButton(onTap: _back),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(_isEdit ? 'Note' : 'New Note',
                            style: ReminderText.screenTitle),
                      ),
                      _SquareButton(
                        icon: _pinned ? Icons.star_rounded : Icons.star_border_rounded,
                        color: NoteColors.amber,
                        background: HomeColors.amberLight,
                        tooltip: _pinned ? 'Unpin' : 'Pin to top',
                        onTap: _loading ? null : () => setState(() => _pinned = !_pinned),
                      ),
                      if (_isEdit && _original != null) ...[
                        const SizedBox(width: 10),
                        _SquareButton(
                          icon: Icons.delete_outline_rounded,
                          color: HomeColors.coral,
                          background: HomeColors.coralLight,
                          tooltip: 'Delete note',
                          onTap: _delete,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: HomeColors.lavender))
                      : _body(meta),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: GradientButton(
                    label: _isEdit ? 'Save changes' : 'Save note',
                    loading: _saving,
                    onTap: _canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String? meta) {
    const noBorder = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      counterText: '',
      isCollapsed: true,
    );

    return GestureDetector(
      // tap sa bakanteng parte → diretso sa content
      behavior: HitTestBehavior.translucent,
      onTap: () => _contentFocus.requestFocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Row(
            children: [
              NoteSourcePill(fromZoe: _original?.fromZoe ?? false),
              if (_pinned) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: HomeColors.amberLight, borderRadius: BorderRadius.circular(14)),
                  child: Text('PINNED',
                      style: NoteText.pill.copyWith(color: const Color(0xFFD48A1E))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: !_isEdit,
            maxLength: Note.maxTitle,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _contentFocus.requestFocus(),
            cursorColor: HomeColors.lavender,
            style: NoteText.editorTitle,
            decoration: noBorder.copyWith(
              hintText: 'Title',
              hintStyle: NoteText.editorTitleHint,
            ),
          ),
          if (meta != null) ...[
            const SizedBox(height: 8),
            Text(meta, style: NoteText.meta.copyWith(height: 1.5)),
          ],
          const SizedBox(height: 16),
          Divider(color: HomeColors.divider, height: 1),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            focusNode: _contentFocus,
            maxLength: Note.maxContent,
            minLines: 10,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: HomeColors.lavender,
            style: NoteText.editorBody,
            decoration: noBorder.copyWith(
              hintText: 'Isulat mo dito… ideas, lists, kahit ano.',
              hintStyle: NoteText.editorBodyHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String tooltip;
  final VoidCallback? onTap;

  const _SquareButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(width: 56, height: 56, child: Icon(icon, color: color, size: 28)),
        ),
      ),
    );
  }
}