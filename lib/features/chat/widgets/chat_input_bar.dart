import 'package:flutter/material.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Text field (pill) · mic (later version) · send.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool enabled;
  final bool busy;
  final int maxLength;
  final VoidCallback onSend;
  final VoidCallback onMic;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.enabled,
    required this.busy,
    required this.maxLength,
    required this.onSend,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HomeColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: maxLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              cursorColor: HomeColors.lavender,
              style: ChatText.input,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: ChatText.inputHint,
                counterText: '',
                filled: true,
                fillColor: ChatColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
                disabledBorder: border,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _RoundButton(
            tooltip: 'Voice (coming soon)',
            fill: HomeColors.coralLight,
            onTap: enabled ? onMic : null,
            child: const Icon(Icons.mic_none_rounded, color: HomeColors.coral, size: 28),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = enabled && !busy && value.text.trim().isNotEmpty;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: canSend ? 1 : 0.45,
                child: _RoundButton(
                  tooltip: 'Send',
                  gradient: ChatColors.userBubble,
                  onTap: canSend ? onSend : null,
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 26),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String tooltip;
  final Color? fill;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Widget child;

  const _RoundButton({
    required this.tooltip,
    required this.child,
    this.fill,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: fill, gradient: gradient, borderRadius: radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: radius, onTap: onTap, child: Center(child: child)),
        ),
      ),
    );
  }
}