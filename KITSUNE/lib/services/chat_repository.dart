import 'dart:convert';

import 'package:http/http.dart' as http;

import 'online_config.dart';

class ChatRoom {
  const ChatRoom({required this.id, required this.name, this.description = '', this.isPrivate = false});
  final String id;
  final String name;
  final String description;
  final bool isPrivate;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: '${json['id']}',
        name: '${json['name'] ?? 'Room'}',
        description: '${json['description'] ?? ''}',
        isPrivate: json['is_private'] == true,
      );
}

class ChatMessage {
  const ChatMessage({required this.id, required this.roomId, required this.body, required this.authorId, required this.createdAt});
  final String id;
  final String roomId;
  final String body;
  final String authorId;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: '${json['id']}',
        roomId: '${json['room_id']}',
        body: '${json['body'] ?? ''}',
        authorId: '${json['author_id']}',
        createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class ChatRepository {
  ChatRepository({required this.config, required this.accessToken, required this.userId, http.Client? client}) : _client = client ?? http.Client();
  final OnlineConfig config;
  final String accessToken;
  final String userId;
  final http.Client _client;

  Future<List<ChatRoom>> rooms() async {
    final response = await _client.get(Uri.parse('${config.supabaseUrl}/rest/v1/rooms?select=id,name,description,is_private&order=name'), headers: _headers());
    final data = _decodeList(response);
    return data.map(ChatRoom.fromJson).toList();
  }

  Future<List<ChatMessage>> messages(String roomId) async {
    final uri = Uri.parse('${config.supabaseUrl}/rest/v1/messages?select=id,room_id,body,author_id,created_at&room_id=eq.${Uri.encodeComponent(roomId)}&deleted_at=is.null&order=created_at.desc&limit=50');
    final response = await _client.get(uri, headers: _headers());
    return _decodeList(response).map(ChatMessage.fromJson).toList();
  }

  Future<void> sendMessage({required String roomId, required String body}) async {
    final response = await _client.post(Uri.parse('${config.supabaseUrl}/rest/v1/messages'), headers: {..._headers(), 'Prefer': 'return=minimal'}, body: jsonEncode({'room_id': roomId, 'author_id': userId, 'body': body.trim()}));
    if (response.statusCode < 200 || response.statusCode >= 300) throw ChatException('Message could not be sent (${response.statusCode}).');
  }

  Map<String, String> _headers() => {'apikey': config.anonKey, 'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'};

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) throw ChatException('Chat request failed (${response.statusCode}).');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const ChatException('Chat returned an invalid response.');
    return decoded.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
  @override
  String toString() => message;
}
