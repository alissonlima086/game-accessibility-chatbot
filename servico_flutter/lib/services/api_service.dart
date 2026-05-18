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

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    dev.log('HTTP ${res.statusCode} ${res.request?.url}', name: 'API');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(
      body['error'] as String? ?? 'Erro desconhecido',
      statusCode: res.statusCode,
    );
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthUser> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(res);
    final token = data['token'] as String;
    setToken(token);
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>, token);
  }

  Future<AuthUser> register(
      String username, String email, String password) async {
    // O backend retorna apenas UserResponse no /register (sem token).
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
    await _handleResponse(res); // lança ApiException em erro (ex: 409)

    // Cadastro OK — faz login para obter token
    return login(email, password);
  }

  // ── Conversations ────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations(String userId) async {
    final res = await http.get(
      Uri.parse(
          '$baseUrl/api/v1/users/$userId/conversations?limit=50'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw ApiException('Falha ao carregar conversas',
          statusCode: res.statusCode);
    }
    final data = jsonDecode(res.body);
    // Backend pode retornar null quando não há conversas
    if (data == null) return [];
    final list = data as List<dynamic>;
    return list
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final res = await http.get(
      Uri.parse(
          '$baseUrl/api/v1/conversations/$conversationId/messages?limit=100'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw ApiException('Falha ao carregar mensagens',
          statusCode: res.statusCode);
    }
    final data = jsonDecode(res.body);
    if (data == null) return [];
    final list = data as List<dynamic>;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> deleteConversation(String conversationId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/conversations/$conversationId'),
      headers: _headers,
    );
    if (res.statusCode != 204) {
      throw ApiException('Falha ao deletar conversa',
          statusCode: res.statusCode);
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────

  Future<ChatResponse> startChat(String userId, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/chat'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'content': content}),
    );
    final data = await _handleResponse(res);
    try {
      return ChatResponse.fromJson(data);
    } catch (e, st) {
      dev.log('ChatResponse.fromJson error: $e\nBody: $data',
          name: 'API', stackTrace: st);
      rethrow;
    }
  }

  Future<ChatResponse> sendMessage(
      String conversationId, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/chat/$conversationId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    final data = await _handleResponse(res);
    try {
      return ChatResponse.fromJson(data);
    } catch (e, st) {
      dev.log('ChatResponse.fromJson error: $e\nBody: $data',
          name: 'API', stackTrace: st);
      rethrow;
    }
  }
}
