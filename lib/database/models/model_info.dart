import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// Isang row ng model_state (id = 1): ang estado ng Zoe's Brain.
class ModelInfo {
  const ModelInfo({
    required this.status,
    this.version,
    this.sizeBytes,
    this.filePath,
    this.verifiedAt,
    this.updatedAt,
  });

  /// null = wala pang row (hal. luma ang install bago ang onboarding).
  final ModelStatus? status;
  final String? version;
  final int? sizeBytes;
  final String? filePath;
  final DateTime? verifiedAt;
  final DateTime? updatedAt;

  static const none = ModelInfo(status: null);

  bool get isReady => status == ModelStatus.ready;
  bool get isQueued => status == ModelStatus.pending;
  bool get isDownloading => status == ModelStatus.downloading;

  /// Pwedeng pindutin ang [Download].
  bool get canDownload =>
      status == null || status == ModelStatus.skipped || status == ModelStatus.failed;

  /// May file o naka-queue → pwedeng i-delete / i-cancel.
  bool get canDelete =>
      status == ModelStatus.ready || status == ModelStatus.failed || filePath != null;

  static ModelInfo fromRow(Map<String, Object?> row) => ModelInfo(
        status: ModelStatus.values.asNameMap()[row['status']],
        version: row['model_version'] as String?,
        sizeBytes: row['size_bytes'] as int?,
        filePath: row['file_path'] as String?,
        verifiedAt: DateTime.tryParse((row['verified_at'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((row['updated_at'] as String?) ?? ''),
      );
}