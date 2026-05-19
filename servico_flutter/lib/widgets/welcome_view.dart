// lib/widgets/welcome_view.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class WelcomeView extends StatelessWidget {
  final void Function(String) onPrompt;
  final List<String> suggestions;

  const WelcomeView({
    super.key,
    required this.onPrompt,
    this.suggestions = const [
      'Como tornar meu jogo acessível para pessoas com deficiência visual?',
      'Quais são as boas práticas de legendas e closed captions em jogos?',
      'Como implementar remapeamento de controles para acessibilidade motora?',
      'O que são modos daltônico e como aplicá-los em jogos?',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentGlow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentDim),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_rounded, size: 12, color: AppTheme.accent),
                    SizedBox(width: 6),
                    Text('RAG · Acessibilidade em jogos',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Como posso ajudar?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.2),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pergunte sobre acessibilidade em jogos ou escolha uma sugestão.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Grid 2x2
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3.2,
                children: suggestions
                    .map((s) => _SuggestionCard(label: s, onTap: () => onPrompt(s)))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionCard({required this.label, required this.onTap});
  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF0E1F1D) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered ? AppTheme.accentDim : AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: _hovered ? AppTheme.accent : AppTheme.iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                      color: _hovered
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
