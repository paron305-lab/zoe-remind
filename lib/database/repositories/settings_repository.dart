import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/features/onboarding/models/onboarding_result.dart';

/// AI model status in model_state.
/// pending = user tapped "Let's get my brain ready" (downloader picks it up later)
/// skipped = user tapped "Maybe later"
enum ModelStatus { pending, skipped, downloading, ready, failed }

class SettingsRepository {
  SettingsRepository({ZoeDatabase? db}) : _db = db ?? ZoeDatabase.instance;

  final ZoeDatabase _db;

  static const _kOnboardingDone = 'onboarding_done';
  static const _kLanguage = 'language_mode';

  Future<bool> isOnboardingDone() async =>
      await _get(_kOnboardingDone) == 'true';

  Future<ZoeLanguage> getLanguage() async {
    final value = await _get(_kLanguage);
    return ZoeLanguage.values.asNameMap()[value] ?? ZoeLanguage.both;
  }

  Future<String?> getUserName() async {
    final db = await _db.database;
    final rows = await db.query('user_profile',
        columns: ['name'], where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : rows.first['name'] as String?;
  }

  Future<ModelStatus?> getModelStatus() async {
    final db = await _db.database;
    final rows = await db.query('model_state',
        columns: ['status'], where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return ModelStatus.values.asNameMap()[rows.first['status']];
  }

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