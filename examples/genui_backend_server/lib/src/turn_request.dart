import 'dart:convert';

import 'package:genkit/genkit.dart' as genkit;

const _interactionMimeType = 'application/vnd.genui.interaction+json';

final class GenUiFlowTurnRequest {
  const GenUiFlowTurnRequest({
    required this.message,
    this.history = const [],
    this.systemPrompt,
    this.catalogId,
    this.metadata = const {},
  });

  factory GenUiFlowTurnRequest.fromJson(Map<String, Object?> json) {
    return GenUiFlowTurnRequest(
      message: _jsonMap(json['message'], 'message'),
      history: [
        for (final item in json['history'] as List<Object?>? ?? const [])
          _jsonMap(item, 'history'),
      ],
      systemPrompt: json['systemPrompt'] as String?,
      catalogId: json['catalogId'] as String?,
      metadata: json['metadata'] == null
          ? const {}
          : _jsonMap(json['metadata'], 'metadata'),
    );
  }

  final Map<String, Object?> message;
  final List<Map<String, Object?>> history;
  final String? systemPrompt;
  final String? catalogId;
  final Map<String, Object?> metadata;
}

List<genkit.Message> genkitMessagesForTurn(GenUiFlowTurnRequest request) {
  return [
    if (request.systemPrompt != null && request.systemPrompt!.isNotEmpty)
      genkit.Message(
        role: genkit.Role.system,
        content: [genkit.TextPart(text: request.systemPrompt!)],
      ),
    for (final previous in request.history)
      if (genUiMessageText(previous).trim().isNotEmpty)
        genkitMessageForJson(previous),
    genkitMessageForJson(request.message),
  ];
}

genkit.Message genkitMessageForJson(Map<String, Object?> message) {
  return genkit.Message(
    role: _roleForJson(message['role'] as String?),
    content: [genkit.TextPart(text: genUiMessageText(message))],
  );
}

String genUiMessageText(Map<String, Object?> message) {
  final fragments = <String>[];
  final parts = message['parts'] as List<Object?>? ?? const [];

  for (final rawPart in parts) {
    if (rawPart is! Map) continue;
    final part = Map<String, Object?>.from(rawPart);
    switch (part['type']) {
      case 'Text':
        final content = part['content'] as String? ?? '';
        if (content.trim().isNotEmpty) fragments.add(content.trim());
      case 'Data':
        final interaction = _interactionFromDataPart(part);
        if (interaction != null && interaction.trim().isNotEmpty) {
          fragments.add('User interacted with generated UI: $interaction');
        }
      default:
        break;
    }
  }

  if (fragments.isNotEmpty) return fragments.join('\n\n');
  return jsonEncode(message);
}

Map<String, Object?> resultMetadataFromResponse(
  genkit.GenerateResponseHelper<Object?> response,
) {
  return {
    'finishReason': response.modelResponse.finishReason.value,
    if (response.modelResponse.finishMessage != null)
      'finishMessage': response.modelResponse.finishMessage,
    if (response.modelResponse.usage != null)
      'usage': response.modelResponse.usage!.toJson(),
  };
}

genkit.Role _roleForJson(String? role) {
  return switch (role) {
    'system' => genkit.Role.system,
    'model' => genkit.Role.model,
    'user' || null => genkit.Role.user,
    _ => genkit.Role.user,
  };
}

String? _interactionFromDataPart(Map<String, Object?> part) {
  final content = part['content'];
  if (content is! Map) return null;
  final contentJson = Map<String, Object?>.from(content);
  if (contentJson['mimeType'] != _interactionMimeType) return null;

  final bytesUri = contentJson['bytes'] as String?;
  if (bytesUri == null || bytesUri.isEmpty) return null;
  final data = Uri.parse(bytesUri).data;
  if (data == null) return null;

  final decoded = jsonDecode(utf8.decode(data.contentAsBytes()));
  if (decoded is! Map) return null;
  return decoded['interaction'] as String?;
}

Map<String, Object?> _jsonMap(Object? value, String fieldName) {
  if (value is! Map) {
    throw FormatException('Expected "$fieldName" to be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}
