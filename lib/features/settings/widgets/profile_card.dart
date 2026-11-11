import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/zoe_avatar.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

/// Hero gradient card: Zoe avatar + pangalan mo. Tap = palitan ang pangalan.
class ProfileCard extends StatelessWidget {
  final String name;
  final DateTime? since;
  final VoidCallback onEdit;

  const ProfileCard({super.key, required this.name, required this.since, required this.onEdit});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final s = since;
    final sub = s == null ? 'Tap to edit your name' : 'With Zoe since ${_months[s.month - 1]} ${s.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: SettingsPalette.heroGradient),
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
              child: Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const ZoeAvatar(size: 64, scale: 1.3),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Your name' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SettingsText.heroName,
                        ),
                        const SizedBox(height: 4),
                        Text(sub, style: SettingsText.heroSub),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22,
                        semanticLabel: 'Edit name'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}