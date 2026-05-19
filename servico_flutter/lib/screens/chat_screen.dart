// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../utils/theme.dart';
import '../widgets/chat_input.dart';
import '../widgets/delete_conversation_dialog.dart';
import '../widgets/error_banner.dart';
import '../widgets/message_list.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../widgets/welcome_view.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const ChatScreen({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Conversation> _conversations = [];
  String? _activeConversationId;
  List<ChatMessage> _messages = [];
  bool _sending = false;
  bool _loadingMessages = false;
  bool _sidebarOpen = true;
  String? _error;

  final _scrollCtrl = ScrollController();
  late AdminService _adminService;

  ApiService get _api => widget.apiService;
  AuthUser get _user => widget.authService.currentUser!;
  bool get _isAdmin => _user.role == 'ADMIN';

  String get _activeTitle {
    if (_activeConversationId == null) return 'Nova conversa';
    return _conversations
        .firstWhere(
          (c) => c.id == _activeConversationId,
          orElse: () => _conversations.first,
        )
        .title;
  }

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(_api);
    // Fix #4: registra callback de sessão expirada
    widget.authService.onSessionExpired = _onSessionExpired;
    _loadConversations();
  }

  @override
  void dispose() {
    widget.authService.onSessionExpired = null;
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Fix #4: deslogar automaticamente ao receber 401
  void _onSessionExpired() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          apiService: widget.apiService,
        ),
      ),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sessão expirada. Faça login novamente.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // Wrapper que converte UnauthorizedException em logout automático
  Future<T> _withAuth<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on UnauthorizedException {
      await widget.authService.handleUnauthorized();
      rethrow;
    }
  }

  Future<void> _loadConversations() async {
    try {
      final convs = await _withAuth(() => _api.getConversations(_user.id));
      if (mounted) setState(() => _conversations = convs);
    } on UnauthorizedException {
      // já tratado pelo _withAuth
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _selectConversation(Conversation conv) async {
    setState(() {
      _activeConversationId = conv.id;
      _messages = [];
      _loadingMessages = true;
      _error = null;
    });
    try {
      final msgs = await _withAuth(() => _api.getMessages(conv.id));
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } on UnauthorizedException {
      // já tratado
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingMessages = false;
        });
      }
    }
  }

  void _newChat() => setState(() {
        _activeConversationId = null;
        _messages = [];
        _error = null;
      });

  Future<void> _deleteConversation(Conversation conv) async {
    final confirmed = await showDeleteConversationDialog(context, conv);
    if (!confirmed) return;
    try {
      await _withAuth(() => _api.deleteConversation(conv.id));
      setState(() {
        _conversations.removeWhere((c) => c.id == conv.id);
        if (_activeConversationId == conv.id) {
          _activeConversationId = null;
          _messages = [];
        }
      });
    } on UnauthorizedException {
      // já tratado
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _send(String content) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _messages = [..._messages, _optimisticUserMessage(content)];
    });
    _scrollToBottom();

    try {
      final resp = await _withAuth(() => _activeConversationId == null
          ? _api.startChat(_user.id, content)
          : _api.sendMessage(_activeConversationId!, content));

      setState(() {
        _activeConversationId = resp.conversation.id;
        _conversations = [
          resp.conversation,
          ..._conversations.where((c) => c.id != resp.conversation.id),
        ];
        _messages = [
          ..._messages.where((m) => m.id != _kTempId),
          resp.userMessage,
          resp.botMessage,
        ];
      });
      _scrollToBottom();
    } on UnauthorizedException {
      setState(() => _messages = _messages.where((m) => m.id != _kTempId).toList());
    } catch (e) {
      setState(() {
        _messages = _messages.where((m) => m.id != _kTempId).toList();
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _kTempId = 'temp_user';

  ChatMessage _optimisticUserMessage(String content) => ChatMessage(
        id: _kTempId,
        conversationId: _activeConversationId ?? '',
        content: content,
        role: 'USER',
        timestamp: DateTime.now(),
      );

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            authService: widget.authService,
            apiService: widget.apiService,
          ),
        ),
      );
    }
  }

  void _openAdminPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPanelScreen(adminService: _adminService),
      ),
    );
  }

  // Fix #3: abre tela de perfil
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          authService: widget.authService,
          apiService: widget.apiService,
          onLogout: _logout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      drawer: isWide ? null : _buildDrawer(),
      body: SelectionArea(
        child: Row(
          children: [
            if (isWide && _sidebarOpen) _buildSidebar(),
            Expanded(child: _buildMainArea(isWide)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() => Sidebar(
        conversations: _conversations,
        activeId: _activeConversationId,
        onNewChat: _newChat,
        onSelect: _selectConversation,
        onDelete: _deleteConversation,
      );

  Widget _buildDrawer() => Drawer(
        backgroundColor: AppTheme.bgSidebar,
        child: Sidebar(
          conversations: _conversations,
          activeId: _activeConversationId,
          onNewChat: () { Navigator.pop(context); _newChat(); },
          onSelect: (c) { Navigator.pop(context); _selectConversation(c); },
          onDelete: (c) { Navigator.pop(context); _deleteConversation(c); },
        ),
      );

  Widget _buildMainArea(bool isWide) => Column(
        children: [
          TopBar(
            title: _activeTitle,
            sidebarOpen: _sidebarOpen,
            showSidebarToggle: isWide,
            user: _user,
            onToggleSidebar: () => setState(() => _sidebarOpen = !_sidebarOpen),
            onNewChat: _newChat,
            onLogout: _logout,
            onOpenDrawer: isWide ? null : () => Scaffold.of(context).openDrawer(),
            onOpenAdminPanel: _isAdmin ? _openAdminPanel : null,
            onOpenProfile: _openProfile,
          ),
          if (_error != null)
            ErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
          Expanded(child: _buildContent()),
          ChatInput(enabled: !_sending, onSend: _send),
        ],
      );

  Widget _buildContent() {
    if (_loadingMessages) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_messages.isEmpty) {
      return WelcomeView(onPrompt: _send);
    }
    return MessageList(
      messages: _messages,
      sending: _sending,
      scrollController: _scrollCtrl,
    );
  }
}
