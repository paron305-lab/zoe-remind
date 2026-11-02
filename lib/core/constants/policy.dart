/// One section of the in-app policy summary.
class PolicySection {
  const PolicySection(this.title, this.body);

  final String title;
  final String body;
}

class ZoePolicy {
  ZoePolicy._();

  /// Bump this whenever the policy text changes, so the database
  /// shows which version each user agreed to.
  static const version = 'draft-2026-10';

  /// Minimum age to use Zoe. 13 is common app-store practice;
  /// confirm the right number for your release.
  static const minAge = 13;
  static const maxAge = 120;

  /// TEMPORARY in-app summary. Replace with your real
  /// Terms of Service and Privacy Policy before release.
  static const sections = [
    PolicySection(
      'Your data stays on your phone',
      "Your tasks, reminders, notes, chats, name and age are saved only in "
          "Zoe's database on this device. Zoe has no account or login, and "
          'nothing you write is uploaded.',
    ),
    PolicySection(
      'The AI model download',
      "If you choose to download Zoe's AI brain, the app connects to the "
          'internet only to fetch the model file and check that it downloaded '
          'correctly. No personal data is sent.',
    ),
    PolicySection(
      'Permissions',
      'Notifications and exact alarms are used only to show your reminders '
          "on time. You can turn them off anytime in your phone's Settings.",
    ),
    PolicySection(
      'Deleting your data',
      "Clearing Zoe's storage or uninstalling the app removes everything "
          'Zoe saved on this device.',
    ),
    PolicySection(
      'Full policy',
      '[Add your full Terms of Service and Privacy Policy here before release.]',
    ),
  ];
}