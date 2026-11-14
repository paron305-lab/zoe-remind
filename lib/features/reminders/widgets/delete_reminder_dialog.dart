import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Delete always asks first (risk tier: DELETE ONE). Returns true only on "Delete".
/// For repeating reminders, says that every repeat goes too.
Future<bool> confirmDeleteReminder(
  BuildContext context,
  String title, {
  bool repeats = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        'Delete this reminder?',
        style: TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: HomeColors.ink),
      ),
      content: Text(
        repeats
            ? '"$title" and all its repeats will be removed. Hindi na ito maibabalik.'
            : '"$title" will be removed. Hindi na ito maibabalik.',
        style: TextStyle(
            fontFamily: 'Poppins', fontSize: 15, color: HomeColors.inkSoft, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: HomeColors.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: HomeColors.coral)),
        ),
      ],
    ),
  );
  return ok ?? false;
}