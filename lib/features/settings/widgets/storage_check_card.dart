import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/core/services/data_wipe.dart';
import 'package:zoe_remind/database/repositories/wipe_repository.dart';

/// Developer › "Storage": bilang ng rows sa bawat table ng user,
/// naka-ON ba ang secure_delete, at ang huling error ng "Burahin lahat".
/// Pagkatapos ng wipe: dapat 0 lahat (task_categories = 7 default).
class StorageCheckCard extends StatefulWidget {
  const StorageCheckCard({super.key});

  @override
  State<StorageCheckCard> createState() => _StorageCheckCardState();
}

class _StorageCheckCardState extends State<StorageCheckCard> {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);

  final _repo = WipeRepository();
  Map<String, int> _counts = const {};
  bool? _secureDelete;

  @override
  void initState() {
    super.initState();
    DataWipe.instance.done.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DataWipe.instance.done.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final counts = await _repo.counts();
      final secure = await _repo.secureDeleteOn();
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _secureDelete = secure;
      });
    } catch (e) {
      debugPrint('Storage check failed: $e');
    }
  }

  /// Malinis = 0 lahat, maliban sa task_categories (default 7).
  bool get _clean => _counts.entries.every(
      (e) => e.key == StorageConstants.taskCategoriesTable || e.value == 0);

  @override
  Widget build(BuildContext context) {
    final error = DataWipe.instance.lastError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _secureDelete == null
                  ? 'checking…'
                  : (_secureDelete! ? '✅ secure_delete ON' : '❌ secure_delete OFF'),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _secureDelete == false ? _coral : _mint),
            ),
            Text(
              _clean ? '🧹 Walang data ng user (malinis)' : 'May laman pa',
              style: TextStyle(fontSize: 13, color: _clean ? _mint : _lavender),
            ),
            const SizedBox(height: 6),
            for (final e in _counts.entries)
              Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 13)),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text('⚠️ $error', style: const TextStyle(fontSize: 13, color: _coral)),
            ],
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}