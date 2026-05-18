// lib/models/admin_models.dart

// ── Usuários ──────────────────────────────────────────────────────────────────

class AdminUser {
  final String id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'ADMIN';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'USER',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'role': role,
      };
}

// ── Links ─────────────────────────────────────────────────────────────────────

class CrawlerLink {
  final String url;
  final String status;
  final int depth;
  final String domain;
  final String createdAt;
  final String updatedAt;
  final String errorMessage;

  const CrawlerLink({
    required this.url,
    required this.status,
    required this.depth,
    required this.domain,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage = '',
  });

  factory CrawlerLink.fromJson(Map<String, dynamic> json) => CrawlerLink(
        url: json['url'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        depth: (json['depth'] as num?)?.toInt() ?? 0,
        domain: json['domain'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
        errorMessage: json['error_message'] as String? ?? '',
      );
}

class LinksPage {
  final List<CrawlerLink> links;
  final int total;

  const LinksPage({required this.links, required this.total});

  factory LinksPage.fromJson(Map<String, dynamic> json) {
    final list = (json['links'] as List<dynamic>? ?? [])
        .map((e) => CrawlerLink.fromJson(e as Map<String, dynamic>))
        .toList();
    return LinksPage(links: list, total: (json['total'] as num?)?.toInt() ?? 0);
  }
}

// ── Status do crawler ─────────────────────────────────────────────────────────

class LinksStatus {
  final int total;
  final int pending;
  final int success;
  final int error;
  final int blocked;

  const LinksStatus({
    required this.total,
    required this.pending,
    required this.success,
    required this.error,
    required this.blocked,
  });

  factory LinksStatus.fromJson(Map<String, dynamic> json) => LinksStatus(
        total: (json['total'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
        success: (json['success'] as num?)?.toInt() ?? 0,
        error: (json['error'] as num?)?.toInt() ?? 0,
        blocked: (json['blocked'] as num?)?.toInt() ?? 0,
      );
}
