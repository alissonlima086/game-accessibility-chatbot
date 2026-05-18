// lib/widgets/top_bar.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool sidebarOpen;
  final bool showSidebarToggle;
  final AuthUser user;
  final VoidCallback onToggleSidebar;
  final VoidCallback onNewChat;
  final VoidCallback onLogout;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenAdminPanel;

  const TopBar({
    super.key,
    required this.title,
    required this.sidebarOpen,
    required this.showSidebarToggle,
    required this.user,
    required this.onToggleSidebar,
    required this.onNewChat,
    required this.onLogout,
    this.onOpenDrawer,
    this.onOpenAdminPanel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showSidebarToggle)
              IconButton(
                icon: Icon(
                  sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                  color: AppTheme.iconColor,
                  size: 20,
                ),
                onPressed: onToggleSidebar,
              )
            else
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppTheme.iconColor, size: 20),
                onPressed: onOpenDrawer,
              ),

            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppTheme.iconColor, size: 20),
              onPressed: onNewChat,
              tooltip: 'Nova conversa',
            ),
            _UserAvatar(
              user: user,
              onLogout: onLogout,
              onOpenAdminPanel: onOpenAdminPanel,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onLogout;
  final VoidCallback? onOpenAdminPanel;

  const _UserAvatar({
    required this.user,
    required this.onLogout,
    this.onOpenAdminPanel,
  });

  bool get _isAdmin => user.role == 'ADMIN';

  void _showMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final items = <PopupMenuEntry<String>>[
      // Header
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.username,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGlow,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accentDim),
                    ),
                    child: const Text(
                      'Admin',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Divider(height: 1, color: AppTheme.divider),
            ),
          ],
        ),
      ),

      // Painel admin (só para admins)
      if (_isAdmin)
        PopupMenuItem<String>(
          value: 'admin',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 15, color: AppTheme.accent),
              SizedBox(width: 10),
              Text(
                'Painel de Administrador',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),

      if (_isAdmin)
        PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: AppTheme.divider),
        ),

      PopupMenuItem<String>(
        value: 'logout',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, size: 15, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Sair', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ),
      ),
    ];

    final result = await showMenu<String>(
      context: context,
      position: position,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.divider),
      ),
      items: items,
    );

    if (result == 'logout') onLogout();
    if (result == 'admin' && onOpenAdminPanel != null) onOpenAdminPanel!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _isAdmin ? AppTheme.accentGlow : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isAdmin ? AppTheme.accentDim : AppTheme.divider,
          ),
        ),
        child: Center(
          child: Text(
            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
            style: TextStyle(
              color: _isAdmin ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
