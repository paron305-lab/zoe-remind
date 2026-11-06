import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Zoe-style snackbar: floating, rounded, mint (coral for errors), 2 seconds.
/// Same look as the Tasks screen.
class ZoeSnack {
  ZoeSnack._();

  static const _duration = Duration(seconds: 2);
  static Timer? _timer;

  static void show(
    BuildContext context,
    String text, {
    SnackBarAction? action,
    bool error = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    _timer?.cancel();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: error ? HomeColors.coral : HomeColors.mint,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
          duration: _duration,
          action: action,
        ),
      );

    _timer = Timer(_duration, messenger.hideCurrentSnackBar);
  }
}