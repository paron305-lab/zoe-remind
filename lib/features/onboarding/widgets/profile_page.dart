import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';
import 'package:zoe_remind/core/constants/policy.dart';
import 'package:zoe_remind/core/theme/colors.dart';
import 'package:zoe_remind/features/onboarding/widgets/floating_logo.dart';
import 'package:zoe_remind/features/onboarding/widgets/glass_pill.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_styles.dart';
import 'package:zoe_remind/features/onboarding/widgets/zoe_icon.dart';

/// Step 4 — name, age, and agreeing to the Terms & Privacy Policy.
/// The text controllers live in OnboardingScreen so typing survives
/// going Back and forth.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.nameController,
    required this.ageController,
    required this.ageError,
    required this.policyAccepted,
    required this.onPolicyChanged,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final String? ageError;
  final bool policyAccepted;
  final ValueChanged<bool> onPolicyChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          const FloatingLogo(size: 80),
          const SizedBox(height: 20),
          const Text(
            "Let's get to know you",
            style: OnboardingStyles.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'So I can greet you properly.',
            style: OnboardingStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _ZoeField(
            label: 'Your name',
            hint: 'e.g. Juan',
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
          ),
          const SizedBox(height: 16),
          _ZoeField(
            label: 'Your age',
            hint: 'e.g. 24',
            controller: ageController,
            errorText: ageError,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
          ),
          const SizedBox(height: 22),
          _PolicyCheck(value: policyAccepted, onChanged: onPolicyChanged),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showPolicySheet(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
              child: const Text('Read Terms & Privacy Policy'),
            ),
          ),
          const SizedBox(height: 12),
          const GlassPill(
            iconPath: ZoeAssets.icLock,
            iconSize: 18,
            label: 'Saved only on this phone.',
          ),
        ],
      ),
    );
  }
}

/// White-on-glass text field with a label above it.
class _ZoeField extends StatelessWidget {
  const _ZoeField({
    required this.label,
    required this.hint,
    required this.controller,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            cursorColor: Colors.white,
            style: const TextStyle(fontSize: 16, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              errorText: errorText,
              errorMaxLines: 2,
              errorStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.16),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              enabledBorder:
                  _border(Colors.white.withValues(alpha: 0.35), 1),
              focusedBorder: _border(Colors.white, 2),
              errorBorder: _border(ZoeColors.coral, 2),
              focusedErrorBorder: _border(ZoeColors.coral, 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// "I agree" checkbox. The whole row is the tap target.
class _PolicyCheck extends StatelessWidget {
  const _PolicyCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: value
                      ? const ZoeIcon(ZoeAssets.icCheckLavender, size: 16)
                      : null,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "I've read and agree to Zoe's Terms & Privacy Policy.",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with the policy summary from ZoePolicy.
void showPolicySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          const Text(
            'Terms & Privacy Policy',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ZoeColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${ZoePolicy.version}',
            style: TextStyle(
              fontSize: 13,
              color: ZoeColors.ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          for (final section in ZoePolicy.sections) ...[
            Text(
              section.title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ZoeColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              section.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: ZoeColors.ink.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: ZoeColors.lavenderDeep,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    ),
  );
}