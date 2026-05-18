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

// ── Mensagem do usuário ───────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgUserBubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppTheme.divider),
          ),
          // SelectableText para permitir seleção/cópia
          child: SelectableText(
            message.content,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 14, height: 1.55),
          ),
        ),
      ),
    );
  }
}

// ── Mensagem do bot ───────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  final ChatMessage message;
  const _BotBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone fixo — não sai do lugar durante carregamento
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentGlow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentDim),
            ),
            child: const Icon(Icons.radar_rounded,
                size: 16, color: AppTheme.accent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectionArea(
                  // Ctrl+C funciona, mas sem toolbar visual
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                  child: MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.7),
                      code: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          backgroundColor: Color(0xFF131929),
                          color: Color(0xFFA78BFA)),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF0B0F1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(
                            left: BorderSide(
                                color: AppTheme.accent, width: 3)),
                      ),
                      blockquotePadding:
                          const EdgeInsets.only(left: 12),
                      h1: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700),
                      h2: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      h3: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      listBullet: const TextStyle(
                          color: AppTheme.textSecondary),
                      strong: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600),
                      em: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontStyle: FontStyle.italic),
                      a: const TextStyle(color: AppTheme.accent),
                    ),
                    onTapLink: (_, href, __) async {
                      if (href != null) await launchUrl(Uri.parse(href));
                    },
                  ),
                ),
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SourceList(sources: message.sources),
                ],
                const SizedBox(height: 6),
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
        const Text('Fontes',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                sources.map((s) => _SourceChip(source: s)).toList()),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final Source source;
  const _SourceChip({required this.source});

  String get _domain {
    try {
      return Uri.parse(source.url).host.replaceFirst('www.', '');
    } catch (_) {
      return source.url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async => launchUrl(Uri.parse(source.url)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new_rounded,
                size: 11, color: AppTheme.iconColor),
            const SizedBox(width: 5),
            Text(_domain,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(width: 5),
            Text(
              '${(source.score * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: AppTheme.accent, fontSize: 10),
            ),
          ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _copied ? Icons.check_rounded : Icons.copy_all_rounded,
            size: 13,
            color: AppTheme.iconColor,
          ),
          const SizedBox(width: 4),
          Text(
            _copied ? 'Copiado!' : 'Copiar',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Indicador de digitação — CORRIGIDO: alinhado com as mensagens bot ─────────

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
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mesmo layout Row que _BotBubble — ícone à esquerda + dots à direita
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentGlow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentDim),
            ),
            child: const Icon(Icons.radar_rounded,
                size: 16, color: AppTheme.accent),
          ),
          // Dots alinhados verticalmente com o ícone
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final delay = i / 3;
                      final t = (_ctrl.value - delay).clamp(0.0, 1.0);
                      final opacity =
                          (t < 0.5 ? t * 2 : (1 - t) * 2)
                              .clamp(0.2, 1.0);
                      return Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
