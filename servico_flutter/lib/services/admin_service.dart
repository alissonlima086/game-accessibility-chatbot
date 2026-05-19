// lib/services/admin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_models.dart';
import 'api_service.dart';

class AdminService {
  final ApiService _api;

  AdminService(this._api);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_api.token != null) 'Authorization': 'Bearer ${_api.token}',
      };

  Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final res = await http.get(Uri.parse('${_api.baseUrl}$path'), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parse(jsonDecode(res.body));
    }
    final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Erro';
    throw ApiException(err.toString(), statusCode: res.statusCode);
  }

  Future<T> _post<T>(String path, Map<String, dynamic> body, T Function(dynamic) parse) async {
    final res = await http.post(
      Uri.parse('${_api.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parse(jsonDecode(res.body));
    }
    final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Erro';
    throw ApiException(err.toString(), statusCode: res.statusCode);
  }

  Future<T> _put<T>(String path, Map<String, dynamic> body, T Function(dynamic) parse) async {
    final res = await http.put(
      Uri.parse('${_api.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parse(jsonDecode(res.body));
    }
    final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Erro';
    throw ApiException(err.toString(), statusCode: res.statusCode);
  }

  Future<void> _delete(String path) async {
    final res = await http.delete(Uri.parse('${_api.baseUrl}$path'), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Erro';
    throw ApiException(err.toString(), statusCode: res.statusCode);
  }

  // ── Usuários ────────────────────────────────────────────────────────────────

  Future<List<AdminUser>> listUsers({int limit = 20, int offset = 0, String? search}) {
    final q = search != null && search.isNotEmpty ? '&search=${Uri.encodeQueryComponent(search)}' : '';
    return _get('/api/v1/admin/users?limit=$limit&offset=$offset$q',
        (d) => (d as List).map((e) => AdminUser.fromJson(e)).toList());
  }

  Future<AdminUser> updateUser(String id, String username, String email, String role) =>
      _put('/api/v1/admin/users/$id', {'username': username, 'email': email, 'role': role},
          (d) => AdminUser.fromJson(d));

  Future<void> deleteUser(String id) => _delete('/api/v1/admin/users/$id');

  // ── Links ───────────────────────────────────────────────────────────────────

  Future<LinksStatus> getLinksStatus() =>
      _get('/api/v1/admin/links/status', (d) => LinksStatus.fromJson(d));

  Future<LinksPage> listLinks({int limit = 20, int skip = 0, String? status, String? urlFilter}) {
    final q = StringBuffer();
    if (status != null && status.isNotEmpty) q.write('&status=$status');
    if (urlFilter != null && urlFilter.isNotEmpty) q.write('&url=${Uri.encodeQueryComponent(urlFilter)}');
    return _get('/api/v1/admin/links?limit=$limit&skip=$skip$q',
        (d) => LinksPage.fromJson(d));
  }

  Future<Map<String, dynamic>> addLinks(List<String> urls) =>
      _post('/api/v1/admin/links', {'urls': urls}, (d) => d as Map<String, dynamic>);

  Future<void> deleteLinkDirect(String url) async {
    final encoded = Uri.encodeComponent(url);
    final res = await http.delete(
      Uri.parse('${_api.baseUrl}/api/v1/admin/links/$encoded'),
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Erro';
      throw ApiException(err.toString(), statusCode: res.statusCode);
    }
  }

  // ── Crawler actions ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> extractLinks({int limit = 100}) =>
      _post('/api/v1/admin/extract-links?limit=$limit', {}, (d) => d as Map<String, dynamic>);

  Future<Map<String, dynamic>> triggerCrawl({int limit = 50}) =>
      _post('/api/v1/admin/crawl?limit=$limit', {}, (d) => d as Map<String, dynamic>);

  Future<Map<String, dynamic>> crawlSinglePage(String url) =>
      _post('/api/v1/admin/crawl/single', {'url': url}, (d) => d as Map<String, dynamic>);

  Future<List<Map<String, dynamic>>> getLinksStatusByDomain() =>
      _get('/api/v1/admin/links/status/by-domain',
          (d) => (d as List).cast<Map<String, dynamic>>());

  Future<void> deleteDomain(String domain) async {
    final res = await http.delete(
      Uri.parse('${_api.baseUrl}/api/v1/admin/domains/$domain'),
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = (jsonDecode(res.body) as Map<String, dynamic>)['error'] ?? 'Erro';
      throw ApiException(err.toString(), statusCode: res.statusCode);
    }
  }


  Future<Map<String, dynamic>> rescanAll({int limit = 500}) =>
      _post('/api/v1/admin/crawl/rescan?limit=$limit', {}, (d) => d as Map<String, dynamic>);
}
