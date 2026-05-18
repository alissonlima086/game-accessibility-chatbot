// lib/widgets/delete_conversation_dialog.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';

/// Exibe diálogo de confirmação e retorna [true] se o usuário confirmar.
Future<bool> showDeleteConversationDialog(
  BuildContext context,
  Conversation conversation,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DeleteConversationDialog(conversation: conversation),
  );
  return result == true;
}

class _DeleteConversationDialog extends StatelessWidget {
  final Conversation conversation;
  const _DeleteConversationDialog({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgInput,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Apagar conversa?',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      content: Text(
        '"${conversation.title}"',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Apagar',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
