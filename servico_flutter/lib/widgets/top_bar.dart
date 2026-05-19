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
  final VoidCallback? onOpenProfile;

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
    this.onOpenProfile,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showSidebarToggle)
              _BarIcon(
                icon: sidebarOpen
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                onTap: onToggleSidebar,
              )
            else
              _BarIcon(icon: Icons.menu_rounded, onTap: onOpenDrawer ?? () {}),

            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1),
              ),
            ),

            _BarIcon(
              icon: Icons.edit_square,
              onTap: onNewChat,
              tooltip: 'Nova conversa',
            ),

            const SizedBox(width: 2),
            _UserAvatar(
              user: user,
              onLogout: onLogout,
              onOpenAdminPanel: onOpenAdminPanel,
              onOpenProfile: onOpenProfile,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _BarIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _BarIcon({required this.icon, required this.onTap, this.tooltip});
  @override
  State<_BarIcon> createState() => _BarIconState();
}

class _BarIconState extends State<_BarIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.bgCard : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(widget.icon, size: 18,
                color: _hovered ? AppTheme.textPrimary : AppTheme.iconColor),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatefulWidget {
  final AuthUser user;
  final VoidCallback onLogout;
  final VoidCallback? onOpenAdminPanel;
  final VoidCallback? onOpenProfile;

  const _UserAvatar({
    required this.user,
    required this.onLogout,
    this.onOpenAdminPanel,
    this.onOpenProfile,
  });

  bool get _isAdmin => user.role == 'ADMIN';

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  bool _hovered = false;
  bool get _isAdmin => widget.user.role == 'ADMIN';

  void _showMenu(BuildContext context) async {
    final RenderBox button  = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      color: AppTheme.bgCard,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.divider),
      ),
      items: [
        // Header
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.user.username,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (_isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGlow,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.accentDim),
                      ),
                      child: const Text('Admin',
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(widget.user.email,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.divider),
            ],
          ),
        ),

        // Meu Perfil
        _menuItem('profile', Icons.person_outline_rounded, 'Meu Perfil'),

        if (_isAdmin) ...[
          PopupMenuItem<String>(
            enabled: false, height: 1,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Divider(height: 1, color: AppTheme.divider),
          ),
          _menuItem('admin', Icons.shield_outlined, 'Painel Admin',
              color: AppTheme.accent),
        ],

        PopupMenuItem<String>(
          enabled: false, height: 1,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: const Divider(height: 1, color: AppTheme.divider),
        ),
        _menuItem('logout', Icons.logout_rounded, 'Sair',
            color: Colors.redAccent),
      ],
    );

    if (result == 'logout') widget.onLogout();
    if (result == 'admin' && widget.onOpenAdminPanel != null) widget.onOpenAdminPanel!();
    if (result == 'profile' && widget.onOpenProfile != null) widget.onOpenProfile!();
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) =>
      PopupMenuItem<String>(
        value: value,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color ?? AppTheme.textPrimary),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: color ?? AppTheme.textPrimary, fontSize: 13)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showMenu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? (_isAdmin ? AppTheme.accentGlow : AppTheme.bgCard)
                : (_isAdmin ? const Color(0x162DD4BF) : const Color(0x18FFFFFF)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isAdmin ? AppTheme.accentDim : AppTheme.divider,
            ),
          ),
          child: Center(
            child: Text(
              widget.user.username.isNotEmpty
                  ? widget.user.username[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: _isAdmin ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
