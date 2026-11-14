import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/zoe_avatar.dart';

class ReminderText {
  ReminderText._();
  static const _f = 'Poppins';

  static TextStyle get screenTitle => TextStyle(
      fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get label => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w700,
      color: HomeColors.inkSoft, letterSpacing: 0.4);
  static TextStyle get field => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get fieldHint => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w600,
      color: ZoeTheme.pick(const Color(0xFFAAA8B8), const Color(0xFF8E8BA3)));
  static TextStyle get banner => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500,
      color: HomeColors.ink, height: 1.45);
  static const chip = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700);
  static const button = TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white);
}

/// Lavender rounded-square back button.
class ReminderBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const ReminderBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.lavenderLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.arrow_back_rounded, color: HomeColors.lavender, size: 28),
        ),
      ),
    );
  }
}

enum BannerTone { ask, warn, ok }

/// Zoe's inline message at the top of the form (clarify / warn / confirm).
class ZoeHintBanner extends StatelessWidget {
  final BannerTone tone;
  final String text;
  final String? boldText;

  const ZoeHintBanner({super.key, required this.tone, required this.text, this.boldText});

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      BannerTone.ask => HomeColors.skyLight,
      BannerTone.warn => HomeColors.coralLight,
      BannerTone.ok => HomeColors.mintLight,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          const ZoeAvatar(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: ReminderText.banner,
                children: [
                  TextSpan(text: text),
                  if (boldText != null)
                    TextSpan(
                        text: boldText,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 28),
        child: Text(text.toUpperCase(), style: ReminderText.label),
      );
}

/// White rounded box with an icon + value (date / time / repeat).
class PickerField extends StatelessWidget {
  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool showChevron;

  const PickerField({
    super.key,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: HomeColors.divider, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          child: Row(
            children: [
              Icon(icon, color: HomeColors.lavender, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  value ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: value == null ? ReminderText.fieldHint : ReminderText.field,
                ),
              ),
              if (showChevron)
                Icon(Icons.chevron_right_rounded,
                    color: HomeColors.navInactive, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const QuickChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomeColors.lavender : HomeColors.lavenderLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          child: Text(
            label,
            style: ReminderText.chip
                .copyWith(color: selected ? Colors.white : HomeColors.lavender),
          ),
        ),
      ),
    );
  }
}

/// Full-width gradient CTA, the only commit action on the screen.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap; // null = disabled
  final bool loading;

  const GradientButton({super.key, required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B7FE0), Color(0xFF6C9BE8), Color(0xFF52C2B4)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: HomeColors.lavender.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: enabled ? onTap : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(label, style: ReminderText.button),
            ),
          ),
        ),
      ),
    );
  }
}