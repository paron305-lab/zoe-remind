import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/ai/model_manager/model_downloader.dart';
import 'package:zoe_remind/app/app_config.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/database/repositories/chat_history_repository.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/onboarding/widgets/profile_page.dart' show showPolicySheet;
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';
import 'package:zoe_remind/features/settings/widgets/brain_card.dart';
import 'package:zoe_remind/features/settings/widgets/profile_card.dart';
import 'package:zoe_remind/features/settings/widgets/settings_dialogs.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';
import 'package:zoe_remind/features/settings/widgets/settings_tiles.dart';

/// Settings tab (Screen 09).
/// Profile · Zoe Chat · Zoe's Brain · Reminders · Privacy & Memory ·
/// Appearance · About · Developer (hidden — 7 taps sa app version).
/// Lahat ng value ay galing / sine-save sa zoe.db (settings, user_profile,
/// model_state, ai_messages, memories).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final _settings = SettingsRepository();
  final _chats = ChatHistoryRepository();
  final _memories = MemoryRepository();
  final _alarms = ReminderAlarmService.instance;
  final _downloader = ModelDownloader.instance;

  bool _loading = true;
  bool _busy = false;

  UserProfile? _profile;
  ZoeLanguage _language = ZoeLanguage.both;
  ModelInfo _model = ModelInfo.none;
  SetupStatus? _setup;
  int _chatCount = 0;
  int _memoryCount = 0;
  bool _longTermMemory = true;
  bool _developer = false;

  /// 7 taps sa app version → lalabas ang Developer.
  int _versionTaps = 0;
  static const _tapsToUnlock = 7;

  SettingsPalette get _p => SettingsPalette(ZoeTheme.isDark);
  bool get _darkMode => ZoeTheme.isDark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatHistoryRepository.changes.addListener(_loadCounts);
    MemoryRepository.changes.addListener(_loadCounts);
    // Bell sa Home → sabay ang switch dito.
    _alarms.enabled.addListener(_rebuild);
    _alarms.sound.addListener(_rebuild);
    _alarms.vibrate.addListener(_rebuild);
    _alarms.defaultSnooze.addListener(_rebuild);
    _downloader.progress.addListener(_onDownloadProgress);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatHistoryRepository.changes.removeListener(_loadCounts);
    MemoryRepository.changes.removeListener(_loadCounts);
    _alarms.enabled.removeListener(_rebuild);
    _alarms.sound.removeListener(_rebuild);
    _alarms.vibrate.removeListener(_rebuild);
    _alarms.defaultSnooze.removeListener(_rebuild);
    _downloader.progress.removeListener(_onDownloadProgress);
    super.dispose();
  }

  // Pagbalik galing sa phone Settings → i-check ulit ang permissions.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSetup();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ───────────────────────── data ─────────────────────────

  Future<void> _load() async {
    try {
      await _alarms.loadPrefs();
      await _alarms.loadEnabled();
      final results = await Future.wait([
        _settings.getProfile(),
        _settings.getLanguage(),
        _settings.getModelInfo(),
        _settings.isLongTermMemoryOn(),
        _settings.isDeveloperUnlocked(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _language = results[1] as ZoeLanguage;
        _model = results[2] as ModelInfo;
        _longTermMemory = results[3] as bool;
        _developer = results[4] as bool;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading settings failed: $e');
      if (mounted) setState(() => _loading = false);
    }
    await Future.wait([_loadCounts(), _loadSetup()]);
  }

  Future<void> _loadCounts() async {
    try {
      final chats = await _chats.messageCount();
      final memories = await _memories.count();
      if (!mounted) return;
      setState(() {
        _chatCount = chats;
        _memoryCount = memories;
      });
    } catch (e) {
      debugPrint('Loading chat/memory counts failed: $e');
    }
  }

  Future<void> _loadSetup() async {
    try {
      final s = await ReminderPermissions.instance.check();
      if (mounted) setState(() => _setup = s);
    } catch (e) {
      debugPrint('Checking reminder setup failed: $e');
    }
  }

  Future<void> _loadModel() async {
    final m = await _settings.getModelInfo();
    if (mounted) setState(() => _model = m);
  }

  /// Patakbuhin ang [action]; kapag pumalya, error snackbar.
  Future<void> _save(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      if (ok != null && mounted) ZoeSnack.show(context, ok);
    } catch (e) {
      debugPrint('Saving setting failed: $e');
      if (mounted) ZoeSnack.show(context, "Couldn't save that setting.", error: true);
      _load();
    }
  }

  // ───────────────────────── Profile ─────────────────────────

  Future<void> _editName() async {
    final name = await showEditNameDialog(context, _profile?.name ?? '', _p);
    if (name == null || name == _profile?.name || !mounted) return;
    await _save(() async {
      await _settings.setUserName(name);
      final profile = await _settings.getProfile();
      if (mounted) setState(() => _profile = profile);
    }, ok: 'Hi, $name! ✨');
  }

  // ───────────────────────── Zoe Chat ─────────────────────────

  Future<void> _setLanguage(ZoeLanguage lang) async {
    setState(() => _language = lang);
    await _save(() => _settings.setLanguage(lang), ok: lang.description);
  }

  // ───────────────────────── Zoe's Brain ─────────────────────────

  /// Bawat update ng ModelDownloader: i-refresh ang card; snackbar sa dulo.
  void _onDownloadProgress() {
    if (!mounted) return;
    final pr = _downloader.progress.value;
    setState(() {});
    switch (pr.phase) {
      case DownloadPhase.done:
        _loadModel();
        ZoeSnack.show(context, "Zoe's brain is ready 🧠✨");
      case DownloadPhase.failed:
        _loadModel();
        ZoeSnack.show(context, pr.message ?? 'Download failed', error: true);
      case DownloadPhase.cancelled:
        _loadModel();
        ZoeSnack.show(context, 'Download paused — tap Resume anytime');
      default:
        break;
    }
  }

  /// wifi / mobile / none (ethernet at VPN = wifi para sa decision na ito).
  Future<String> _network() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet) ||
          r.contains(ConnectivityResult.vpn)) {
        return 'wifi';
      }
      if (r.contains(ConnectivityResult.mobile)) return 'mobile';
      return 'none';
    } catch (_) {
      return 'wifi'; // hindi ma-check → ituloy, may confirm dialog pa rin
    }
  }

  /// [Download] / [Resume]: kunin ang config sa Supabase → confirm → start.
  Future<void> _downloadModel() async {
    if (_downloader.isRunning) return;
    setState(() => _busy = true);
    try {
      final net = await _network();
      if (net == 'none') {
        if (mounted) ZoeSnack.show(context, 'No internet. Connect to Wi-Fi first.', error: true);
        return;
      }
      final config = await _downloader.latestConfig();
      if (!mounted) return;
      if (config == null) {
        ZoeSnack.show(context, "Couldn't reach Zoe's server. Try again later.", error: true);
        return;
      }
      final size = BrainCard.formatBytes(config.sizeBytes);
      final ok = await confirmAction(
        context,
        palette: _p,
        danger: false,
        title: _model.isDownloading ? 'Resume download?' : "Download Zoe's brain?",
        message: net == 'mobile'
            ? 'Naka-mobile data ka. $size ang model na ito — mas mainam sa Wi-Fi. '
                'Ituloy pa rin?'
            : '$size ang model (v${config.version}). Isang beses lang ito. '
                'Huwag isara si Zoe hanggang matapos.',
        confirmLabel: _model.isDownloading ? 'Resume' : 'Download',
      );
      if (!ok || !mounted) return;
      _downloader.start(); // hindi ina-await — live update sa card
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelDownload() => _downloader.cancel();

  /// [Update]: ikumpara ang naka-install sa active model sa Supabase.
  Future<void> _updateModel() async {
    if (_downloader.isRunning) return;
    setState(() => _busy = true);
    try {
      final config = await _downloader.latestConfig();
      if (!mounted) return;
      if (config == null) {
        ZoeSnack.show(context, "Couldn't check for updates. Try again later.", error: true);
        return;
      }
      if (config.version == _model.version) {
        ZoeSnack.show(context, "Zoe's brain is up to date (v${config.version})");
        return;
      }
      final ok = await confirmAction(
        context,
        palette: _p,
        danger: false,
        title: 'Update to v${config.version}?',
        message: 'Ida-download ang bagong model (${BrainCard.formatBytes(config.sizeBytes)}) '
            'at papalitan ang luma. Mas mainam sa Wi-Fi.',
        confirmLabel: 'Update',
      );
      if (!ok || !mounted) return;
      await _settings.deleteModel();
      await _downloader.clearPartials();
      await _loadModel();
      _downloader.start();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteModel() async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: "Delete Zoe's brain?",
      message: 'Matatanggal ang AI model sa phone mo. Hindi muna makakapag-chat si Zoe '
          'hanggang i-download mo ulit. Hindi mabubura ang tasks, reminders at notes mo.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    var freed = 0;
    await _save(() async {
      freed = await _settings.deleteModel();
      await _downloader.clearPartials();
    });
    await _loadModel();
    if (!mounted) return;
    setState(() => _busy = false);
    ZoeSnack.show(context,
        freed > 0 ? 'Deleted — ${BrainCard.formatBytes(freed)} freed' : "Zoe's brain removed");
  }

  // ───────────────────────── Reminders ─────────────────────────

  Future<void> _setRemindersOn(bool on) async {
    HapticFeedback.lightImpact();
    await _save(() => _alarms.setEnabled(on),
        ok: on ? 'Reminders ON 🔔 — tutunog na si Zoe' : 'Reminders OFF 🔕 — walang tutunog');
  }

  Future<void> _pickSound() async {
    final s = await showSoundPicker(context, _p, _alarms.sound.value);
    if (s == null || s == _alarms.sound.value) return;
    await _save(() => _alarms.setSound(s), ok: 'Alarm sound: ${s.label}');
  }

  Future<void> _setVibrate(bool on) =>
      _save(() => _alarms.setVibrate(on), ok: on ? 'Vibration ON' : 'Vibration OFF');

  Future<void> _pickSnooze() async {
    final m = await showSnoozePicker(context, _p, _alarms.defaultSnooze.value);
    if (m == null || m == _alarms.defaultSnooze.value) return;
    await _save(() => _alarms.setDefaultSnooze(m), ok: 'Default snooze: $m minutes');
  }

  Future<void> _openReminderSetup() async {
    await context.push('/reminders/setup');
    await _loadSetup();
  }

  // ───────────────────────── Privacy & Memory ─────────────────────────

  Future<void> _clearChats() async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: 'Clear chat history?',
      message: 'Mabubura ang lahat ng usapan ninyo ni Zoe. '
          'Hindi ito mababawi. Hindi mabubura ang tasks, reminders at notes.',
      confirmLabel: 'Clear',
    );
    if (!ok) return;
    await _save(_chats.clearAll, ok: 'Chat history cleared');
  }

  Future<void> _clearMemories() async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: "Clear Zoe's memories?",
      message: 'Makakalimutan ni Zoe ang lahat ng natutunan niya tungkol sa iyo. '
          'Hindi ito mababawi.',
      confirmLabel: 'Clear',
    );
    if (!ok) return;
    await _save(_memories.clearAll, ok: 'Memories cleared');
  }

  Future<void> _setLongTermMemory(bool on) async {
    setState(() => _longTermMemory = on);
    await _save(() => _settings.setLongTermMemory(on),
        ok: on ? 'Zoe will remember what matters 💭' : "Zoe won't save new memories");
  }

  // ───────────────────────── Appearance ─────────────────────────

  Future<void> _setDarkMode(bool on) async {
    // Buong app ang lilipat (ZoeApp ang nagre-rebuild).
    await _save(() => ZoeTheme.setDark(on));
  }

  // ───────────────────────── About / Developer ─────────────────────────

  Future<void> _tapVersion() async {
    if (_developer) {
      ZoeSnack.show(context, 'Developer options are already on');
      return;
    }
    _versionTaps++;
    final left = _tapsToUnlock - _versionTaps;
    if (left <= 0) {
      _versionTaps = 0;
      await _save(() => _settings.setDeveloperUnlocked(true), ok: 'Developer options unlocked 🛠️');
      if (mounted) setState(() => _developer = true);
    } else if (left <= 3) {
      ZoeSnack.show(context, '$left more ${left == 1 ? 'tap' : 'taps'} to developer options');
    }
  }

  Future<void> _openDeveloper() async {
    final result = await context.push<String>('/settings/developer');
    if (result == 'hidden' && mounted) {
      setState(() => _developer = false);
      ZoeSnack.show(context, 'Developer options hidden');
    }
  }

  // ───────────────────────── UI ─────────────────────────

  String _setupSubtitle() {
    final s = _setup;
    if (s == null) return 'Checking…';
    if (s.allOk) return 'All set — ${s.readyCount}/${s.items.length} ready';
    if (!s.criticalOk) return 'Needs setup — reminders may not ring';
    return '${s.readyCount}/${s.items.length} ready · tap to finish';
  }

  Color? _setupColor() {
    final s = _setup;
    if (s == null) return null;
    if (s.allOk) return _p.mint;
    return s.criticalOk ? _p.amber : _p.coral;
  }

  String _count(int n, String one, String many) => n == 0
      ? 'Empty'
      : '$n ${n == 1 ? one : many}';

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final remindersOn = _alarms.enabled.value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_darkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: p.accent))
              : RefreshIndicator(
                  color: p.accent,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                        child: Text('Settings', style: SettingsText.title(p)),
                      ),

                      // 1. Profile
                      ProfileCard(
                        name: _profile?.name ?? '',
                        since: _profile?.createdAt,
                        onEdit: _editName,
                      ),

                      // 2. Zoe Chat
                      SettingsSection('Zoe language', palette: p),
                      SettingsSegmented<ZoeLanguage>(
                        values: ZoeLanguage.values,
                        selected: _language,
                        label: (l) => l.label,
                        onChanged: _setLanguage,
                        palette: p,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        child: Text(
                          'Para sa Zoe Chat lang. Naiintindihan ka pa rin ni Zoe '
                          'sa English, Tagalog o Taglish.',
                          style: SettingsText.body(p).copyWith(fontSize: 13),
                        ),
                      ),

                      // 3. Zoe's Brain
                      SettingsSection("Zoe's brain", palette: p),
                      BrainCard(
                        info: _model,
                        progress: _downloader.progress.value,
                        palette: p,
                        busy: _busy,
                        onDownload: _downloadModel,
                        onCancel: _cancelDownload,
                        onUpdate: _updateModel,
                        onDelete: _deleteModel,
                      ),

                      // 4. Reminders
                      SettingsSection('Reminders', palette: p),
                      SettingsTile.toggle(
                        icon: remindersOn
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        title: 'Reminders',
                        subtitle: remindersOn
                            ? 'Zoe will ring for your reminders'
                            : 'OFF — no reminder will ring',
                        value: remindersOn,
                        onChanged: _setRemindersOn,
                        palette: p,
                      ),
                      SettingsTile.nav(
                        icon: Icons.music_note_outlined,
                        title: 'Alarm sound',
                        subtitle: _alarms.sound.value.label,
                        onTap: _pickSound,
                        palette: p,
                      ),
                      SettingsTile.toggle(
                        icon: Icons.vibration_rounded,
                        title: 'Vibration',
                        subtitle: 'Vibrate while a reminder rings',
                        value: _alarms.vibrate.value,
                        onChanged: _setVibrate,
                        palette: p,
                      ),
                      SettingsTile.nav(
                        icon: Icons.snooze_rounded,
                        title: 'Default snooze',
                        subtitle: '${_alarms.defaultSnooze.value} minutes',
                        onTap: _pickSnooze,
                        palette: p,
                      ),
                      SettingsTile.nav(
                        icon: Icons.tune_rounded,
                        title: 'Reminder Setup',
                        subtitle: _setupSubtitle(),
                        subtitleColor: _setupColor(),
                        onTap: _openReminderSetup,
                        palette: p,
                        showDivider: false,
                      ),

                      // 5. Privacy & Memory
                      SettingsSection('Privacy & memory', palette: p),
                      _PrivacyBanner(palette: p),
                      SettingsTile(
                        icon: Icons.forum_outlined,
                        title: 'Chat history',
                        subtitle: _count(_chatCount, 'message', 'messages'),
                        onTap: () => context.push('/settings/chat-history'),
                        palette: p,
                        trailing: _ClearButton(
                          palette: p,
                          onTap: _chatCount == 0 ? null : _clearChats,
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.auto_awesome_outlined,
                        title: "Zoe's memories",
                        subtitle: _count(_memoryCount, 'memory', 'memories'),
                        onTap: () => context.push('/settings/memories'),
                        palette: p,
                        trailing: _ClearButton(
                          palette: p,
                          onTap: _memoryCount == 0 ? null : _clearMemories,
                        ),
                      ),
                      SettingsTile.toggle(
                        icon: Icons.psychology_outlined,
                        title: 'Long-term memory',
                        subtitle: _longTermMemory
                            ? 'Zoe remembers what matters to you'
                            : "Zoe won't save new memories",
                        value: _longTermMemory,
                        onChanged: _setLongTermMemory,
                        palette: p,
                        showDivider: false,
                      ),

                      // 6. Appearance
                      SettingsSection('Appearance', palette: p),
                      SettingsTile.toggle(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark mode',
                        subtitle: 'Easier on the eyes at night',
                        value: _darkMode,
                        onChanged: _setDarkMode,
                        palette: p,
                        showDivider: false,
                      ),

                      // 7. About (+ 8. Developer kapag na-unlock)
                      SettingsSection('About', palette: p),
                      SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'App version',
                        subtitle: '${AppConfig.version} (build ${AppConfig.build})',
                        onTap: _tapVersion,
                        palette: p,
                      ),
                      SettingsTile(
                        icon: Icons.favorite_outline_rounded,
                        title: AppConfig.appName,
                        subtitle: 'Made by ${AppConfig.company}',
                        palette: p,
                      ),
                      SettingsTile.nav(
                        icon: Icons.shield_outlined,
                        title: 'Terms & Privacy',
                        subtitle: 'How Zoe keeps your data safe',
                        onTap: () => showPolicySheet(context),
                        palette: p,
                        showDivider: _developer,
                      ),
                      if (_developer)
                        SettingsTile.nav(
                          icon: Icons.build_outlined,
                          title: 'Developer',
                          subtitle: 'Alarm Check & debug tools',
                          onTap: _openDeveloper,
                          palette: p,
                          showDivider: false,
                          iconColor: p.amber,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Lahat ng data mo ay nasa phone mo lang" — mint banner.
class _PrivacyBanner extends StatelessWidget {
  final SettingsPalette palette;
  const _PrivacyBanner({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.mint.withValues(alpha: palette.dark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: palette.mint, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lahat ng data mo ay nasa phone mo lang',
                      style: SettingsText.tileTitle(palette).copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Walang account, walang upload. Your data stays on this phone.',
                      style: SettingsText.body(palette).copyWith(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maliit na "Clear" button sa dulo ng row. null onTap = disabled (walang laman).
class _ClearButton extends StatelessWidget {
  final SettingsPalette palette;
  final VoidCallback? onTap;
  const _ClearButton({required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: palette.coral,
        disabledForegroundColor: palette.sectionLabel.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text('Clear', style: SettingsText.button),
    );
  }
}