import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as genkit;
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

void main() {
  test('LocalGenkitBackend emits text chunks followed by done', () async {
    final backend = LocalGenkitBackend(
      generate: (request) =>
          Stream<String>.fromIterable(['hello', ' ', request.message.text]),
    );

    final events = await backend
        .send(GenUiTurnRequest(message: ChatMessage.user('world')))
        .toList();

    expect(events, hasLength(4));
    expect((events[0] as GenUiTextChunk).text, 'hello');
    expect((events[1] as GenUiTextChunk).text, ' ');
    expect((events[2] as GenUiTextChunk).text, 'world');
    expect(events[3], isA<GenUiTurnDone>());
  });

  test('GenUiTurnRequest serializes for remote flow transport', () {
    final request = GenUiTurnRequest(
      message: ChatMessage.user('hello'),
      history: [ChatMessage.model('previous')],
      systemPrompt: 'Use A2UI.',
      catalogId: 'catalog.test',
      metadata: const {'route': 'backend'},
    );

    final decoded = genUiTurnRequestFromJson(genUiTurnRequestToJson(request));

    expect(decoded.message.text, 'hello');
    expect(decoded.history.single.text, 'previous');
    expect(decoded.systemPrompt, 'Use A2UI.');
    expect(decoded.catalogId, 'catalog.test');
    expect(decoded.metadata['route'], 'backend');
  });

  test(
    'LocalGenkitBackend converts generator errors to error events',
    () async {
      final backend = LocalGenkitBackend(
        generate: (_) => Stream<String>.error(StateError('boom')),
      );

      final events = await backend
          .send(GenUiTurnRequest(message: ChatMessage.user('hi')))
          .toList();

      expect(events.single, isA<GenUiBackendError>());
      expect((events.single as GenUiBackendError).message, contains('boom'));
    },
  );

  test('GenkitBackend streams text from a registered Genkit model', () async {
    final ai = genkit.Genkit();
    genkit.ModelRequest? seenRequest;
    ai.defineModel(
      name: 'streaming-model',
      fn: (request, context) async {
        seenRequest = request;
        context
          ..sendChunk(
            genkit.ModelResponseChunk(
              content: [genkit.TextPart(text: 'hello ')],
            ),
          )
          ..sendChunk(
            genkit.ModelResponseChunk(
              content: [genkit.TextPart(text: request.messages.last.text)],
            ),
          );
        return genkit.ModelResponse(
          finishReason: genkit.FinishReason.stop,
          message: genkit.Message(
            role: genkit.Role.model,
            content: [genkit.TextPart(text: 'done')],
          ),
        );
      },
    );
    final backend = GenkitBackend<Map<String, dynamic>>(
      ai: ai,
      model: genkit.modelRef('streaming-model'),
      configBuilder: (request) => {
        'temperature': request.metadata['temperature'],
      },
    );

    final events = await backend
        .send(
          GenUiTurnRequest(
            message: ChatMessage.user('world'),
            history: [ChatMessage.model('previous answer')],
            systemPrompt: 'Use A2UI.',
            metadata: const {'temperature': 0.1},
          ),
        )
        .toList();

    expect(events, hasLength(3));
    expect((events[0] as GenUiTextChunk).text, 'hello ');
    expect((events[1] as GenUiTextChunk).text, 'world');
    expect(events[2], isA<GenUiTurnDone>());
    expect(seenRequest!.messages.map((message) => message.role.value), [
      'system',
      'model',
      'user',
    ]);
    expect(seenRequest!.config, {'temperature': 0.1});

    await backend.dispose();
    await ai.shutdown();
  });

  test(
    'GenkitBackend emits final text when provider sends no chunks',
    () async {
      final ai = genkit.Genkit();
      ai.defineModel(
        name: 'non-streaming-model',
        fn: (request, context) async {
          return genkit.ModelResponse(
            finishReason: genkit.FinishReason.stop,
            message: genkit.Message(
              role: genkit.Role.model,
              content: [
                genkit.TextPart(text: 'final ${request.messages.last.text}'),
              ],
            ),
          );
        },
      );
      final backend = GenkitBackend<Map<String, dynamic>>(
        ai: ai,
        model: genkit.modelRef('non-streaming-model'),
      );

      final events = await backend
          .send(GenUiTurnRequest(message: ChatMessage.user('answer')))
          .toList();

      expect(events, hasLength(2));
      expect((events[0] as GenUiTextChunk).text, 'final answer');
      expect(events[1], isA<GenUiTurnDone>());

      await backend.dispose();
      await ai.shutdown();
    },
  );

  test('HybridGenUiBackend routes turns by policy', () async {
    final local = _RecordingBackend(
      (request) => Stream<GenUiBackendEvent>.fromIterable([
        GenUiTextChunk('local:${request.message.text}'),
        const GenUiTurnDone(),
      ]),
    );
    final remote = _RecordingBackend(
      (request) => Stream<GenUiBackendEvent>.fromIterable([
        GenUiTextChunk('remote:${request.message.text}'),
        const GenUiTurnDone(),
      ]),
    );
    final backend = HybridGenUiBackend(
      routes: {'local': local, 'remote': remote},
      policy: (request, _) => request.metadata['route']! as String,
    );

    final events = await backend
        .send(
          GenUiTurnRequest(
            message: ChatMessage.user('hello'),
            metadata: const {'route': 'remote'},
          ),
        )
        .toList();

    expect((events.first as GenUiTextChunk).text, 'remote:hello');
    expect(local.requests, isEmpty);
    expect(remote.requests.single.message.text, 'hello');

    await backend.dispose();
    expect(local.disposed, isTrue);
    expect(remote.disposed, isTrue);
  });

  test('HybridGenUiBackend cancels the active route', () async {
    final controller = StreamController<GenUiBackendEvent>();
    final routed = _RecordingBackend((_) => controller.stream);
    final backend = HybridGenUiBackend(
      routes: {'local': routed},
      policy: (_, _) => 'local',
    );

    final events = <GenUiBackendEvent>[];
    final subscription = backend
        .send(GenUiTurnRequest(message: ChatMessage.user('hello')))
        .listen(events.add);
    await Future<void>.delayed(Duration.zero);

    await backend.cancelActiveTurn();
    await controller.close();
    await subscription.cancel();

    expect(routed.cancelled, isTrue);
    expect(events, isEmpty);
    await backend.dispose();
  });

  test('HybridGenUiBackend disposes shared route instances once', () async {
    final shared = _RecordingBackend((_) => const Stream.empty());
    final backend = HybridGenUiBackend(
      routes: {'primary': shared, 'fallback': shared},
      policy: (_, _) => 'primary',
    );

    await backend.dispose();

    expect(shared.disposeCount, 1);
  });
}

final class _RecordingBackend implements GenUiBackend {
  _RecordingBackend(this._send);

  final Stream<GenUiBackendEvent> Function(GenUiTurnRequest request) _send;
  final List<GenUiTurnRequest> requests = [];
  var cancelled = false;
  var disposed = false;
  var disposeCount = 0;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) {
    requests.add(request);
    return _send(request);
  }

  @override
  Future<void> cancelActiveTurn() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    disposed = true;
  }
}
