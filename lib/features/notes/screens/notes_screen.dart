import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/zoe_fab.dart';
import 'package:zoe_remind/features/notes/controllers/note_list_logic.dart';
import 'package:zoe_remind/features/notes/widgets/note_card.dart';
import 'package:zoe_remind/features/notes/widgets/note_dialogs.dart';
import 'package:zoe_remind/features/notes/widgets/note_styles.dart';
import 'package:zoe_remind/features/notes/widgets/notes_header.dart';

/// Notes tab: lahat ng sine-save ni Zoe at tinype mo, searchable.
/// Pinned sa taas → Today / Yesterday / This week / Older.
/// Tap = open · Long-press = Pin / Delete · + = New note.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with WidgetsBindingObserver {
  final _repo = NoteRepository();
  final _search = TextEditingController();

  List<Note> _all = const [];
  NoteFilter _filter = NoteFilter.all;
  NoteSort _sort = NoteSort.edited;
  bool _loading = true;
  bool _failed = false;

  /// Para hindi mag-load nang sabay-sabay (hal. listener + resume).
  /// Kapag may bagong change habang naglo-load, isa pang load pagkatapos.
  bool _reloading = false;
  bool _reloadAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search.addListener(_onSearchChanged);
    NoteRepository.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NoteRepository.changes.removeListener(_load);
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Para ma-refresh ang "Edited 2h ago" at Today/Yesterday.
    if (state == AppLifecycleState.resumed) _load();
  }

  void _onSearchChanged() => setState(() {});

  // ---------- data ----------

  Future<void> _load() async {
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    try {
      final notes = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _all = notes;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Loading notes failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    } finally {
      _reloading = false;
      if (_reloadAgain && mounted) {
        _reloadAgain = false;
        _load();
      }
    }
  }

  Future<void> _togglePin(Note note) async {
    final id = note.id;
    if (id == null) return;
    final pinned = !note.pinned;
    // update agad ang UI, tapos save
    setState(() {
      _all = [for (final n in _all) n.id == id ? n.copyWith(pinned: pinned) : n];
    });
    HapticFeedback.selectionClick();
    try {
      await _repo.setPinned(id, pinned);
      if (mounted) ZoeSnack.show(context, pinned ? 'Pinned to top 📌' : 'Unpinned');
    } catch (e) {
      debugPrint('Pinning note failed: $e');
      if (!mounted) return;
      ZoeSnack.show(context, "Couldn't update the note.", error: true);
      _load();
    }
  }

  Future<void> _delete(Note note) async {
    final id = note.id;
    if (id == null) return;
    final ok = await confirmDeleteNote(context, note.title);
    if (!ok || !mounted) return;
    setState(() => _all = _all.where((n) => n.id != id).toList());
    try {
      await _repo.delete(id);
      if (mounted) ZoeSnack.show(context, 'Note deleted');
    } catch (e) {
      debugPrint('Deleting note failed: $e');
      if (!mounted) return;
      ZoeSnack.show(context, "Couldn't delete the note.", error: true);
      _load();
    }
  }

  // ---------- navigation ----------

  /// Editor returns 'saved' / 'deleted' / null (cancel).
  /// Hindi kailangang mag-reload dito — NoteRepository.changes na ang bahala.
  Future<void> _openEditor(String location) async {
    final result = await context.push<String>(location);
    if (!mounted) return;
    if (result == 'saved') ZoeSnack.show(context, 'Note saved ✨');
    if (result == 'deleted') ZoeSnack.show(context, 'Note deleted');
  }

  void _openNew() => _openEditor('/notes/new');

  void _openNote(Note note) => _openEditor('/notes/edit/${note.id}');

  Future<void> _longPress(Note note) async {
    HapticFeedback.mediumImpact();
    final action = await showNoteActions(context, note);
    if (action == null || !mounted) return;
    switch (action) {
      case NoteAction.pin:
        await _togglePin(note);
      case NoteAction.delete:
        await _delete(note);
    }
  }

  Future<void> _pickSort() async {
    final picked = await showNoteSort(context, _sort);
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final query = _search.text;
    final visible = NoteListLogic.applyFilter(_all, _filter, query: query);
    final groups = NoteListLogic.group(visible, now, sort: _sort);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // puting icons sa ibabaw ng gradient header
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        floatingActionButton: ZoeFab(onTap: _openNew, size: 64),
        body: RefreshIndicator(
          color: HomeColors.lavender,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              NotesHeader(search: _search, onSortTap: _pickSort),
              const SizedBox(height: 22),
              NoteFilterChips(
                selected: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              if (_loading)
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator(color: HomeColors.lavender)),
                )
              else if (_failed)
                _ErrorState(onRetry: () {
                  setState(() => _loading = true);
                  _load();
                })
              else if (groups.isEmpty)
                NotesEmptyState(filter: _filter, searching: query.trim().isNotEmpty)
              else
                for (final g in groups) ..._buildGroup(g, now),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroup(NoteGroup g, DateTime now) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 14),
          child: Text(g.label.toUpperCase(), style: NoteText.groupLabel),
        ),
        for (final n in g.notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: NoteCard(
              key: ValueKey('note-${n.id}'),
              note: n,
              preview: NoteListLogic.preview(n),
              timeLabel: NoteListLogic.timeLabel(n, now, sort: _sort),
              onTap: () => _openNote(n),
              onLongPress: () => _longPress(n),
            ),
          ),
      ];
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Text('Hindi ko ma-load ang notes mo',
              textAlign: TextAlign.center, style: NoteText.emptyTitle),
          const SizedBox(height: 6),
          Text('Something went wrong reading your notes.',
              textAlign: TextAlign.center, style: NoteText.emptyBody),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text('Try again',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: HomeColors.lavender)),
          ),
        ],
      ),
    );
  }
}