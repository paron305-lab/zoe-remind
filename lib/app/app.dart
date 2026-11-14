import 'package:flutter/material.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/core/theme/app_theme.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';

class ZoeApp extends StatefulWidget {
  const ZoeApp({super.key});

  @override
  State<ZoeApp> createState() => _ZoeAppState();
}

class _ZoeAppState extends State<ZoeApp> {
  @override
  void initState() {
    super.initState();
    ZoeTheme.dark.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ZoeTheme.dark.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Dark mode ON/OFF → i-rebuild ang lahat ng screen (kasama ang mga
  /// nakatagong tab sa likod) para mabasa ulit ang bagong kulay.
  /// Hindi nawawala ang state (naka-type, scroll position, bukas na tab).
  void _onThemeChanged() {
    setState(() {});
    void markAll(Element el) {
      el.markNeedsBuild();
      el.visitChildren(markAll);
    }

    (context as Element).visitChildren(markAll);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zoe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ZoeTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      // Walang animation ng kulay para sabay-sabay lumipat ang lahat.
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
    );
  }
}