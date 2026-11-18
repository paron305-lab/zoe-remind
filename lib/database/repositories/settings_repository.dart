import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/model_tier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/features/onboarding/models/onboarding_result.dart';

/// AI model status in model_state.
/// pending = user tapped "Let's get my brain ready" (downloader picks it up later)
/// skipped = user tapped "Maybe later" (or deleted the model in Settings)
enum ModelStatus { pending, skipped, downloading, ready, failed }

/// Name + kailan nagsimula (user_profile, id = 1).
class UserProfile {
  const UserProfile({required this.name, this.createdAt});
  final String name;
  final DateTime? createdAt;
}

class SettingsRepository {
  SettingsRepository({ZoeDatabase? db}) : _db = db ?? ZoeDatabase.instance;

  final ZoeDatabase _db;

  /// Tumataas kada may nabago sa profile / language / model,
  /// para mag-refresh ang Home (pangalan) at Zoe Chat (language).
  static final changes = ValueNotifier<int>(0);

  static const _kOnboardingDone = 'onboarding_done';
  static const _kLanguage = 'language_mode';
  static const _kDarkMode = 'dark_mode';
  static const _kLongTermMemory = 'long_term_memory';
  static const _kMoodLog = 'mood_log';
  static const _kMoodLogNotedOn = 'mood_log_noted_on';
  static const _kDeveloper = 'developer_unlocked';
  static const _kActiveModel = 'active_model';

  static const maxName = 30;

  // ───────────────────────── Onboarding ─────────────────────────

  Future<bool> isOnboardingDone() async =>
      await _get(_kOnboardingDone) == 'true';

  /// Saves everything from onboarding in one transaction: all or nothing.
  /// The onboarding_done flag is written last.
  /// Zoe Lite lang ang dina-download sa onboarding.
  Future<void> completeOnboarding(OnboardingResult result) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final status =
        result.downloadModel ? ModelStatus.pending : ModelStatus.skipped;

