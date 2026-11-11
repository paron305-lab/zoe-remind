import 'package:flutter/material.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/settings/screens/chat_history_screen.dart';
import 'package:zoe_remind/features/settings/widgets/settings_dialogs.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

/// Settings › Privacy & Memory › Zoe's memories.
/// Lahat ng natutunan ni Zoe tungkol sa iyo — pwedeng burahin isa-isa o lahat.
/// Route: /settings/memories
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final _repo = MemoryRepository();
  SettingsPalette _p = const SettingsPalette(false);
  List<MemoryItem> _items = const [];
  bool _longTerm = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    MemoryRepository.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    MemoryRepository.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = SettingsRepository();
      final dark = await settings.isDarkMode();
      final longTerm = await settings.isLongTermMemoryOn();
      final items = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _p = SettingsPalette(dark);
        _longTerm = longTerm;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading memories failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(MemoryItem m) async {
    final id = m.id;
    if (id == null) return;
    final ok = await confirmAction(
      context,
      palette: _p,
      title: 'Forget this?',
      message: '"${m.content}"',
      confirmLabel: 'Forget',
    );
    if (!ok) return;
    try {
      await _repo.delete(id);
      if (mounted) ZoeSnack.show(context, 'Zoe forgot that');
    } catch (e) {
      if (mounted) ZoeSnack.show(context, "Couldn't delete the memory.", error: true);
    }
  }

  Future<void> _clearAll() async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: "Clear Zoe's memories?",
      message: 'Makakalimutan ni Zoe ang lahat ng natutunan niya tungkol sa iyo. '
          'Hindi ito mababawi.',
      confirmLabel: 'Clear',
    );
    if (!ok) return;
    try {
      await _repo.clearAll();
      if (mounted) ZoeSnack.show(context, 'Memories cleared');
    } catch (e) {
      if (mounted) ZoeSnack.show(context, "Couldn't clear the memories.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return SettingsSubScaffold(
      palette: p,
      title: "Zoe's memories",
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
                  icon: Icons.auto_awesome_outlined,
                  title: 'Wala pang naaalala si Zoe',
                  body: _longTerm
                      ? 'Habang nag-uusap kayo, dito lalabas ang mga bagay na '
                          'mahalaga sa iyo. Pwede mo silang burahin anytime.'
                      : 'Naka-OFF ang long-term memory, kaya walang bagong maaalala si Zoe.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    return SettingsListCard(
                      palette: p,
                      title: m.content,
                      titleMaxLines: 4,
                      body: '',
                      meta: '${m.fromChat ? 'Learned in chat' : 'You told Zoe'} · '
                          '${relativeDay(m.updatedAt)}',
                      trailing: IconButton(
                        tooltip: 'Forget',
                        icon: Icon(Icons.delete_outline_rounded, color: p.coral),
                        onPressed: () => _delete(m),
                      ),
                    );
                  },
                ),
    );
  }
}