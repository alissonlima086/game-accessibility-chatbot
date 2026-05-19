// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class Sidebar extends StatelessWidget {
  final List<Conversation> conversations;
  final String? activeId;
  final VoidCallback onNewChat;
  final void Function(Conversation) onSelect;
  final void Function(Conversation) onDelete;

  const Sidebar({
    super.key,
    required this.conversations,
    required this.activeId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: AppTheme.bgSidebar,
        border: Border(right: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGlow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentDim),
                        ),
                        child: const Icon(Icons.hub_rounded,
                            size: 17, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AccessBot',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2)),
                          Text('RAG · Acessibilidade em jogos',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 9.5,
                                  letterSpacing: 0.2)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _NewChatButton(onTap: onNewChat),
                ],
              ),
            ),
          ),

          if (conversations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(children: const [
                Text('HISTÓRICO',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4)),
              ]),
            ),

          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.forum_outlined, size: 28, color: AppTheme.iconColor),
                        SizedBox(height: 10),
                        Text('Nenhuma conversa',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: conversations.length,
                    itemBuilder: (context, i) {
                      final conv = conversations[i];
                      return _ConversationTile(
                        conversation: conv,
                        isActive: conv.id == activeId,
                        onTap: () => onSelect(conv),
                        onDelete: () => onDelete(conv),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewChatButton({required this.onTap});
  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.accentGlow : const Color(0x112DD4BF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? AppTheme.accentDim : const Color(0xFF1A2A28),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, size: 16, color: AppTheme.accent),
              SizedBox(width: 8),
              Text('Nova conversa',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF0E1F1D)
                : _hovered
                    ? const Color(0xFF0C1218)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: widget.isActive
                ? Border.all(color: AppTheme.accentDim, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.isActive
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 12,
                color: widget.isActive ? AppTheme.accent : AppTheme.iconColor,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  style: TextStyle(
                    color: widget.isActive
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hovered || widget.isActive)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 13,
                      color: _hovered ? Colors.redAccent.withOpacity(0.7) : AppTheme.iconColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
