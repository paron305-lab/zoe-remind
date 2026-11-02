import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';
import 'package:zoe_remind/core/constants/policy.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/theme/colors.dart';
import 'package:zoe_remind/features/onboarding/controllers/onboarding_permissions.dart';
import 'package:zoe_remind/features/onboarding/models/onboarding_result.dart';
import 'package:zoe_remind/features/onboarding/widgets/language_page.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_background.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_buttons.dart';
import 'package:zoe_remind/features/onboarding/widgets/page_dots.dart';
import 'package:zoe_remind/features/onboarding/widgets/permissions_page.dart';
import 'package:zoe_remind/features/onboarding/widgets/profile_page.dart';
import 'package:zoe_remind/features/onboarding/widgets/welcome_page.dart';

/// First-launch flow:
/// Welcome → Language → Permissions + AI choice → Profile (name, age, policy).
///
/// Steps move only by buttons (no swiping), so nothing can be skipped.
/// Android back goes to the previous step.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.permissions = const OnboardingPermissions(),
  });

  /// Called once, with what the user chose. Save it and go to Home.
  final ValueChanged<OnboardingResult> onFinish;
  final OnboardingPermissions permissions;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 4;

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  int _page = 0;
  ZoeLanguage? _language;
  bool _notificationsGranted = false;
  bool _exactAlarmGranted = false;
  bool _downloadModel = false;
  bool _policyAccepted = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Exact alarms are granted in system Settings; re-check on return.
    _lifecycle = AppLifecycleListener(onResume: _refreshPermissions);
    _refreshPermissions();
    _nameController.addListener(_onFormChanged);
    _ageController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // ---------- Profile validation ----------

  void _onFormChanged() => setState(() {});

  String get _name => _nameController.text.trim();
  int? get _age => int.tryParse(_ageController.text);

  /// Shown under the age field. Null = no error (or not typed yet).
  String? get _ageError {
    if (_ageController.text.isEmpty) return null;
    final age = _age;
    if (age == null || age < 1 || age > ZoePolicy.maxAge) {
      return 'Please enter a valid age.';
    }
    if (age < ZoePolicy.minAge) {
      return 'You need to be at least ${ZoePolicy.minAge} to use Zoe.';
    }
    return null;
  }

  bool get _profileValid =>
      _name.isNotEmpty &&
      _ageController.text.isNotEmpty &&
      _ageError == null &&
      _policyAccepted;

  // ---------- Permissions ----------

  Future<void> _refreshPermissions() async {
    final notifications = await widget.permissions.notificationsGranted();
    final exactAlarm = await widget.permissions.exactAlarmGranted();
    if (!mounted) return;
    setState(() {
      _notificationsGranted = notifications;
      _exactAlarmGranted = exactAlarm;
    });
  }

  Future<void> _requestNotifications() async {
    final granted = await widget.permissions.requestNotifications();
    if (mounted) setState(() => _notificationsGranted = granted);
  }

  Future<void> _requestExactAlarm() async {
    final granted = await widget.permissions.requestExactAlarm();
    if (mounted) setState(() => _exactAlarmGranted = granted);
  }

  // ---------- Navigation ----------

  void _goTo(int page) {
    if (page < 0 || page >= _pageCount) return;
    FocusManager.instance.primaryFocus?.unfocus(); // close the keyboard
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// Both AI buttons record the choice, then go to the profile step.
  void _chooseDownload(bool download) {
    _downloadModel = download;
    _goTo(3);
  }

  void _finish() {
    if (_finished || !_profileValid) return; // ignore double taps
    _finished = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onFinish(
      OnboardingResult(
        language: _language ?? ZoeLanguage.both,
        downloadModel: _downloadModel,
        name: _name,
        age: _age!,
        policyVersion: ZoePolicy.version,
      ),
    );
  }

  Widget _primaryButton() => switch (_page) {
        0 => OnboardingPrimaryButton(
            label: 'Get started',
            onPressed: () => _goTo(1),
          ),
        1 => OnboardingPrimaryButton(
            label: 'Continue',
            onPressed: _language == null ? null : () => _goTo(2),
          ),
        2 => OnboardingPrimaryButton(
            label: "Let's get my brain ready",
            iconPath: ZoeAssets.icDownload,
            onPressed: () => _chooseDownload(true),
          ),
        _ => OnboardingPrimaryButton(
            label: 'Start using Zoe',
            onPressed: _profileValid ? _finish : null,
          ),
      };

  Widget _secondaryButton() => switch (_page) {
        0 => const SizedBox.shrink(),
        1 => OnboardingTextButton(label: 'Back', onPressed: () => _goTo(0)),
        2 => OnboardingTextButton(
            label: 'Maybe later',
            onPressed: () => _chooseDownload(false),
          ),
        _ => OnboardingTextButton(label: 'Back', onPressed: () => _goTo(2)),
      };

  @override
  Widget build(BuildContext context) {
    // Hide the dots while typing, to leave more room above the keyboard.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: _page == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _goTo(_page - 1);
        },
        child: Scaffold(
          backgroundColor: ZoeColors.lavender,
          body: OnboardingBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        const WelcomePage(),
                        LanguagePage(
                          selected: _language,
                          onSelected: (l) => setState(() => _language = l),
                        ),
                        PermissionsPage(
                          notificationsGranted: _notificationsGranted,
                          exactAlarmGranted: _exactAlarmGranted,
                          showExactAlarm: widget.permissions.isAndroid,
                          onAllowNotifications: _requestNotifications,
                          onAllowExactAlarm: _requestExactAlarm,
                        ),
                        ProfilePage(
                          nameController: _nameController,
                          ageController: _ageController,
                          ageError: _ageError,
                          policyAccepted: _policyAccepted,
                          onPolicyChanged: (v) =>
                              setState(() => _policyAccepted = v),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!keyboardOpen) ...[
                          PageDots(count: _pageCount, index: _page),
                          const SizedBox(height: 20),
                        ],
                        _primaryButton(),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 48,
                          child: Center(child: _secondaryButton()),
                        ),
                      ],
                    ),
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