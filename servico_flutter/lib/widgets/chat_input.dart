// lib/widgets/chat_input.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

class ChatInput extends StatefulWidget {
  final bool enabled;
  final void Function(String) onSend;
  const ChatInput({super.key, required this.enabled, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl      = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _ctrl.clear();
    widget.onSend(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bgDark,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: AppTheme.bgInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focused ? AppTheme.accentDim : AppTheme.divider,
                  width: _focused ? 1.5 : 1,
                ),
                boxShadow: _focused
                    ? [BoxShadow(
                        color: AppTheme.accent.withOpacity(0.06),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )]
                    : [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _RawInput(
                      ctrl: _ctrl,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      onSend: _send,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: GestureDetector(
                      onTap: _hasText && widget.enabled ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: _hasText && widget.enabled
                              ? AppTheme.accent
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: _hasText && widget.enabled
                                ? AppTheme.accentDim
                                : AppTheme.divider,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 17,
                          color: _hasText && widget.enabled
                              ? Colors.black
                              : AppTheme.iconColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RawInput extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _RawInput({
    required this.ctrl,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!HardwareKeyboard.instance.isShiftPressed) onSend();
        },
      },
      child: TextField(
        controller: ctrl,
        focusNode: focusNode,
        enabled: enabled,
        maxLines: 6,
        minLines: 1,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          hintText: 'Pergunte sobre acessibilidade em jogos...',
          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          counterText: '',
        ),
      ),
    );
  }
}
