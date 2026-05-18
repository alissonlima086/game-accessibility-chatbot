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
      width: 260,
      color: AppTheme.bgSidebar,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGlow,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.radar_rounded,
                            size: 16, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 10),
                      const Text('Crawler Chat',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2)),
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
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: const [
                  Text('CONVERSAS',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2)),
                ],
              ),
            ),

          // ── Lista ────────────────────────────────────────────────────
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.chat_bubble_outline,
                            size: 28, color: AppTheme.iconColor),
                        SizedBox(height: 10),
                        Text('Nenhuma conversa',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
          // Sem footer de usuário — ele ficou na TopBar
        ],
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accentGlow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: AppTheme.accent),
              SizedBox(width: 8),
              Text('Nova conversa',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
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
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.bgCard
                : _hovered
                    ? const Color(0xFF111520)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: widget.isActive
                ? Border.all(color: AppTheme.accentDim, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 13,
                color: widget.isActive
                    ? AppTheme.accent
                    : AppTheme.iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  style: TextStyle(
                    color: widget.isActive
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w500
                        : FontWeight.normal,
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
                      Icons.close_rounded,
                      size: 14,
                      color: _hovered
                          ? Colors.redAccent.withOpacity(0.8)
                          : AppTheme.iconColor,
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
