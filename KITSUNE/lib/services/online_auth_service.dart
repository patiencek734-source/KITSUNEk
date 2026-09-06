import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'online_config.dart';

class OnlineSession {
  const OnlineSession({required this.accessToken, required this.userId, this.email});

  final String accessToken;
  final String userId;
  final String? email;
}

class OnlineAuthService {
  OnlineAuthService({OnlineConfig? config, http.Client? client, FlutterSecureStorage? secure})
      : config = config ?? OnlineConfig.current,
        _client = client ?? http.Client(),
        _secure = secure ?? const FlutterSecureStorage();

  final OnlineConfig config;
  final http.Client _client;
  final FlutterSecureStorage _secure;

  Future<void> requestMagicLink(String email) async {
    _ensureConfigured();
    final response = await _client.post(
      Uri.parse('${config.supabaseUrl}/auth/v1/otp'),
      headers: _headers(),
      body: jsonEncode({'email': email.trim(), 'create_user': true}),
    );
    _check(response);
  }

  Future<OnlineSession> verifyEmailCode({required String email, required String code}) async {
    _ensureConfigured();
    final response = await _client.post(
      Uri.parse('${config.supabaseUrl}/auth/v1/verify'),
      headers: _headers(),
      body: jsonEncode({'email': email.trim(), 'token': code.trim(), 'type': 'email'}),
    );
    _check(response);
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final accessToken = '${data['access_token'] ?? ''}';
    final userId = '${data['user']?['id'] ?? ''}';
    if (accessToken.isEmpty || userId.isEmpty) throw const OnlineAuthException('The sign-in response was incomplete.');
    return OnlineSession(accessToken: accessToken, userId: userId, email: email.trim());
  }

  Future<OnlineSession?> restoreSession() async {
    final token = await _secure.read(key: 'online_access_token');
    final userId = await _secure.read(key: 'online_user_id');
    if (token == null || userId == null || token.isEmpty || userId.isEmpty) return null;
    return OnlineSession(accessToken: token, userId: userId, email: await _secure.read(key: 'online_email'));
  }

  Future<void> saveSession(OnlineSession session) async {
    await _secure.write(key: 'online_access_token', value: session.accessToken);
    await _secure.write(key: 'online_user_id', value: session.userId);
    if (session.email != null) await _secure.write(key: 'online_email', value: session.email);
  }

  Future<void> signOut() async {
    await _secure.delete(key: 'online_access_token');
    await _secure.delete(key: 'online_user_id');
    await _secure.delete(key: 'online_email');
  }

  Map<String, String> _headers([String? token]) => {
        'apikey': config.anonKey,
        'Authorization': 'Bearer ${token ?? config.anonKey}',
        'Content-Type': 'application/json',
      };

  void _ensureConfigured() {
    if (!config.isConfigured) throw const OnlineAuthException('Online chat is not configured. Build with SUPABASE_URL and SUPABASE_ANON_KEY.');
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OnlineAuthException('Online request failed (${response.statusCode}).');
    }
  }
}

class OnlineAuthException implements Exception {
  const OnlineAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
