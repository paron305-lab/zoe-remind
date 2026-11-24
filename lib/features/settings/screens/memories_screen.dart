import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/settings/screens/chat_history_screen.dart';
import 'package:zoe_remind/features/settings/widgets/settings_dialogs.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';
import 'package:zoe_remind/features/settings/widgets/settings_tiles.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

/// Settings › Privacy & Memory › "Ano'ng alam ni Zoe tungkol sa akin".
/// Lahat ng natutunan ni Zoe tungkol sa iyo, naka-grupo (Level 3):
///   Tawag sa iyo · Paano ka kausapin · Kapag stressed ka ·
///   Mga panalo mo · Mga routine mo · Iba pa
/// Pwedeng burahin isa-isa o lahat (Clear all).
/// Route: /settings/memories
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  /// Pamagat (dito at sa Settings tile).
  static const title = "Ano'ng alam ni Zoe tungkol sa akin";

  /// Pagkakasunod ng mga grupo sa screen.
  static const order = [
    FactKind.nickname,
    FactKind.style,
    FactKind.stressHelp,
    FactKind.win,
    FactKind.routine,
    FactKind.general,
  ];

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final _repo = MemoryRepository();
  SettingsPalette get _p => SettingsPalette(ZoeTheme.isDark);
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
      final longTerm = await settings.isLongTermMemoryOn();
      final items = await _repo.getAll();
      if (!mounted) return;
      setState(() {
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
      message: 'Makakalimutan ni Zoe ang lahat ng natutunan niya tungkol sa iyo — '
          'pati ang tawag sa iyo at kung paano ka kausapin. Hindi ito mababawi.',
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

  /// Malinaw na pamagat ng card: "AC", "Diretso", "Makinig muna"… o ang content.
  static String _titleOf(MemoryItem m) {
    switch (m.kind) {
      case FactKind.nickname:
        return m.value ?? m.content;
      case FactKind.style:
        return switch (TalkStyle.fromValue(m.value)) {
          TalkStyle.diretso => 'Diretso — maikli, walang paligoy',
          TalkStyle.malambing => 'Malambing — mas malambot',
          null => m.content,
        };
      case FactKind.stressHelp:
        return switch (StressHelp.fromValue(m.value)) {
          StressHelp.listen => 'Makinig muna',
          StressHelp.advice => 'Payo agad',
          StressHelp.lighten => 'Pampagaan',
          null => m.content,
        };
      case FactKind.win:
      case FactKind.routine:
      case FactKind.general:
        return m.content;
    }
  }

  Widget _card(MemoryItem m) {
    final p = _p;
    final title = _titleOf(m);
    return SettingsListCard(
      palette: p,
      title: title,
      titleMaxLines: 4,
      // Single kinds: ipakita rin ang buong sinabi ("Tawagin akong AC").
      body: title == m.content ? '' : m.content,
      meta: '${m.fromChat ? 'Learned in chat' : 'You told Zoe'} · ${relativeDay(m.updatedAt)}',
      trailing: IconButton(
        tooltip: 'Forget',
        icon: Icon(Icons.delete_outline_rounded, color: p.coral),
        onPressed: () => _delete(m),
      ),
    );
  }

  List<Widget> _groups() {
    final p = _p;
    final out = <Widget>[];
    for (final kind in MemoriesScreen.order) {
      final items = _items.where((m) => m.kind == kind).toList();
      if (items.isEmpty) continue;
      out.add(SettingsSection(CompanionFacts.label(kind, tagalog: true), palette: p));
      for (final m in items) {
        out
          ..add(Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _card(m)))
          ..add(const SizedBox(height: 12));
      }
    }
    out.add(const SizedBox(height: 28));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return SettingsSubScaffold(
      palette: p,
      title: MemoriesScreen.title,
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
                      ? 'Habang nag-uusap kayo, dito lalabas ang mga bagay na sinabi mo: '
                          'tawag sa iyo ("call me AC"), paano ka kausapin, ano\'ng '
                          'nakakatulong kapag stressed ka, mga panalo at routine mo. '
                          'Pwede mo silang burahin anytime.'
                      : 'Naka-OFF ang long-term memory, kaya walang bagong maaalala si Zoe.',
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 0, bottom: 12),
                  children: _groups(),
                ),
    );
  }
}