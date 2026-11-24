import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/ai/model_manager/model_downloader.dart';
import 'package:zoe_remind/app/app_config.dart';
import 'package:zoe_remind/core/constants/ai_constants.dart';
import 'package:zoe_remind/core/constants/model_tier.dart';
import 'package:zoe_remind/core/device/device_memory.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/services/data_wipe.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/database/repositories/chat_history_repository.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/companion/controllers/mood_log.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';
import 'package:zoe_remind/features/onboarding/widgets/profile_page.dart' show showPolicySheet;
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';
import 'package:zoe_remind/features/settings/screens/memories_screen.dart';
import 'package:zoe_remind/features/settings/widgets/brain_card.dart';
import 'package:zoe_remind/features/settings/widgets/profile_card.dart';
import 'package:zoe_remind/features/settings/widgets/settings_dialogs.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';
import 'package:zoe_remind/features/settings/widgets/settings_tiles.dart';
import 'package:zoe_remind/supabase/model_config_service.dart';

/// Settings tab (Screen 09).
/// Profile · Zoe Chat · Zoe's Brain · Reminders · Privacy & Memory ·
/// Appearance · About · Developer (hidden — 7 taps sa app version).
/// Lahat ng value ay galing / sine-save sa zoe.db (settings, user_profile,
/// model_state, ai_messages, memories, mood_log).
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
  final _moodLog = MoodLog.instance;

  bool _loading = true;
  bool _busy = false;

  UserProfile? _profile;
  ZoeLanguage _language = ZoeLanguage.both;

  /// Estado ng bawat model sa phone (model_state).
  Map<ModelTier, ModelInfo> _models = const {};

  /// Info ng bawat model galing sa Supabase. Walang laman kapag offline.
  Map<ModelTier, ModelConfig> _configs = const {};

  /// Ang piniling model ng user (settings: active_model).
  ModelTier _activeTier = ModelTier.lite;

  /// RAM ng phone sa MB. null = hindi pa alam / hindi nalaman.
  int? _ramMb;

  SetupStatus? _setup;
  int _chatCount = 0;
  int _memoryCount = 0;
  bool _longTermMemory = true;
  bool _developer = false;

  /// Mood log (7 araw): bilang ng pagod / stressed… ngayong linggo.
  MoodWeek _moodWeek = MoodWeek.empty;

  /// 7 taps sa app version → lalabas ang Developer.
  int _versionTaps = 0;
  static const _tapsToUnlock = 7;

  /// Dagdag na free space na kailangan bukod sa size ng model.
  static const _storageMarginMb = 300;

  SettingsPalette get _p => SettingsPalette(ZoeTheme.isDark);
  bool get _darkMode => ZoeTheme.isDark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatHistoryRepository.changes.addListener(_loadCounts);
    MemoryRepository.changes.addListener(_loadCounts);
    _moodLog.changes.addListener(_loadCounts);
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
    _moodLog.changes.removeListener(_loadCounts);
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
        _settings.getAllModels(),
        _settings.isLongTermMemoryOn(),
        _settings.isDeveloperUnlocked(),
        _settings.getActiveTier(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _language = results[1] as ZoeLanguage;
        _models = results[2] as Map<ModelTier, ModelInfo>;
        _longTermMemory = results[3] as bool;
        _developer = results[4] as bool;
        _activeTier = results[5] as ModelTier;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading settings failed: $e');
      if (mounted) setState(() => _loading = false);
    }
    await Future.wait([_loadCounts(), _loadSetup(), _loadBrainExtras()]);
  }

  Future<void> _loadCounts() async {
    try {
      final chats = await _chats.messageCount();
      final memories = await _memories.count();
      final week = await _moodLog.week();
      if (!mounted) return;
      setState(() {
        _chatCount = chats;
        _memoryCount = memories;
        _moodWeek = week;
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

  /// Estado ng mga model sa phone + alin ang pinili.
  Future<void> _loadModels() async {
    final models = await _settings.getAllModels();
    final active = await _settings.getActiveTier();
    if (!mounted) return;
    setState(() {
      _models = models;
      _activeTier = active;
    });
  }

  /// RAM ng phone + listahan ng models sa Supabase (pangalan, size, min RAM).
  /// Kapag offline, hindi binubura ang dating nakuha.
  Future<void> _loadBrainExtras() async {
    try {
      final ram = await DeviceMemory.totalRamMb();
      final configs = await ModelConfigService.fetchAll();
      debugPrint('[Device] RAM: $ram MB · models sa server: ${configs.length}');
      if (!mounted) return;
      setState(() {
        _ramMb = ram;
        if (configs.isNotEmpty) {
          _configs = {for (final c in configs) c.tier: c};
        }
      });
    } catch (e) {
      debugPrint('Loading brain info failed: $e');
    }
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

  ModelInfo _info(ModelTier tier) => _models[tier] ?? ModelInfo.empty(tier);

  /// Pangalang pinapakita: galing sa Supabase, o fallback kapag offline.
  String _name(ModelTier tier) =>
      _configs[tier]?.displayName ?? AiConstants.fallbackName(tier);

  /// Ang model na talagang gamit ni Zoe: ang pinili kung ready,
  /// kung hindi ay ang isa pa kung ready. null = walang ready.
  ModelTier? get _inUse {
    if (_info(_activeTier).isReady) return _activeTier;
    final other = _activeTier.other;
    return _info(other).isReady ? other : null;
  }

  /// Laging kita ang Zoe Lite. Ang Zoe Plus ay kita lang kapag
  /// nasa phone na ito, o inaalok ng server sa build na ito.
  bool _visible(ModelTier tier) {
    if (tier == ModelTier.lite) return true;
    final status = _info(tier).status;
    if (status != null && status != ModelStatus.skipped) return true;
    final config = _configs[tier];
    return config != null && config.minAppBuild <= AppConfig.build;
  }

  /// Hindi null kapag kulang ang RAM ng phone para sa model na ito.
  /// Hindi nila-lock ang model na ready na sa phone.
  String? _lockedNote(ModelTier tier) {
    final config = _configs[tier];
    final ram = _ramMb;
    if (config == null || ram == null || config.minRamMb <= 0) return null;
    if (_info(tier).isReady || ram >= config.minRamMb) return null;
    final gb = (config.minRamMb / 1024).ceil();
    return 'Kailangan ng $gb GB RAM pataas';
  }

  /// Bawat update ng ModelDownloader: i-refresh ang card; snackbar sa dulo.
  void _onDownloadProgress() {
    if (!mounted) return;
    final pr = _downloader.progress.value;
    setState(() {});
    switch (pr.phase) {
      case DownloadPhase.done:
        _loadModels();
        ZoeSnack.show(context, '${_name(pr.tier)} is ready 🧠✨');
      case DownloadPhase.failed:
        _loadModels();
        ZoeSnack.show(context, pr.message ?? 'Download failed', error: true);
      case DownloadPhase.cancelled:
        _loadModels();
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

  /// [Download] / [Resume]: kunin ang config sa Supabase → RAM at storage
  /// check → confirm → start.
  Future<void> _downloadModel(ModelTier tier) async {
    if (_downloader.isRunning) {
      ZoeSnack.show(context, 'May dina-download pa. Hintayin munang matapos.');
      return;
    }
    setState(() => _busy = true);
    try {
      final net = await _network();
      if (net == 'none') {
        if (mounted) ZoeSnack.show(context, 'No internet. Connect to Wi-Fi first.', error: true);
        return;
      }
      final config = await _downloader.latestConfig(tier);
      if (!mounted) return;
      if (config == null) {
        ZoeSnack.show(context, "Couldn't reach Zoe's server. Try again later.", error: true);
        return;
      }

      // Kaya ba ng phone? (Zoe Plus: 6 GB RAM pataas)
      if (config.minRamMb > 0) {
        final ram = _ramMb ?? await DeviceMemory.totalRamMb();
        if (!mounted) return;
        if (ram != null && ram < config.minRamMb) {
          ZoeSnack.show(context, 'Kulang ang RAM ng phone para sa ${config.displayName}.',
              error: true);
          return;
        }
      }

      // May sapat bang space? (hindi na chine-check kapag Resume)
      final resuming = _info(tier).isDownloading;
      if (!resuming) {
        final free = await DeviceMemory.freeStorageMb();
        if (!mounted) return;
        final needMb = config.sizeBytes ~/ (1024 * 1024) + _storageMarginMb;
        if (free != null && free < needMb) {
          ZoeSnack.show(
              context,
              'Kulang ang storage. Kailangan ng mga '
              '${BrainCard.formatBytes(needMb * 1024 * 1024)} na free space.',
              error: true);
          return;
        }
      }

      final size = BrainCard.formatBytes(config.sizeBytes);
      final ok = await confirmAction(
        context,
        palette: _p,
        danger: false,
        title: resuming ? 'Resume download?' : 'Download ${config.displayName}?',
        message: net == 'mobile'
            ? 'Naka-mobile data ka. $size ang model na ito — mas mainam sa Wi-Fi. '
                'Ituloy pa rin?'
            : '$size ang model (v${config.version}). Isang beses lang ito. '
                'Huwag isara si Zoe hanggang matapos.',
        confirmLabel: resuming ? 'Resume' : 'Download',
      );
      if (!ok || !mounted) return;
      _downloader.start(tier); // hindi ina-await — live update sa card
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelDownload() => _downloader.cancel();

  /// [Update]: ikumpara ang naka-install sa active model sa Supabase.
  Future<void> _updateModel(ModelTier tier) async {
    if (_downloader.isRunning) {
      ZoeSnack.show(context, 'May dina-download pa. Hintayin munang matapos.');
      return;
    }
    setState(() => _busy = true);
    try {
      final config = await _downloader.latestConfig(tier);
      if (!mounted) return;
      if (config == null) {
        ZoeSnack.show(context, "Couldn't check for updates. Try again later.", error: true);
        return;
      }
      if (config.version == _info(tier).version) {
        ZoeSnack.show(context, '${config.displayName} is up to date (v${config.version})');
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
      // deleteModel() ay lumilipat sa kabilang model kapag ito ang pinili;
      // ibalik ang pili para ito pa rin ang gamit pagkatapos ng update.
      final wasChosen = _activeTier == tier;
      await _settings.deleteModel(tier);
      if (wasChosen) await _settings.setActiveTier(tier);
      await _downloader.clearPartials(config.modelName);
      await _loadModels();
      _downloader.start(tier);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteModel(ModelTier tier) async {
    final name = _name(tier);
    final other = tier.other;
    final otherReady = _info(other).isReady;
    final String message;
    if (otherReady) {
      final switching =
          _inUse == tier ? 'Lilipat si Zoe sa ${_name(other)}. ' : '';
      message = 'Matatanggal ang $name sa phone mo. $switching'
          'Hindi mabubura ang tasks, reminders at notes mo.';
    } else {
      message = 'Matatanggal ang AI model sa phone mo. Hindi muna makakapag-chat si Zoe '
          'hanggang i-download mo ulit. Hindi mabubura ang tasks, reminders at notes mo.';
    }
    final ok = await confirmAction(
      context,
      palette: _p,
      title: 'Delete $name?',
      message: message,
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    var freed = 0;
    // .part ng model na ito lang ang buburahin.
    final fileName = _configs[tier]?.modelName ?? _info(tier).modelName;
    await _save(() async {
      freed = await _settings.deleteModel(tier);
      await _downloader.clearPartials(fileName);
    });
    await _loadModels();
    if (!mounted) return;
    setState(() => _busy = false);
    ZoeSnack.show(context,
        freed > 0 ? 'Deleted — ${BrainCard.formatBytes(freed)} freed' : '$name removed');
  }

  /// [Gamitin]: piliin ang model na ito bilang gamit ni Zoe.
  Future<void> _useModel(ModelTier tier) async {
    if (!_info(tier).isReady) return;
    await _save(() => _settings.setActiveTier(tier),
        ok: 'Si ${_name(tier)} na ang gamit ni Zoe ✨');
    await _loadModels();
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

  /// ON → magbibilang si Zoe. OFF → titigil at buburahin ang laman (may confirm).
  Future<void> _setMoodLog(bool on) async {
    if (!on) {
      final ok = await confirmAction(
        context,
        palette: _p,
        title: 'I-off ang mood log?',
        message: 'Hindi na magbibilang si Zoe kung ilang araw kang pagod o stressed, '
            'at mabubura ang laman ngayon. Pwede mo itong i-on ulit kahit kailan.',
        confirmLabel: 'I-off',
      );
      if (!ok || !mounted) return;
    }
    await _save(() => _moodLog.setEnabled(on),
        ok: on ? 'Mood log ON — sa phone mo lang 🔒' : 'Mood log OFF — nabura na ang laman');
    if (mounted) setState(() {});
    await _loadCounts();
  }

  Future<void> _clearMoodLog() async {
    final ok = await confirmAction(
      context,
      palette: _p,
      title: 'Burahin ang mood log?',
      message: 'Mabubura ang bilang ng pagod, stressed at iba pa sa huling 7 araw. '
          'Hindi ito mababawi. Hindi mabubura ang chats, tasks, reminders at notes.',
      confirmLabel: 'Burahin',
    );
    if (!ok) return;
    await _save(_moodLog.clearAll, ok: 'Nabura na ang mood log');
  }

  /// Iisang "Burahin lahat ng data" (DataWipe). Isang tanong lang —
  /// malinaw ang mabubura at hindi mababawi. Pagkatapos: dito pa rin sa app.
  Future<void> _wipeAll() async {
    final ok0 = await confirmAction(
      context,
      palette: _p,
      title: 'Burahin lahat ng data?',
      message: 'Mabubura ang lahat ng tasks, reminders (at alarms), notes, '
          'usapan ninyo ni Zoe, memories, mood at history. '
          'Hindi na ito mababawi.\n\n'
          'Maiiwan: pangalan mo, language, settings ng app, at ang na-download na Zoe.',
      confirmLabel: 'Burahin lahat',
    );
    if (!ok0 || !mounted) return;

    setState(() => _busy = true);
    final ok = await DataWipe.instance.wipeAll();
    if (!mounted) return;
    setState(() => _busy = false);
    ZoeSnack.show(
      context,
      ok ? 'Nabura na lahat. Bagong simula tayo 🌱' : "Hindi natapos ang pagbura. Subukan ulit.",
      error: !ok,
    );
    await _load();
  }

  /// "Pagod 2 · Stressed 1 · Masaya 3" — o "Wala pa" kapag walang laman.
  String _moodWeekSubtitle() {
    if (!_moodLog.enabled.value) return 'OFF';
    if (_moodWeek.isEmpty) return 'Wala pa sa huling 7 araw';
    const order = [
      (UserTone.tired, 'Pagod'),
      (UserTone.stressed, 'Stressed'),
      (UserTone.sad, 'Malungkot'),
      (UserTone.upset, 'Inis'),
      (UserTone.worried, 'Kabado'),
      (UserTone.happy, 'Masaya'),
    ];
    return [
      for (final (tone, label) in order)
        if (_moodWeek.count(tone) > 0) '$label ${_moodWeek.count(tone)}',
    ].join(' · ');
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
    final inUse = _inUse;
    final runningTier = _downloader.runningTier;

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

                      // 3. Zoe's Brain — isang card kada model
                      SettingsSection("Zoe's brain", palette: p),
                      for (final tier in ModelTier.values)
                        if (_visible(tier)) ...[
                          if (tier != ModelTier.lite) const SizedBox(height: 14),
                          BrainCard(
                            tier: tier,
                            title: _name(tier),
                            description: _configs[tier]?.description,
                            info: _info(tier),
                            progress: _downloader.progress.value,
                            palette: p,
                            busy: _busy,
                            active: inUse == tier,
                            lockedNote: _lockedNote(tier),
                            otherBusy: runningTier != null && runningTier != tier,
                            downloadBytes: _configs[tier]?.sizeBytes,
                            onDownload: () => _downloadModel(tier),
                            onCancel: _cancelDownload,
                            onUpdate: () => _updateModel(tier),
                            onDelete: () => _deleteModel(tier),
                            onUse: () => _useModel(tier),
                          ),
                        ],

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
                        title: MemoriesScreen.title,
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
                      ),
                      SettingsTile.toggle(
                        icon: Icons.insights_outlined,
                        title: 'Mood log (7 araw)',
                        subtitle: _moodLog.enabled.value
                            ? 'Bilang lang ng pagod, stressed… sa phone mo lang. '
                                'Kusang nabubura after 7 days.'
                            : 'OFF — hindi nagbibilang si Zoe',
                        value: _moodLog.enabled.value,
                        onChanged: _setMoodLog,
                        palette: p,
                      ),
                      SettingsTile(
                        icon: Icons.calendar_view_week_outlined,
                        title: 'Ngayong linggo',
                        subtitle: _moodWeekSubtitle(),
                        palette: p,
                        trailing: _ClearButton(
                          palette: p,
                          label: 'Burahin',
                          onTap: _moodWeek.isEmpty ? null : _clearMoodLog,
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.delete_forever_outlined,
                        title: 'Burahin lahat ng data',
                        subtitle: 'Tasks, reminders, notes, chats, memories at mood. '
                            'Maiiwan ang pangalan mo, settings at si Zoe (model).',
                        palette: p,
                        showDivider: false,
                        trailing: _ClearButton(
                          palette: p,
                          label: _busy ? '…' : 'Burahin',
                          onTap: _busy ? null : _wipeAll,
                        ),
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
  final String label;
  const _ClearButton({required this.palette, required this.onTap, this.label = 'Clear'});

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
      child: Text(label, style: SettingsText.button),
    );
  }
}