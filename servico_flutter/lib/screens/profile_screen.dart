// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.authService,
    required this.apiService,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _saving = false;
  bool _changingPass = false;
  bool _showCurPass = false;
  bool _showNewPass = false;
  String? _profileError;
  String? _passError;
  String? _profileSuccess;
  String? _passSuccess;

  @override
  void initState() {
    super.initState();
    final user = widget.authService.currentUser!;
    _nameCtrl.text  = user.username;
    _emailCtrl.text = user.email;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _curPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _profileError = null; _profileSuccess = null; });
    try {
      await widget.authService.updateProfile(_nameCtrl.text.trim(), _emailCtrl.text.trim());
      if (mounted) setState(() => _profileSuccess = 'Perfil atualizado com sucesso!');
    } catch (e) {
      if (mounted) setState(() => _profileError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confPassCtrl.text) {
      setState(() => _passError = 'As senhas não coincidem.');
      return;
    }
    if (_newPassCtrl.text.length < 8) {
      setState(() => _passError = 'A nova senha deve ter pelo menos 8 caracteres.');
      return;
    }
    setState(() { _changingPass = true; _passError = null; _passSuccess = null; });
    try {
      await widget.authService.changePassword(_curPassCtrl.text, _newPassCtrl.text);
      if (mounted) {
        setState(() {
          _passSuccess = 'Senha alterada com sucesso!';
          _curPassCtrl.clear();
          _newPassCtrl.clear();
          _confPassCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _passError = e.toString());
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Excluir conta',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: const Text(
          'Tem certeza que deseja excluir sua conta? Esta ação é irreversível.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.authService.deleteAccount();
      widget.onLogout();
    } catch (e) {
      if (mounted) setState(() => _profileError = e.toString());
    }
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
          onPressed: () => context.pop(),
        ),
        title: const Text('Meu Perfil',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Informações Pessoais'),
                const SizedBox(height: 12),
                _field('Nome', _nameCtrl),
                const SizedBox(height: 12),
                _field('E-mail', _emailCtrl, keyboardType: TextInputType.emailAddress),
                if (_profileError != null) ...[
                  const SizedBox(height: 8),
                  _errorText(_profileError!),
                ],
                if (_profileSuccess != null) ...[
                  const SizedBox(height: 8),
                  _successText(_profileSuccess!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 32),
                Divider(color: AppTheme.divider),
                const SizedBox(height: 24),

                _sectionTitle('Alterar Senha'),
                const SizedBox(height: 12),
                _passField('Senha Atual', _curPassCtrl, _showCurPass,
                    () => setState(() => _showCurPass = !_showCurPass)),
                const SizedBox(height: 12),
                _passField('Nova Senha', _newPassCtrl, _showNewPass,
                    () => setState(() => _showNewPass = !_showNewPass)),
                const SizedBox(height: 12),
                _passField('Confirmar Nova Senha', _confPassCtrl, _showNewPass, null),
                if (_passError != null) ...[
                  const SizedBox(height: 8),
                  _errorText(_passError!),
                ],
                if (_passSuccess != null) ...[
                  const SizedBox(height: 8),
                  _successText(_passSuccess!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _changingPass ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgCard,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _changingPass
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 40),
                Divider(color: AppTheme.divider),
                const SizedBox(height: 20),

                _sectionTitle('Zona de Perigo', color: Colors.redAccent),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent),
                    label: const Text('Excluir minha conta',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {Color? color}) => Text(
        text,
        style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: _inputDecoration(label),
      );

  Widget _passField(String label, TextEditingController ctrl, bool visible,
      VoidCallback? onToggle) =>
      TextField(
        controller: ctrl,
        obscureText: !visible,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: _inputDecoration(label).copyWith(
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
                      size: 18, color: AppTheme.iconColor),
                  onPressed: onToggle,
                )
              : null,
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.bgCard,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _errorText(String msg) => Text(msg,
      style: const TextStyle(color: Colors.redAccent, fontSize: 12));

  Widget _successText(String msg) => Text(msg,
      style: const TextStyle(color: Colors.greenAccent, fontSize: 12));
}
