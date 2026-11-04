import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/widgets/zoe_bottom_nav.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/chat/screens/zoe_chat_screen.dart';
import 'package:zoe_remind/features/home/screens/home_screen.dart';
import 'package:zoe_remind/features/notes/screens/notes_screen.dart';
import 'package:zoe_remind/features/onboarding/screens/onboarding_screen.dart';
import 'package:zoe_remind/features/reminders/screens/new_reminder_screen.dart';
import 'package:zoe_remind/features/settings/screens/settings_screen.dart';
import 'package:zoe_remind/features/tasks/screens/tasks_screen.dart';

/// True once onboarding is saved. Set in main.dart at startup;
/// the router listens to it and moves the user automatically.
final onboardingDone = ValueNotifier<bool>(false);

final _settings = SettingsRepository();

final appRouter = GoRouter(
  initialLocation: '/home',
  refreshListenable: onboardingDone,

  // New user → /onboarding. Finished user → never sees onboarding again.
  redirect: (context, state) {
    final atOnboarding = state.matchedLocation == '/onboarding';
    if (!onboardingDone.value) return atOnboarding ? null : '/onboarding';
    if (atOnboarding) return '/home';
    return null;
  },

  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onFinish: (result) async {
          try {
            await _settings.completeOnboarding(result);
          } catch (e) {
            // If saving fails, onboarding simply shows again next launch.
            debugPrint('Saving onboarding failed: $e');
          }
          onboardingDone.value = true; // redirect sends the user to /home
        },
      ),
    ),

    // New Reminder — outside the shell → full screen, no bottom nav.
    // Opened from the + button on Home: context.push('/reminders/new')
    GoRoute(
      path: '/reminders/new',
      builder: (context, state) => const NewReminderScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        // No SafeArea here — each screen handles its own top inset,
        // so Home's gradient can sit behind the status bar.
        body: shell,
        bottomNavigationBar: ZoeBottomNav(
          currentIndex: shell.currentIndex,
          onTap: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
      // Order MUST match ZoeBottomNav: Home, Zoe, Tasks, Notes, Settings
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (c, s) => const ZoeChatScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/notes', builder: (c, s) => const NotesScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen())]),
      ],
    ),
  ],
);