import 'package:flutter/material.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';

/// First open (walang messages): malaking Zoe + greeting.
class ChatWelcome extends StatelessWidget {
  final String name;
  final String greeting;
  final String body;
  const ChatWelcome({super.key, required this.name, required this.greeting, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ChatAvatar(size: 120, asset: 'assets/images/zoe/idle/01_idle (2).png'),
            const SizedBox(height: 18),
            Text(
              name.isEmpty ? '$greeting 👋' : '$greeting, $name! 👋',
              textAlign: TextAlign.center,
              style: ChatText.title,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: ChatText.body),
          ],
        ),
      ),
    );
  }
}

/// No model yet (at naka-off ang UI preview): natutulog si Zoe.
class ChatNoBrain extends StatelessWidget {
  final VoidCallback onGetReady;
  const ChatNoBrain({super.key, required this.onGetReady});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: 0.55,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0xFFB9B4D6), BlendMode.modulate),
                    child: const ChatAvatar(size: 120, asset: 'assets/images/zoe/idle/01_idle (2).png'),
                  ),
                ),
                const Positioned(
                  right: -6,
                  top: -4,
                  child: Text('💤', style: TextStyle(fontSize: 32)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Zoe is still asleep', textAlign: TextAlign.center, style: ChatText.title),
            const SizedBox(height: 8),
            const Text(
              "Kailangan ko muna ng brain ko para makausap mo ako. "
              "One-time download lang, tapos gagana na ako kahit offline. "
              "Pwede mo pa ring gamitin ang Home, Tasks, at Notes.",
              textAlign: TextAlign.center,
              style: ChatText.body,
            ),
            const SizedBox(height: 24),
            GradientButton(label: "Get Zoe's brain ready", onTap: onGetReady),
          ],
        ),
      ),
    );
  }
}

/// Manipis na banner sa taas ng chat (downloading / UI preview).
class ChatBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color fill;
  final bool progress;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ChatBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.fill,
    this.progress = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: fill,
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: ChatText.pill.copyWith(color: HomeColors.ink))),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(actionLabel!, style: ChatText.pill.copyWith(color: color)),
                ),
            ],
          ),
          if (progress) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  color: color,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quick suggestions sa taas ng input (kapag walang laman ang chat).
class SuggestionRow extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;
  const SuggestionRow({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(items[i], style: ChatText.chip),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD9D3F5), width: 1.5),
          shape: const StadiumBorder(),
          onPressed: () => onTap(items[i]),
        ),
      ),
    );
  }
}