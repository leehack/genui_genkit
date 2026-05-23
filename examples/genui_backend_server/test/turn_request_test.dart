import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genui_backend_server/src/turn_request.dart';
import 'package:test/test.dart';

void main() {
  test('remote flow request JSON maps to Genkit messages', () {
    final request = GenUiFlowTurnRequest.fromJson({
      'systemPrompt': 'Render A2UI JSON.',
      'message': _message('user', 'Build a plan'),
      'history': [_message('model', 'Previous answer')],
      'catalogId': 'dev.example.catalog',
      'metadata': {'route': 'backend'},
    });

    final messages = genkitMessagesForTurn(request);

    expect(request.catalogId, 'dev.example.catalog');
    expect(request.metadata['route'], 'backend');
    expect(messages.map((message) => message.role.value), [
      'system',
      'model',
      'user',
    ]);
    expect(messages.last.text, 'Build a plan');
  });

  test('UI interaction data parts are preserved as model context', () {
    final message = _message(
      'user',
      '',
      parts: [_interactionPart('{"choice":"museum"}')],
    );

    expect(
      genUiMessageText(message),
      'User interacted with generated UI: {"choice":"museum"}',
    );
  });
}

Map<String, Object?> _message(
  String role,
  String text, {
  List<Map<String, Object?>> parts = const [],
}) {
  return {
    'role': role,
    'metadata': const {},
    'parts': [
      if (text.isNotEmpty) {'type': 'Text', 'content': text},
      ...parts,
    ],
  };
}

Map<String, Object?> _interactionPart(String interaction) {
  final payload = base64Encode(
    utf8.encode(jsonEncode({'interaction': interaction})),
  );
  return {
    'type': 'Data',
    'content': {
      'bytes': 'data:application/vnd.genui.interaction+json;base64,$payload',
      'mimeType': 'application/vnd.genui.interaction+json',
      'name': 'json',
    },
  };
}
