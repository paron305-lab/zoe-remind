import 'package:flutter/material.dart';
import 'package:zoe_remind/ai/model_manager/model_downloader.dart';
import 'package:zoe_remind/core/constants/ai_constants.dart';
import 'package:zoe_remind/core/constants/model_tier.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

/// Settings › Zoe's Brain: isang card kada model (Zoe Lite / Zoe Plus).
/// status · version · size + [Gamitin] [Download] [Update] [Delete].
/// Binabasa ang model_state (SQLite) at ang live progress ng [ModelDownloader].
class BrainCard extends StatelessWidget {
  final ModelTier tier;

  /// Pangalang pinapakita (hal. "Zoe Lite"), galing sa Supabase.
  final String title;
  final String? description;
  final ModelInfo info;

  /// Live progress mula sa ModelDownloader.instance.progress.
  /// Para sa card na ito lang kapag pareho ang tier.
  final DownloadProgress progress;
  final SettingsPalette palette;
  final bool busy;

  /// Ito ang model na ginagamit ni Zoe ngayon.
  final bool active;

  /// Hindi null = naka-lock ang card (hal. kulang ang RAM ng phone).
  final String? lockedNote;

  /// May ibang model na dina-download → bawal muna mag-Download dito.
  final bool otherBusy;

  /// Size ng download ayon sa server (kapag hindi pa na-download).
  final int? downloadBytes;

  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onUse;

  const BrainCard({
    super.key,
    required this.tier,
    required this.title,
    required this.info,
    required this.progress,
    required this.palette,
    required this.busy,
    required this.onDownload,
    required this.onCancel,
    required this.onUpdate,
    required this.onDelete,
    required this.onUse,
    this.description,
    this.active = false,
    this.lockedNote,
    this.otherBusy = false,
    this.downloadBytes,
  });

  bool get _running => progress.isActive && progress.tier == tier;

  /// Na-kill ang app habang nagda-download → may .part na pwedeng ituloy.
  bool get _paused => info.isDownloading && !_running;

  bool get _locked => lockedNote != null;

  /// Ready pero hindi ito ang ginagamit → may [Gamitin] button.
  bool get _canUse => info.isReady && !active && !_running;

  (String, Color) _status() {
    if (_running) {
      return switch (progress.phase) {
        DownloadPhase.fetchingConfig => ('Connecting…', palette.accent),
        DownloadPhase.verifying => ('Checking file…', palette.accent),
        _ => ('Downloading… ${progress.percent}%', palette.accent),
      };
    }
    return switch (info.status) {
      ModelStatus.ready => ('Ready', palette.mint),
      ModelStatus.downloading => ('Paused — tap Resume', palette.amber),
      ModelStatus.pending => ('Waiting to download', palette.amber),
      ModelStatus.failed => ('Download failed', palette.coral),
      ModelStatus.skipped || null => ('Not downloaded', palette.inkSoft),
    };
  }

  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  String get _size {
    if (_running && progress.total > 0) {
      return '${formatBytes(progress.received)} / ${formatBytes(progress.total)}';
    }
    final b = info.sizeBytes;
    if (b != null && b > 0) return formatBytes(b);
    final d = downloadBytes;
    if (d != null && d > 0) return '${formatBytes(d)} download';
    if (tier == ModelTier.lite) return '~${AiConstants.estimatedSizeMb} MB download';
    return '—';
  }

  String get _explain {
    if (_running) {
      return 'Keep Zoe open until this finishes. The rest of the app works as usual.';
    }
    return switch (info.status) {
      ModelStatus.ready => active
          ? 'Zoe thinks on your phone — no internet needed.'
          : (description ?? 'Ready to use. Tap Gamitin to switch.'),
      ModelStatus.downloading =>
        'Download was interrupted. Tap Resume to continue where it stopped.',
      ModelStatus.pending =>
        'Tap Download when you are on Wi-Fi. The rest of the app works as usual.',
      ModelStatus.failed => 'Something went wrong. Try downloading again.',
      _ => description ??
          'Download once so Zoe can chat and understand you, even offline.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: active ? palette.accent : palette.divider,
            width: active ? 2 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: _locked ? 0.5 : 1,
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
                        child: Icon(
                          tier == ModelTier.lite
                              ? Icons.psychology_alt_rounded
                              : Icons.auto_awesome_rounded,
                          color: palette.accent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: SettingsText.tileTitle(palette)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration:
                                      BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(label,
                                      style: SettingsText.tileSub(palette).copyWith(
                                          color: color, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: 10),
                        _Chip('Ginagamit', palette),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow('Version', info.version == null ? '—' : 'v${info.version}', palette),
                  _InfoRow('Size', _size, palette),
                  const SizedBox(height: 10),
                  Text(_explain, style: SettingsText.body(palette)),
                ],
              ),
            ),
            if (_running || _paused) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  // null = gumagalaw lang (connecting / verifying)
                  value: _running ? progress.fraction : 0,
                  color: palette.accent,
                  backgroundColor: palette.pillBg,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (_locked)
              _LockedNote(lockedNote!, palette)
            else ...[
              if (_canUse) ...[
                _Btn('Gamitin', Icons.check_circle_outline_rounded, onUse, palette,
                    filled: true, enabled: !busy),
                const SizedBox(height: 12),
              ],
              Row(children: _buttons()),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buttons() {
    final Widget primary;
    if (_running) {
      primary = _Btn('Cancel', Icons.close_rounded, onCancel, palette,
          filled: false, enabled: !busy);
    } else if (info.isReady) {
      // Kapag may [Gamitin] na sa itaas, outlined na lang ang Update.
      primary = _Btn('Update', Icons.system_update_alt_rounded, onUpdate, palette,
          filled: !_canUse, enabled: !busy && !otherBusy);
    } else if (_paused) {
      primary = _Btn('Resume', Icons.play_arrow_rounded, onDownload, palette,
          filled: true, enabled: !busy && !otherBusy);
    } else {
      primary = _Btn('Download', Icons.download_rounded, onDownload, palette,
          filled: true, enabled: !busy && !otherBusy);
    }
    return [
      Expanded(child: primary),
      const SizedBox(width: 12),
      Expanded(
        child: _Btn('Delete', Icons.delete_outline_rounded, onDelete, palette,
            filled: false,
            danger: true,
            enabled: !busy && !_running && (info.canDelete || _paused)),
      ),
    ];
  }
}

/// Maliit na "Ginagamit" chip sa card ng model na gamit ngayon.
class _Chip extends StatelessWidget {
  final String label;
  final SettingsPalette palette;
  const _Chip(this.label, this.palette);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.pillBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label,
            style: SettingsText.button.copyWith(fontSize: 13, color: palette.pillText)),
      );
}

/// Amber na paalala kapag naka-lock ang card (hal. kulang ang RAM).
class _LockedNote extends StatelessWidget {
  final String text;
  final SettingsPalette palette;
  const _LockedNote(this.text, this.palette);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.amber.withValues(alpha: palette.dark ? 0.18 : 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: palette.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: SettingsText.body(palette)
                      .copyWith(color: palette.amber, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
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