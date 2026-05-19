// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return _UserBubble(message: message);
    return _BotBubble(message: message);
  }
}

// ── Usuário ───────────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgUserBubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: const Color(0xFF1A3830)),
          ),
          child: SelectableText(
            message.content,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14, height: 1.6),
          ),
        ),
      ),
    );
  }
}

// ── Bot ───────────────────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  final ChatMessage message;
  const _BotBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar bot
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 12, top: 1),
            decoration: BoxDecoration(
              color: AppTheme.accentGlow,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppTheme.accentDim),
            ),
            child: const Icon(Icons.hub_rounded, size: 15, color: AppTheme.accent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectionArea(
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                  child: MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14, height: 1.72),
                      code: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          backgroundColor: AppTheme.codeBg,
                          color: AppTheme.codeText),
                      codeblockDecoration: BoxDecoration(
                        color: AppTheme.codeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      codeblockPadding: const EdgeInsets.all(14),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(
                            left: BorderSide(color: AppTheme.accent, width: 3)),
                      ),
                      blockquotePadding: const EdgeInsets.only(left: 12),
                      h1: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18, fontWeight: FontWeight.w700),
                      h2: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15, fontWeight: FontWeight.w600),
                      h3: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w600),
                      listBullet: const TextStyle(color: AppTheme.accent),
                      strong: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      em: const TextStyle(
                          color: AppTheme.textPrimary, fontStyle: FontStyle.italic),
                      a: const TextStyle(
                          color: AppTheme.accent,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.accentDim),
                      horizontalRuleDecoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.divider))),
                    ),
                    onTapLink: (_, href, __) async {
                      if (href != null) await launchUrl(Uri.parse(href));
                    },
                  ),
                ),
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SourceList(sources: message.sources),
                ],
                const SizedBox(height: 8),
                _CopyButton(content: message.content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fontes ────────────────────────────────────────────────────────────────────

class _SourceList extends StatelessWidget {
  final List<Source> sources;
  const _SourceList({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link_rounded, size: 11, color: AppTheme.textSecondary),
            SizedBox(width: 4),
            Text('FONTES',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sources.map((s) => _SourceChip(source: s)).toList()),
      ],
    );
  }
}

class _SourceChip extends StatefulWidget {
  final Source source;
  const _SourceChip({required this.source});
  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip> {
  bool _hovered = false;

  String get _domain {
    try {
      return Uri.parse(widget.source.url).host.replaceFirst('www.', '');
    } catch (_) {
      return widget.source.url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.source.url)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF0E1F1D) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: _hovered ? AppTheme.accentDim : AppTheme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 10,
                  color: _hovered ? AppTheme.accent : AppTheme.iconColor),
              const SizedBox(width: 5),
              Text(_domain,
                  style: TextStyle(
                      color: _hovered
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 11)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.accentGlow,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${(widget.source.score * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Copiar ────────────────────────────────────────────────────────────────────

class _CopyButton extends StatefulWidget {
  final String content;
  const _CopyButton({required this.content});
  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Row(
          key: ValueKey(_copied),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_circle_outline_rounded : Icons.copy_all_rounded,
              size: 13,
              color: _copied ? AppTheme.accent : AppTheme.iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              _copied ? 'Copiado!' : 'Copiar',
              style: TextStyle(
                  color: _copied ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 12, top: 1),
            decoration: BoxDecoration(
              color: AppTheme.accentGlow,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppTheme.accentDim),
            ),
            child: const Icon(Icons.hub_rounded, size: 15, color: AppTheme.accent),
          ),
          SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final t = (_ctrl.value - delay).clamp(0.0, 1.0);
                    final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.15, 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
