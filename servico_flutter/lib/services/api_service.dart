// lib/services/api_service.dart
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('Sessão expirada. Faça login novamente.', statusCode: 401);
}

class ApiService {
  final String baseUrl;
  String? _token;

  ApiService({required this.baseUrl});

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;
  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _handleResponse(http.Response res) async {
    dev.log('HTTP ${res.statusCode} ${res.request?.url}', name: 'API');
    if (res.statusCode == 401) throw const UnauthorizedException();
    if (res.body.isEmpty) return null;
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final err = (body is Map ? body['error'] : null) as String? ?? 'Erro desconhecido';
    throw ApiException(err, statusCode: res.statusCode);
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthUser> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res) as Map<String, dynamic>;
    final tok = data['token'] as String;
    setToken(tok);
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>, tok);
  }

  Future<AuthUser> register(String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'role': 'USER',
      }),
    );
    await _handleResponse(res);
    return login(email, password);
  }

  // ── Profile (Fix #3) ──────────────────────────────────────────────────────

  Future<AuthUser> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/profile'),
      headers: _headers,
    );
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return AuthUser.fromJson(data, _token!);
  }

  Future<AuthUser> updateProfile(String username, String email) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/profile'),
      headers: _headers,
      body: jsonEncode({'username': username, 'email': email}),
    );
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return AuthUser.fromJson(data, _token!);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/v1/profile/password'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    await _handleResponse(res);
  }

  Future<void> deleteAccount() async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/profile'),
      headers: _headers,
    );
    await _handleResponse(res);
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations(String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/users/$userId/conversations?limit=50'),
      headers: _headers,
    );
    final data = await _handleResponse(res);
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/conversations/$conversationId/messages?limit=100'),
      headers: _headers,
    );
    final data = await _handleResponse(res);
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> deleteConversation(String conversationId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/conversations/$conversationId'),
      headers: _headers,
    );
    await _handleResponse(res);
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<ChatResponse> startChat(String userId, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/chat'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'content': content}),
    );
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return ChatResponse.fromJson(data);
  }

  Future<ChatResponse> sendMessage(String conversationId, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/chat/$conversationId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    final data = await _handleResponse(res) as Map<String, dynamic>;
    return ChatResponse.fromJson(data);
  }
}
