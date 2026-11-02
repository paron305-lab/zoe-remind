import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';
import 'package:zoe_remind/features/onboarding/widgets/floating_logo.dart';
import 'package:zoe_remind/features/onboarding/widgets/glass_pill.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_page_body.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_styles.dart';
import 'package:zoe_remind/features/onboarding/widgets/permission_row.dart';

/// Step 3 — reminder permissions, then the AI download choice
/// (the download buttons live in the screen's bottom bar).
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({
    super.key,
    required this.notificationsGranted,
    required this.exactAlarmGranted,
    required this.showExactAlarm,
    required this.onAllowNotifications,
    required this.onAllowExactAlarm,
  });

  final bool notificationsGranted;
  final bool exactAlarmGranted;
  final bool showExactAlarm;
  final VoidCallback onAllowNotifications;
  final VoidCallback onAllowExactAlarm;

  @override
  Widget build(BuildContext context) {
    return OnboardingPageBody(
      children: [
        const Spacer(),
        const FloatingLogo(size: 88),
        const SizedBox(height: 24),
        const Text(
          'Almost ready!',
          style: OnboardingStyles.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Let me remind you on time. Then download my AI brain once, '
          'and I’ll work fully offline after that.',
          style: OnboardingStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PermissionRow(
          iconPath: ZoeAssets.icBell,
          title: 'Notifications',
          subtitle: 'So your reminders actually show up.',
          granted: notificationsGranted,
          onAllow: onAllowNotifications,
        ),
        if (showExactAlarm) ...[
          const SizedBox(height: 12),
          PermissionRow(
            iconPath: ZoeAssets.icAlarmClock,
            title: 'Exact alarms',
            subtitle: 'So I ring at the exact minute you set.',
            granted: exactAlarmGranted,
            onAllow: onAllowExactAlarm,
          ),
        ],
        const SizedBox(height: 20),
        const GlassPill(
          iconPath: ZoeAssets.icLock,
          iconSize: 18,
          label: 'Everything stays on your device. Always.',
        ),
        const Spacer(),
      ],
    );
  }
}