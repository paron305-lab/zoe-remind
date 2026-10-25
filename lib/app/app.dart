import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class ZoeApp extends StatelessWidget {
  const ZoeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zoe-Remind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}

