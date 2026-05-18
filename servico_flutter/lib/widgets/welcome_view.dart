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
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone decorativo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentGlow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentDim),
                ),
                child: const Icon(Icons.radar_rounded,
                    size: 26, color: AppTheme.accent),
              ),
              const SizedBox(height: 20),
              const Text(
                'Como posso ajudar?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              const Text(
                'Faça uma pergunta ou escolha uma sugestão abaixo.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              // Grid de sugestões
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.bgCard : AppTheme.bgInput,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered ? AppTheme.accentDim : AppTheme.divider,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de sugestão — compatibilidade com outros usos
class SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SuggestionChip(
      {super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgInput,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      ),
    );
  }
}