    await db.transaction((txn) async {
      await _put(txn, _kLanguage, result.language.name, now);
      await txn.insert(
        'model_state',
        {
          'id': ModelTier.lite.rowId,
          'tier': ModelTier.lite.name,
          'status': status.name,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'user_profile',
        {
          'id': 1,
          'name': result.name,
          'age': result.age,
          'policy_version': result.policyVersion,
          'policy_accepted_at': now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _put(txn, _kOnboardingDone, 'true', now);
    });
  }

  // ───────────────────────── Profile ─────────────────────────

  Future<String?> getUserName() async => (await getProfile())?.name;

  Future<UserProfile?> getProfile() async {
    final db = await _db.database;
    final rows = await db.query('user_profile',
        columns: ['name', 'created_at'], where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile(
      name: (rows.first['name'] as String?) ?? '',
      createdAt: DateTime.tryParse((rows.first['created_at'] as String?) ?? ''),
    );
  }

  /// Palitan ang pangalan (Settings › Profile). Walang row → walang ginagawa.
  Future<void> setUserName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > maxName) {
      throw ArgumentError('Name must be 1–$maxName characters.');
    }
    final db = await _db.database;
    await db.update(
      'user_profile',
      {'name': clean, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = 1',
    );
    changes.value++;
  }

  // ───────────────────────── Zoe Chat language ─────────────────────────

  Future<ZoeLanguage> getLanguage() async {
    final value = await _get(_kLanguage);
    return ZoeLanguage.values.asNameMap()[value] ?? ZoeLanguage.both;
  }

  Future<void> setLanguage(ZoeLanguage language) async {
    await setValue(_kLanguage, language.name);
    changes.value++;
  }

  // ───────────────────────── Appearance / Privacy / Developer ─────────────────────────

  Future<bool> isDarkMode() async => await _get(_kDarkMode) == 'true';
  Future<void> setDarkMode(bool on) => setValue(_kDarkMode, '$on');

  /// Default ON. Kapag OFF, hindi magsasave ng bagong memories si Zoe.
  Future<bool> isLongTermMemoryOn() async => await _get(_kLongTermMemory) != 'false';
  Future<void> setLongTermMemory(bool on) => setValue(_kLongTermMemory, '$on');

  /// Mood log (7 araw). Default ON. Kapag OFF, walang binibilang si Zoe.
  Future<bool> isMoodLogOn() async => await _get(_kMoodLog) != 'false';
  Future<void> setMoodLog(bool on) => setValue(_kMoodLog, '$on');

  /// Araw ('yyyy-MM-dd') na huling nagsalita si Zoe tungkol sa linggo.
  /// '' = hindi pa. Para isang beses lang kada araw.
  Future<String> getMoodLogNotedOn() async => await _get(_kMoodLogNotedOn) ?? '';
  Future<void> setMoodLogNotedOn(String day) => setValue(_kMoodLogNotedOn, day);

  Future<bool> isDeveloperUnlocked() async => await _get(_kDeveloper) == 'true';
  Future<void> setDeveloperUnlocked(bool on) => setValue(_kDeveloper, '$on');

  // ───────────────────────── Zoe's Brain (model_state) ─────────────────────────
  //
  // Dalawang row: id 1 = Zoe Lite, id 2 = Zoe Plus.

  /// Aling model ang PINILI ng user (default: lite).
  /// Hindi ito garantiya na ready ang model — tingnan ang [getUsableModel].
  Future<ModelTier> getActiveTier() async =>
      ModelTier.fromName(await _get(_kActiveModel)) ?? ModelTier.lite;

  Future<void> setActiveTier(ModelTier tier) async {
    await setValue(_kActiveModel, tier.name);
    changes.value++;
  }

  Future<ModelStatus?> getModelStatus([ModelTier? tier]) async =>
      (await getModelInfo(tier)).status;

  /// May [tier] → ang row ng model na iyon.
  /// Walang tier → ang model na gamit ni Zoe ngayon ([getUsableModel]).
  /// Ito ang tinatawag ng Zoe Chat para malaman kung pwede nang mag-chat.
  Future<ModelInfo> getModelInfo([ModelTier? tier]) async {
    if (tier == null) return getUsableModel();
    final db = await _db.database;
    final rows = await db.query('model_state',
        where: 'id = ?', whereArgs: [tier.rowId], limit: 1);
    return rows.isEmpty ? ModelInfo.empty(tier) : ModelInfo.fromRow(rows.first);
  }

  /// Ang model na gamit ni Zoe ngayon:
  /// 1. ang pinili, kung ready;
  /// 2. kung hindi, ang isa pa, kung ready;
  /// 3. kung walang ready, ang kasalukuyang dina-download / naka-queue;
  /// 4. kung wala rin, ang row ng pinili (hal. "not downloaded").
  Future<ModelInfo> getUsableModel() async {
    final chosen = await getActiveTier();
    final a = await getModelInfo(chosen);
    if (a.isReady) return a;
    final b = await getModelInfo(chosen.other);
    if (b.isReady) return b;
    if (a.isDownloading || a.isQueued) return a;
    if (b.isDownloading || b.isQueued) return b;
    return a;
  }

  /// Ang row ng model na pinili ng user (kahit hindi pa ready).
  Future<ModelInfo> getActiveModelInfo() async =>
      getModelInfo(await getActiveTier());

  /// Lahat ng tier, kahit wala pang row (status = null).
  Future<Map<ModelTier, ModelInfo>> getAllModels() async {
    final result = <ModelTier, ModelInfo>{};
    for (final tier in ModelTier.values) {
      result[tier] = await getModelInfo(tier);
    }
    return result;
  }

  /// [Download] → pending (kukunin ng downloader). Cancel → skipped.
  Future<void> setModelStatus(
    ModelStatus status, {
    ModelTier tier = ModelTier.lite,
  }) async {
    final db = await _db.database;
    await db.insert(
      'model_state',
      {
        'id': tier.rowId,
        'tier': tier.name,
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    changes.value++;
  }

  /// Tinatawag ng downloader kapag na-verify ang checksum.
  Future<void> registerModel({
    ModelTier tier = ModelTier.lite,
    String? modelName,
    required String version,
    required String filePath,
    required int sizeBytes,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'model_state',
      {
        'id': tier.rowId,
        'tier': tier.name,
        'model_name': modelName,
        'status': ModelStatus.ready.name,
        'model_version': version,
        'file_path': filePath,
        'size_bytes': sizeBytes,
        'verified_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    changes.value++;
  }

  /// [Delete]: burahin ang model file sa phone + i-reset ang model_state.
  /// Ligtas kahit wala pang file. Returns bytes na na-free (0 kung wala).
  /// Kapag ang ginagamit na model ang binura at ready ang isa,
  /// doon lilipat si Zoe.
  Future<int> deleteModel([ModelTier tier = ModelTier.lite]) async {
    final info = await getModelInfo(tier);
    var freed = 0;
    final path = info.filePath;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          freed = await file.length();
          await file.delete();
        }
      } catch (e) {
        debugPrint('Deleting model file failed: $e');
      }
    }
    // REPLACE → version/path/size = null
    await setModelStatus(ModelStatus.skipped, tier: tier);

    if (await getActiveTier() == tier) {
      final other = tier.other;
      if ((await getModelInfo(other)).isReady) await setActiveTier(other);
    }
    return freed;
  }

  // ───────────────────────── Key / value ─────────────────────────

  /// Generic key/value sa settings table (hal. Reminder Setup flags).
  Future<String?> getValue(String key) => _get(key);

  Future<void> setValue(String key, String value) async {
    final db = await _db.database;
    await _put(db, key, value, DateTime.now().toIso8601String());
  }

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query('settings',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _put(
      DatabaseExecutor ex, String key, String value, String now) async {
    await ex.insert(
      'settings',
      {'key': key, 'value': value, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}