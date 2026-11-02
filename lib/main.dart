import 'package:flutter/material.dart';
import 'package:zoe_remind/app/app.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the database before the first screen, so new users
  // land on onboarding and returning users land on Home.
  onboardingDone.value = await SettingsRepository().isOnboardingDone();

  runApp(const ZoeApp());
}