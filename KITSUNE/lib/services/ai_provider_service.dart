import 'dart:convert';

import 'package:http/http.dart' as http;

enum AiProvider { groq, gemini, anthropic, openAiCompatible }

extension AiProviderLabel on AiProvider {
  String get label => switch (this) {
        AiProvider.groq => 'Groq',
        AiProvider.gemini => 'Google Gemini',
        AiProvider.anthropic => 'Anthropic',
        AiProvider.openAiCompatible => 'Custom OpenAI-compatible',
      };

  String get id => switch (this) {
        AiProvider.groq => 'groq',
        AiProvider.gemini => 'gemini',
        AiProvider.anthropic => 'anthropic',
        AiProvider.openAiCompatible => 'openai_compatible',
      };

  static AiProvider fromId(String? id) => switch (id) {
        'gemini' => AiProvider.gemini,
        'anthropic' => AiProvider.anthropic,
        'openai_compatible' => AiProvider.openAiCompatible,
        _ => AiProvider.groq,
      };
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.endpoint,
  });

  final AiProvider provider;
  final String apiKey;
  final String model;
  final String? endpoint;
}

class AiProviderService {
  AiProviderService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> complete({required AiProviderConfig config, required String prompt}) async {
    if (config.apiKey.trim().isEmpty) throw const AiProviderException('Add an API key before using AI.');
    if (config.model.trim().isEmpty) throw const AiProviderException('Choose a model before using AI.');

    final response = switch (config.provider) {
      AiProvider.groq => await _openAiRequest(
          uri: Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          apiKey: config.apiKey,
          model: config.model,
          prompt: prompt,
        ),
      AiProvider.openAiCompatible => await _openAiRequest(
          uri: Uri.parse(config.endpoint ?? ''),
          apiKey: config.apiKey,
          model: config.model,
          prompt: prompt,
        ),
      AiProvider.gemini => await _geminiRequest(config, prompt),
      AiProvider.anthropic => await _anthropicRequest(config, prompt),
    };
    return response;
  }

  Future<String> _openAiRequest({required Uri uri, required String apiKey, required String model, required String prompt}) async {
    if (!uri.hasScheme) throw const AiProviderException('The custom AI endpoint is not a valid URL.');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({'model': model, 'messages': [{'role': 'user', 'content': prompt}], 'temperature': 0.2}),
    );
    final data = _decode(response);
    final content = data['choices'] is List && (data['choices'] as List).isNotEmpty ? (data['choices'][0]['message']?['content']) : null;
    if (content is! String || content.trim().isEmpty) throw const AiProviderException('The AI provider returned no text.');
    return content.trim();
  }

  Future<String> _geminiRequest(AiProviderConfig config, String prompt) async {
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(config.model)}:generateContent?key=${Uri.encodeQueryComponent(config.apiKey)}');
    final response = await _client.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}]}));
    final data = _decode(response);
    final candidates = data['candidates'];
    final content = candidates is List && candidates.isNotEmpty ? candidates[0]['content']?['parts']?[0]?['text'] : null;
    if (content is! String || content.trim().isEmpty) throw const AiProviderException('Google returned no text.');
    return content.trim();
  }

  Future<String> _anthropicRequest(AiProviderConfig config, String prompt) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {'x-api-key': config.apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
      body: jsonEncode({'model': config.model, 'max_tokens': 900, 'temperature': 0.2, 'messages': [{'role': 'user', 'content': prompt}]}),
    );
    final data = _decode(response);
    final content = data['content'];
    final text = content is List && content.isNotEmpty ? content[0]['text'] : null;
    if (text is! String || text.trim().isEmpty) throw const AiProviderException('Anthropic returned no text.');
    return text.trim();
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw AiProviderException('The AI provider returned an invalid response (${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['error'] is Map ? data['error']['message'] : data['message'];
      throw AiProviderException('${message ?? 'Request failed'} (${response.statusCode}).');
    }
    return data;
  }
}

class AiProviderException implements Exception {
  const AiProviderException(this.message);
  final String message;
  @override
  String toString() => message;
}
