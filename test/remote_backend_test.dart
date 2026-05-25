import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('RemoteGenUiBackend posts a turn and parses SSE events', () async {
    http.Request? seenRequest;
    final client = MockClient((request) async {
      seenRequest = request;
      return http.Response(
        [
          'event: chunk',
          'data: {"text":"hello "}',
          '',
          'event: chunk',
          'data: {"text":"world"}',
          '',
          'event: done',
          'data: {"finishReason":"stop"}',
          '',
        ].join('\n'),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final backend = RemoteGenUiBackend(
      endpoint: Uri.parse('https://example.test/genui'),
      client: client,
      headers: const {'authorization': 'Bearer test'},
    );

    final events = await backend
        .send(
          GenUiTurnRequest(
            message: ChatMessage.user('world'),
            history: [ChatMessage.model('previous')],
            systemPrompt: 'Use A2UI.',
            catalogId: 'catalog.test',
            metadata: const {'route': 'remote'},
          ),
        )
        .toList();

    expect(seenRequest!.method, 'POST');
    expect(seenRequest!.headers['accept'], 'text/event-stream');
    expect(seenRequest!.headers['authorization'], 'Bearer test');
    final body = jsonDecode(seenRequest!.body) as Map<String, Object?>;
    expect(
      ((body['message'] as Map<String, Object?>)['parts'] as List<Object?>),
      isNotEmpty,
    );
    expect(body['catalogId'], 'catalog.test');
    expect((body['metadata'] as Map<String, Object?>)['route'], 'remote');
    expect(events, hasLength(3));
    expect((events[0] as GenUiTextChunk).text, 'hello ');
    expect((events[1] as GenUiTextChunk).text, 'world');
    expect((events[2] as GenUiTurnDone).metadata['finishReason'], 'stop');

    await backend.dispose();
  });

  test('RemoteGenUiBackend reports non-success status codes', () async {
    final backend = RemoteGenUiBackend(
      endpoint: Uri.parse('https://example.test/genui'),
      client: MockClient((_) async => http.Response('nope', 503)),
    );

    final events = await backend
        .send(GenUiTurnRequest(message: ChatMessage.user('hello')))
        .toList();

    expect(events.single, isA<GenUiBackendError>());
    expect((events.single as GenUiBackendError).message, contains('503'));
    await backend.dispose();
  });
}
