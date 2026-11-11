import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
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
  static const _kDeveloper = 'developer_unlocked';

  static const maxName = 30;

  // ───────────────────────── Onboarding ─────────────────────────

  Future<bool> isOnboardingDone() async =>
      await _get(_kOnboardingDone) == 'true';

  /// Saves everything from onboarding in one transaction: all or nothing.
  /// The onboarding_done flag is written last.
  Future<void> completeOnboarding(OnboardingResult result) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final status =
        result.downloadModel ? ModelStatus.pending : ModelStatus.skipped;

    await db.transaction((txn) async {
      await _put(txn, _kLanguage, result.language.name, now);
      await txn.insert(
        'model_state',
        {'id': 1, 'status': status.name, 'updated_at': now},
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

  Future<bool> isDeveloperUnlocked() async => await _get(_kDeveloper) == 'true';
  Future<void> setDeveloperUnlocked(bool on) => setValue(_kDeveloper, '$on');

  // ───────────────────────── Zoe's Brain (model_state) ─────────────────────────

  Future<ModelStatus?> getModelStatus() async => (await getModelInfo()).status;

  Future<ModelInfo> getModelInfo() async {
    final db = await _db.database;
    final rows = await db.query('model_state', where: 'id = 1', limit: 1);
    return rows.isEmpty ? ModelInfo.none : ModelInfo.fromRow(rows.first);
  }

  /// [Download] → pending (kukunin ng downloader). Cancel → skipped.
  Future<void> setModelStatus(ModelStatus status) async {
    final db = await _db.database;
    await db.insert(
      'model_state',
      {'id': 1, 'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    changes.value++;
  }

  /// Tinatawag ng downloader kapag na-verify ang checksum.
  Future<void> registerModel({
    required String version,
    required String filePath,
    required int sizeBytes,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'model_state',
      {
        'id': 1,
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
  Future<int> deleteModel() async {
    final info = await getModelInfo();
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
    await setModelStatus(ModelStatus.skipped); // REPLACE → version/path/size = null
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