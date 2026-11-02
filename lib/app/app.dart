import 'package:flutter/material.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/core/theme/app_theme.dart';

class ZoeApp extends StatelessWidget {
  const ZoeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zoe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}