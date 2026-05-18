// lib/models/models.dart

class Source {
  final String url;
  final double score;

  const Source({required this.url, required this.score});

  factory Source.fromJson(Map<String, dynamic> json) => Source(
        url: json['url'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String content;
  final String role;
  final DateTime timestamp;
  final List<Source> sources;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.role,
    required this.timestamp,
    this.sources = const [],
  });

  bool get isUser => role == 'USER';
  bool get isBot  => role == 'BOT';

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {List<Source>? sources}) {
    // Tenta timestamp, fallback para created_at, fallback para now
    DateTime ts;
    try {
      final raw = json['timestamp'] as String? ?? json['created_at'] as String?;
      ts = raw != null && raw.isNotEmpty ? DateTime.parse(raw) : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    return ChatMessage(
      id:             json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      content:        json['content'] as String? ?? '',
      role:           json['role'] as String? ?? 'BOT',
      timestamp:      ts,
      sources:        sources ?? const [],
    );
  }
}

class Conversation {
  final String id;
  final String userId;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? s) {
      if (s == null || s.isEmpty) return DateTime.now();
      try { return DateTime.parse(s); } catch (_) { return DateTime.now(); }
    }

    return Conversation(
      id:        json['id'] as String? ?? '',
      userId:    json['user_id'] as String? ?? '',
      title:     json['title'] as String? ?? 'Sem título',
      status:    json['status'] as String? ?? 'OPEN',
      createdAt: parseDate(json['created_at'] as String?),
      updatedAt: parseDate(json['updated_at'] as String?),
    );
  }
}

class ChatResponse {
  final Conversation conversation;
  final ChatMessage userMessage;
  final ChatMessage botMessage;
  final List<Source> sources;

  const ChatResponse({
    required this.conversation,
    required this.userMessage,
    required this.botMessage,
    required this.sources,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    // sources ficam no nível raiz da resposta
    final sources = (json['sources'] as List<dynamic>? ?? [])
        .map((s) => Source.fromJson(s as Map<String, dynamic>))
        .toList();

    return ChatResponse(
      conversation: Conversation.fromJson(
          json['conversation'] as Map<String, dynamic>),
      userMessage: ChatMessage.fromJson(
          json['user_message'] as Map<String, dynamic>),
      botMessage: ChatMessage.fromJson(
          json['bot_message'] as Map<String, dynamic>,
          sources: sources),
      sources: sources,
    );
  }
}

class AuthUser {
  final String id;
  final String username;
  final String email;
  final String role;
  final String token;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json, String token) =>
      AuthUser(
        id:       json['id'] as String,
        username: json['username'] as String,
        email:    json['email'] as String,
        role:     json['role'] as String,
        token:    token,
      );
}
