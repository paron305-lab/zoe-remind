import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/ai_constants.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

/// Settings › Zoe's Brain: status · version · size + [Download] [Update] [Delete].
/// Binabasa ang model_state. Ang totoong download (Supabase) ay idadagdag
/// sa model downloader — dito naka-queue lang ito bilang "pending".
class BrainCard extends StatelessWidget {
  final ModelInfo info;
  final SettingsPalette palette;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const BrainCard({
    super.key,
    required this.info,
    required this.palette,
    required this.busy,
    required this.onDownload,
    required this.onCancel,
    required this.onUpdate,
    required this.onDelete,
  });

  (String, Color) _status() => switch (info.status) {
        ModelStatus.ready => ('Ready', palette.mint),
        ModelStatus.downloading => ('Downloading…', palette.accent),
        ModelStatus.pending => ('Waiting to download', palette.amber),
        ModelStatus.failed => ('Download failed', palette.coral),
        ModelStatus.skipped || null => ('Not downloaded', palette.inkSoft),
      };

  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  String get _size {
    final b = info.sizeBytes;
    if (b != null && b > 0) return formatBytes(b);
    return '~${AiConstants.estimatedSizeMb} MB download';
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status();
    final explain = switch (info.status) {
      ModelStatus.ready => 'Zoe thinks on your phone — no internet needed.',
      ModelStatus.pending || ModelStatus.downloading =>
        'Zoe will get her brain when you are online. The rest of the app works as usual.',
      ModelStatus.failed => 'Something went wrong. Try downloading again.',
      _ => 'Download once so Zoe can chat and understand you, even offline.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.divider, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: palette.iconBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.psychology_alt_rounded, color: palette.accent, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AiConstants.modelName, style: SettingsText.tileTitle(palette)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(label,
                                style: SettingsText.tileSub(palette)
                                    .copyWith(color: color, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow('Version', info.version == null ? '—' : 'v${info.version}', palette),
            _InfoRow('Size', _size, palette),
            const SizedBox(height: 10),
            Text(explain, style: SettingsText.body(palette)),
            if (info.isDownloading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  color: palette.accent,
                  backgroundColor: palette.pillBg,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(children: _buttons()),
          ],
        ),
      ),
    );
  }

  List<Widget> _buttons() {
    final primary = switch (info.status) {
      ModelStatus.ready => _Btn('Update', Icons.system_update_alt_rounded, onUpdate, palette,
          filled: true, enabled: !busy),
      ModelStatus.pending || ModelStatus.downloading =>
        _Btn('Cancel', Icons.close_rounded, onCancel, palette, filled: false, enabled: !busy),
      _ => _Btn('Download', Icons.download_rounded, onDownload, palette,
          filled: true, enabled: !busy),
    };
    return [
      Expanded(child: primary),
      const SizedBox(width: 12),
      Expanded(
        child: _Btn('Delete', Icons.delete_outline_rounded, onDelete, palette,
            filled: false, danger: true, enabled: !busy && info.canDelete),
      ),
    ];
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final SettingsPalette palette;
  const _InfoRow(this.label, this.value, this.palette);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(label, style: SettingsText.body(palette)),
            const Spacer(),
            Text(value,
                style: SettingsText.body(palette)
                    .copyWith(color: palette.ink, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final SettingsPalette palette;
  final bool filled;
  final bool danger;
  final bool enabled;

  const _Btn(this.label, this.icon, this.onTap, this.palette,
      {required this.filled, this.danger = false, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : (danger ? palette.coral : palette.accent);
    final bg = filled ? palette.accent : Colors.transparent;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: filled
              ? BorderSide.none
              : BorderSide(color: fg.withValues(alpha: 0.55), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
                Text(label, style: SettingsText.button.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}