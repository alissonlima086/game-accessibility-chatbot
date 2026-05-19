// lib/screens/user_management_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../utils/theme.dart';
import '../router.dart';

class UserManagementScreen extends StatefulWidget {
  final AdminService adminService;
  const UserManagementScreen({super.key, required this.adminService});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const int _pageSize = 15;
  int _currentPage = 0;
  List<AdminUser> _users = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applySearch(_searchCtrl.text);
    });
  }

  void _applySearch(String value) {
    _debounce?.cancel();
    setState(() => _searchQuery = value);
    _loadUsers(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _hasMore = true;
      _users = [];
    }
    if (!_hasMore || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final list = await widget.adminService.listUsers(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      setState(() {
        if (reset) _users = list;
        else _users = [..._users, ...list];
        _hasMore = list.length == _pageSize;
        if (list.isNotEmpty) _currentPage++;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openEditDialog(AdminUser user) {
    final usernameCtrl = TextEditingController(text: user.username);
    final emailCtrl = TextEditingController(text: user.email);
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.divider),
          ),
          title: const Text('Editar Usuário',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Nome de usuário', usernameCtrl),
              const SizedBox(height: 12),
              _buildField('Email', emailCtrl, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    dropdownColor: AppTheme.bgCard,
                    isExpanded: true,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('Usuário')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.adminService.updateUser(
                    user.id, usernameCtrl.text, emailCtrl.text, selectedRole);
                  _loadUsers(reset: true);
                  if (mounted) _showSnack('Usuário atualizado');
                } catch (e) {
                  if (mounted) _showSnack('Erro: $e', error: true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AdminUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.divider),
        ),
        title: const Text('Remover Usuário',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text(
          'Tem certeza que deseja remover "${user.username}"?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.adminService.deleteUser(user.id);
                _loadUsers(reset: true);
                if (mounted) _showSnack('Usuário removido');
              } catch (e) {
                if (mounted) _showSnack('Erro: $e', error: true);
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : AppTheme.accent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildField(String label, TextEditingController ctrl,
    {TextInputType keyboard = TextInputType.text}) {
  return TextField(
    controller: ctrl,
    keyboardType: keyboard,
    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      filled: true,
      fillColor: AppTheme.bgInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.iconColor, size: 20),
          onPressed: () => context.go(AppRoutes.admin),
        ),
        title: const Text('Usuários',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.iconColor, size: 20),
            onPressed: () => _loadUsers(reset: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Column(
            children: [
              Container(height: 1, color: AppTheme.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => _applySearch(v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou email...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.iconColor, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.iconColor),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                              _loadUsers(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SelectionArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: () => _loadUsers(reset: true), child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) _loadUsers();
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length + (_loading ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == _users.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                          ),
                        );
                      }
                      final user = _users[i];
                      return _UserTile(
                        user: user,
                        onEdit: () => _openEditDialog(user),
                        onDelete: () => _confirmDelete(user),
                      );
                    },
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserTile({required this.user, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: user.isAdmin ? AppTheme.accentGlow : const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: TextStyle(
                  color: user.isAdmin ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (user.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGlow,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.accentDim),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    if (!user.isActive)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('inativo',
                            style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(user.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.iconColor),
            onPressed: onEdit,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.redAccent),
            onPressed: onDelete,
            tooltip: 'Remover',
          ),
        ],
      ),
    );
  }
}
