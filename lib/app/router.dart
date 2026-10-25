import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/screens/home_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/notes/screens/notes_screen.dart';
import '../features/chat/screens/zoe_chat_screen.dart';
import '../features/settings/screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: SafeArea(child: shell),
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.check_circle_rounded), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.sticky_note_2_rounded), label: 'Notes'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
            NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/tasks', builder: (c, s) => const TasksScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/notes', builder: (c, s) => const NotesScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (c, s) => const ZoeChatScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen())]),
      ],
    ),
  ],
);

