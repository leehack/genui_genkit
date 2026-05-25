import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('RemoteGenkitFlowBackend streams chunks from a Genkit flow', () async {
    http.Request? seenRequest;
    final backend = RemoteGenkitFlowBackend(
      flowUrl: Uri.parse('https://example.test/genui'),
      client: MockClient((request) async {
        seenRequest = request;
        return http.Response(
          [
            'data: {"message":"hello "}',
            '',
            'data: {"message":"world"}',
            '',
            'data: {"result":{"finishReason":"stop"}}',
            '',
            '',
          ].join('\n'),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final events = await backend
        .send(
          GenUiTurnRequest(
            message: ChatMessage.user('world'),
            catalogId: 'catalog.test',
            metadata: const {'route': 'backend'},
          ),
        )
        .toList();

    expect(seenRequest!.headers['Accept'], 'text/event-stream');
    final body = jsonDecode(seenRequest!.body) as Map<String, Object?>;
    expect(body['data'], isA<Map<String, Object?>>());
    expect((events[0] as GenUiTextChunk).text, 'hello ');
    expect((events[1] as GenUiTextChunk).text, 'world');
    expect((events[2] as GenUiTurnDone).metadata['finishReason'], 'stop');

    await backend.dispose();
  });
}
