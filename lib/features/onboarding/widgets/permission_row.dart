import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';
import 'package:zoe_remind/core/theme/colors.dart';
import 'package:zoe_remind/features/onboarding/widgets/zoe_icon.dart';

/// One permission card: icon, why it's needed, and an Allow button
/// that turns into a check once granted.
class PermissionRow extends StatelessWidget {
  const PermissionRow({
    super.key,
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onAllow,
  });

  final String iconPath;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: ZoeIcon(iconPath, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: granted
                ? Semantics(
                    key: const ValueKey('granted'),
                    label: '$title allowed',
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const ZoeIcon(
                        ZoeAssets.icCheckLavender,
                        size: 18,
                      ),
                    ),
                  )
                : FilledButton(
                    key: const ValueKey('allow'),
                    onPressed: onAllow,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ZoeColors.lavenderDeep,
                      minimumSize: const Size(72, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Allow'),
                  ),
          ),
        ],
      ),
    );
  }
}