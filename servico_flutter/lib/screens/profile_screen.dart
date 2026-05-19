// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router.dart';
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
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _curPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _saving      = false;
  bool _changingPass = false;
  bool _showCurPass  = false;
  bool _showNewPass  = false;
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

  // Fix #2: volta ao chat via go_router
  void _back() => context.go(AppRoutes.chat);

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _profileError = null; _profileSuccess = null; });
    try {
      await widget.authService.updateProfile(
          _nameCtrl.text.trim(), _emailCtrl.text.trim());
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
      await widget.authService.changePassword(
          _curPassCtrl.text, _newPassCtrl.text);
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

  // Fix #3: confirmação com senha antes de deletar conta
  Future<void> _deleteAccount() async {
    final passCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.divider),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Excluir conta',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta ação é permanente e não pode ser desfeita.\nConfirme sua senha para continuar.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                autofocus: true,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  labelStyle:
                      const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.bgInput,
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
                    borderSide:
                        const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        size: 17,
                        color: AppTheme.iconColor),
                    onPressed: () => setDlg(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir conta',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Valida senha localmente antes de chamar API
    final user = widget.authService.currentUser!;
    if (passCtrl.text.isEmpty) {
      setState(() => _profileError = 'Informe sua senha para excluir a conta.');
      return;
    }

    // Usa changePassword apenas para validar — se falhar a senha está errada
    try {
      await widget.authService.changePassword(passCtrl.text, passCtrl.text);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.message.contains('incorreta')) {
        setState(() => _profileError = 'Senha incorreta. Conta não excluída.');
        return;
      }
    }

    try {
      await widget.authService.deleteAccount();
      widget.onLogout();
    } catch (e) {
      if (mounted) setState(() => _profileError = e.toString());
    }
    passCtrl.dispose();
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
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.iconColor, size: 20),
          // Fix #2: vai para /chat, não só pop
          onPressed: _back,
        ),
        title: const Text('Meu Perfil',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar header
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGlow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentDim),
                        ),
                        child: Center(
                          child: Text(
                            widget.authService.currentUser!.username
                                    .isNotEmpty
                                ? widget.authService.currentUser!.username[0]
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.authService.currentUser!.username,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.authService.currentUser!.email,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGlow,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.accentDim),
                        ),
                        child: Text(
                          widget.authService.currentUser!.role,
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),

                _sectionTitle('Informações Pessoais'),
                const SizedBox(height: 12),
                _field('Nome', _nameCtrl),
                const SizedBox(height: 12),
                _field('E-mail', _emailCtrl,
                    keyboardType: TextInputType.emailAddress),
                if (_profileError != null) ...[
                  const SizedBox(height: 8),
                  _feedbackRow(_profileError!, isError: true),
                ],
                if (_profileSuccess != null) ...[
                  const SizedBox(height: 8),
                  _feedbackRow(_profileSuccess!, isError: false),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Salvar Alterações',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(color: AppTheme.divider),
                const SizedBox(height: 24),

                _sectionTitle('Alterar Senha'),
                const SizedBox(height: 12),
                _passField('Senha Atual', _curPassCtrl, _showCurPass,
                    () => setState(() => _showCurPass = !_showCurPass)),
                const SizedBox(height: 12),
                _passField('Nova Senha', _newPassCtrl, _showNewPass,
                    () => setState(() => _showNewPass = !_showNewPass)),
                const SizedBox(height: 12),
                _passField('Confirmar Nova Senha', _confPassCtrl,
                    _showNewPass, null),
                if (_passError != null) ...[
                  const SizedBox(height: 8),
                  _feedbackRow(_passError!, isError: true),
                ],
                if (_passSuccess != null) ...[
                  const SizedBox(height: 8),
                  _feedbackRow(_passSuccess!, isError: false),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _changingPass ? null : _changePassword,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _changingPass
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Alterar Senha',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 40),
                const Divider(color: AppTheme.divider),
                const SizedBox(height: 20),

                _sectionTitle('Zona de Perigo', color: Colors.redAccent),
                const SizedBox(height: 6),
                Text(
                  'A exclusão da conta é permanente e remove todos os seus dados.',
                  style: TextStyle(
                      color: Colors.redAccent.withOpacity(0.7), fontSize: 12),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded,
                        size: 17, color: Colors.redAccent),
                    label: const Text('Excluir minha conta',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                          color: Colors.redAccent, width: 0.8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
            fontSize: 13,
            fontWeight: FontWeight.w600),
      );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: _inputDeco(label),
      );

  Widget _passField(String label, TextEditingController ctrl, bool visible,
      VoidCallback? onToggle) =>
      TextField(
        controller: ctrl,
        obscureText: !visible,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: _inputDeco(label).copyWith(
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
                      size: 17, color: AppTheme.iconColor),
                  onPressed: onToggle,
                )
              : null,
        ),
      );

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.bgInput,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppTheme.accent, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _feedbackRow(String msg, {required bool isError}) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isError
              ? Colors.redAccent.withOpacity(0.08)
              : AppTheme.accentGlow,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: isError
                  ? Colors.redAccent.withOpacity(0.3)
                  : AppTheme.accentDim),
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 14,
              color: isError ? Colors.redAccent : AppTheme.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      color: isError ? Colors.redAccent : AppTheme.accent,
                      fontSize: 12)),
            ),
          ],
        ),
      );
}
