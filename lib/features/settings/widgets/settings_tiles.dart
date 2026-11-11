import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

/// "PREFERENCES", "PRIVACY & DATA", … label sa itaas ng bawat grupo.
class SettingsSection extends StatelessWidget {
  final String label;
  final SettingsPalette palette;

  const SettingsSection(this.label, {super.key, required this.palette});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
        child: Text(label.toUpperCase(), style: SettingsText.section(palette)),
      );
}

/// Isang row: icon (rounded square) · title + subtitle · trailing.
/// trailing = switch, chevron, o kahit anong widget.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final SettingsPalette palette;
  final bool showDivider;
  final Color? iconColor;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.palette,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.iconColor,
  });

  /// Row na may chevron (bubukas ng ibang screen / sheet).
  factory SettingsTile.nav({
    Key? key,
    required IconData icon,
    required String title,
    required SettingsPalette palette,
    String? subtitle,
    Color? subtitleColor,
    required VoidCallback onTap,
    bool showDivider = true,
    Color? iconColor,
  }) =>
      SettingsTile(
        key: key,
        icon: icon,
        title: title,
        palette: palette,
        subtitle: subtitle,
        subtitleColor: subtitleColor,
        onTap: onTap,
        showDivider: showDivider,
        iconColor: iconColor,
        trailing: Icon(Icons.chevron_right_rounded, size: 30, color: palette.sectionLabel),
      );

  /// Row na may ON/OFF switch. Buong row ang tap target.
  factory SettingsTile.toggle({
    Key? key,
    required IconData icon,
    required String title,
    required SettingsPalette palette,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool showDivider = true,
  }) =>
      SettingsTile(
        key: key,
        icon: icon,
        title: title,
        palette: palette,
        subtitle: subtitle,
        showDivider: showDivider,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: ZoeSwitch(value: value, onChanged: onChanged, palette: palette),
      );

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return MergeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                border: showDivider
                    ? Border(bottom: BorderSide(color: palette.divider, width: 1.2))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: palette.iconBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: iconColor ?? palette.accent, size: 28),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: SettingsText.tileTitle(palette)),
                        if (sub != null && sub.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            style: SettingsText.tileSub(palette).copyWith(color: subtitleColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-style switch (gaya ng mockup): lavender kapag ON.
class ZoeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final SettingsPalette palette;

  const ZoeSwitch({super.key, required this.value, required this.onChanged, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 76,
          height: 42,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: value ? palette.accent : palette.switchOff,
            borderRadius: BorderRadius.circular(21),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// English / Tagalog / Both — tatlong pill, isa lang ang selected.
class SettingsSegmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final SettingsPalette palette;

  const SettingsSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: Semantics(
                selected: values[i] == selected,
                button: true,
                child: Material(
                  color: values[i] == selected ? palette.accent : palette.pillBg,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      if (values[i] == selected) return;
                      HapticFeedback.selectionClick();
                      onChanged(values[i]);
                    },
                    child: SizedBox(
                      height: 74,
                      child: Center(
                        child: Text(
                          label(values[i]),
                          style: SettingsText.pill.copyWith(
                            color: values[i] == selected ? Colors.white : palette.pillText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i < values.length - 1) const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }
}