import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart' as v0_9;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit/genui_genkit.dart';

void main() {
  test('session records user and streamed assistant text', () async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => Stream.value('ack')),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
    );

    await session.sendText('hello');

    expect(session.messages.map((m) => m.text).toList(), ['hello', 'ack']);
    expect(session.messages.first.isUser, isTrue);
    expect(session.messages.last.isUser, isFalse);

    session.dispose();
  });

  test('session exposes raw text chunks', () async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (_) => Stream<String>.fromIterable(['a', 'b']),
      ),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
    );

    final raw = <String>[];
    final sub = session.rawText.listen(raw.add);

    await session.sendText('go');

    expect(raw, ['a', 'b']);
    await sub.cancel();
    session.dispose();
  });

  test(
    'session forwards parsed A2UI messages to the message processor',
    () async {
      final catalog = v0_9.basicCatalog();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.fromIterable(
            _surfaceStream(catalog.id, includeVersion: true),
          ),
        ),
        catalog: catalog,
      );

      await session.sendText('go');
      await _waitForSurface(session, 's1');

      expect(
        session.messages.any((message) => message.surfaceId == 's1'),
        isTrue,
      );
      session.dispose();
    },
  );

  test(
    'session repairs A2UI messages that omit the top-level version',
    () async {
      final catalog = v0_9.basicCatalog();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.fromIterable(
            _surfaceStream(catalog.id, includeVersion: false),
          ),
        ),
        catalog: catalog,
      );

      await session.sendText('go');
      await _waitForSurface(session, 's1');

      expect(
        session.messages.any((message) => message.surfaceId == 's1'),
        isTrue,
      );
      expect(
        session.messages
            .map((message) => message.text)
            .whereType<String>()
            .any((text) => text.contains('createSurface')),
        isFalse,
      );
      session.dispose();
    },
  );

  test(
    'session repairs nested component objects before rendering a surface',
    () async {
      final catalog = v0_9.basicCatalog();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.fromIterable(
            _surfaceStream(
              catalog.id,
              includeVersion: false,
              nestedComponent: true,
            ),
          ),
        ),
        catalog: catalog,
      );

      await session.sendText('go');
      await _waitForSurface(session, 's1');

      expect(
        session.messages.any((message) => message.surfaceId == 's1'),
        isTrue,
      );
      expect(
        session.messages
            .map((message) => message.text)
            .whereType<String>()
            .any((text) => text.contains('updateComponents')),
        isFalse,
      );
      session.dispose();
    },
  );

  test(
    'session renders updateComponents-only output with an unclosed fence',
    () async {
      final catalog = v0_9.basicCatalog();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.value('''
```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "root",
        "component": "Text",
        "text": "hello"
      }
    ]
  }
}
'''),
        ),
        catalog: catalog,
      );

      await session.sendText('go');
      await _waitForSurface(session, 's1');

      expect(
        session.messages.any((message) => message.surfaceId == 's1'),
        isTrue,
      );
      expect(
        session.messages
            .map((message) => message.text)
            .whereType<String>()
            .any((text) => text.contains('updateComponents')),
        isFalse,
      );
      session.dispose();
    },
  );

  test(
    'session repairs combined A2UI messages and missing root component',
    () async {
      final catalog = v0_9.basicCatalog();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.value('''
```json
{
  "createSurface": {
    "surfaceId": "s1",
    "catalogId": "${catalog.id}"
  },
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "message",
        "component": "Text",
        "text": "hello"
      }
    ]
  }
}
```
'''),
        ),
        catalog: catalog,
      );

      await session.sendText('go');
      await _waitForSurface(session, 's1');

      expect(
        session.messages.any((message) => message.surfaceId == 's1'),
        isTrue,
      );
      expect(
        session.messages
            .map((message) => message.text)
            .whereType<String>()
            .any((text) => text.contains('createSurface')),
        isFalse,
      );
      session.dispose();
    },
  );

  test(
    'session preserves whitespace-only chunks in visible assistant text',
    () async {
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.fromIterable(['hello', ' ', 'world']),
        ),
        catalog: CatalogImplementation(
          id: 'test.catalog',
          components: const [],
        ),
      );

      await session.sendText('go');

      expect(session.messages.last.text, 'hello world');
      session.dispose();
    },
  );

  test(
    'session sends prior user and assistant messages as next-turn history',
    () async {
      final requests = <GenUiTurnRequest>[];
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (request) {
            requests.add(request);
            return Stream.value('response ${requests.length}');
          },
        ),
        catalog: CatalogImplementation(
          id: 'test.catalog',
          components: const [],
        ),
      );

      await session.sendText('first');
      await session.sendText('second');

      expect(requests, hasLength(2));
      expect(requests.last.history.map((message) => message.text), [
        'first',
        'response 1',
      ]);
      expect(requests.last.history.map((message) => message.role.name), [
        'user',
        'model',
      ]);
      session.dispose();
    },
  );

  test('session merges static and per-turn metadata', () async {
    final requests = <GenUiTurnRequest>[];
    var route = 'local';
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (request) {
          requests.add(request);
          return Stream.value('ack');
        },
      ),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
      metadata: const {'app': 'test'},
      metadataBuilder: () => {'route': route},
    );

    await session.sendText('first');
    route = 'backend';
    await session.sendText('second');

    expect(requests.first.metadata, {'app': 'test', 'route': 'local'});
    expect(requests.last.metadata, {'app': 'test', 'route': 'backend'});
    session.dispose();
  });

  test('session can clear messages and next-turn history', () async {
    final requests = <GenUiTurnRequest>[];
    var responseIndex = 0;
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (request) {
          requests.add(request);
          responseIndex += 1;
          return Stream.value('response $responseIndex');
        },
      ),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
    );

    await session.sendText('first');
    session.clear();
    await session.sendText('second');

    expect(session.messages.map((message) => message.text), [
      'second',
      'response 2',
    ]);
    expect(requests.last.history, isEmpty);
    session.dispose();
  });

  test('session ignores programmatic send while a turn is active', () async {
    final controller = StreamController<String>();
    var sends = 0;
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (_) {
          sends += 1;
          return controller.stream;
        },
      ),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
    );

    final first = session.sendText('first');
    await Future<void>.delayed(Duration.zero);
    await session.sendText('second');
    controller.add('done');
    await controller.close();
    await first;

    expect(sends, 1);
    expect(
      session.messages
          .where((message) => message.isUser)
          .map((message) => message.text),
      ['first'],
    );
    session.dispose();
  });

  test(
    'disposing during an active stream completes the pending send',
    () async {
      final controller = StreamController<String>();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(generate: (_) => controller.stream),
        catalog: CatalogImplementation(
          id: 'test.catalog',
          components: const [],
        ),
      );

      final send = session.sendText('first');
      await Future<void>.delayed(Duration.zero);

      session.dispose();
      await send.timeout(const Duration(seconds: 1));

      controller.add('ignored after disposal');
      await controller.close();
    },
  );

  test('session can build a prompt from multiple catalogs', () async {
    GenUiTurnRequest? seenRequest;
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (request) {
          seenRequest = request;
          return Stream.value('ack');
        },
      ),
      catalogs: [
        CatalogImplementation(id: 'first.catalog', components: const []),
        CatalogImplementation(id: 'second.catalog', components: const []),
      ],
    );

    await session.sendText('hello');

    expect(session.catalogs.map((catalog) => catalog.id), [
      'first.catalog',
      'second.catalog',
    ]);
    expect(seenRequest!.catalogId, 'first.catalog');
    expect(seenRequest!.systemPrompt, contains('first.catalog'));
    expect(seenRequest!.systemPrompt, contains('second.catalog'));

    session.dispose();
  });

  test(
    'session removes surface chat entries when a surface is deleted',
    () async {
      final catalog = v0_9.basicCatalog();
      final session = GenkitGenUiSession(
        backend: LocalGenkitBackend(
          generate: (_) => Stream<String>.fromIterable([
            ..._surfaceStream(catalog.id, includeVersion: true),
            '\n```json\n',
            '{"version":"v0.9","deleteSurface":{"surfaceId":"s1"}}',
            '\n```',
          ]),
        ),
        catalog: catalog,
        systemPromptOptions: GenUiSystemPromptOptions(
          surfaceOperations: SurfaceOperations.all(dataModel: false),
        ),
      );

      await session.sendText('go');
      await Future<void>.delayed(Duration.zero);

      expect(
        session.messages.any((message) => message.surfaceId == 's1'),
        isFalse,
      );
      session.dispose();
    },
  );

  test(
    'cancelActiveTurn stops the backend and avoids adding cancelled history',
    () async {
      final firstTurn = StreamController<GenUiBackendEvent>();
      final requests = <GenUiTurnRequest>[];
      var cancelCalled = false;
      final session = GenkitGenUiSession(
        backend: _SessionTestBackend(
          onSend: (request) {
            requests.add(request);
            if (requests.length == 1) return firstTurn.stream;
            return Stream<GenUiBackendEvent>.fromIterable([
              const GenUiTextChunk('second response'),
              const GenUiTurnDone(),
            ]);
          },
          onCancel: () {
            cancelCalled = true;
          },
        ),
        catalog: CatalogImplementation(
          id: 'test.catalog',
          components: const [],
        ),
      );

      final firstSend = session.sendText('first');
      await Future<void>.delayed(Duration.zero);

      await session.cancelActiveTurn();
      await firstSend.timeout(const Duration(seconds: 1));
      await firstTurn.close();
      await session.sendText('second');

      expect(cancelCalled, isTrue);
      expect(requests, hasLength(2));
      expect(requests.last.history, isEmpty);
      expect(session.messages.map((message) => message.text), [
        'first',
        'second',
        'second response',
      ]);

      session.dispose();
    },
  );

  test('session renders A2UI messages written in a2ui-json blocks', () async {
    final catalog = v0_9.basicCatalog();
    final requests = <GenUiTurnRequest>[];
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (request) {
          requests.add(request);
          return Stream<String>.value('''
Here is your UI.
<a2ui-json>
[
  {"version": "v0.9", "createSurface": {"surfaceId": "s1", "catalogId": "${catalog.id}"}},
  {"version": "v0.9", "updateComponents": {"surfaceId": "s1", "components": [
    {"id": "root", "component": "Text", "text": "hello"}
  ]}}
]
</a2ui-json>
''');
        },
      ),
      catalog: catalog,
    );

    await session.sendText('go');
    await _waitForSurface(session, 's1');
    await Future<void>.delayed(Duration.zero);

    expect(
      session.messages.map((message) => message.surfaceId ?? message.text),
      ['go', 'Here is your UI.', 's1'],
    );
    expect(requests, hasLength(1));
    session.dispose();
  });

  test('session sends A2UI errors to the backend as a new turn', () async {
    final requests = <GenUiTurnRequest>[];
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (request) {
          requests.add(request);
          if (requests.length > 1) return Stream.value('ack');
          return Stream<String>.value(
            '```json\n'
            '{"version":"v0.9","createSurface":'
            '{"surfaceId":"s1","catalogId":"unknown.catalog"}}\n'
            '```',
          );
        },
      ),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
    );

    await session.sendText('go');
    for (var i = 0; i < 100 && requests.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(requests, hasLength(2));
    final text = defaultGenkitMessageText(requests.last.message);
    expect(text, startsWith('User interacted with generated UI: '));
    expect(text, contains('CATALOG_NOT_FOUND'));
    session.dispose();
  });
}

List<String> _surfaceStream(
  String catalogId, {
  required bool includeVersion,
  bool nestedComponent = false,
}) {
  final version = includeVersion ? '"version":"v0.9",' : '';
  final component = nestedComponent
      ? '"component":{"component":"Text","text":"hello"}'
      : '"component":"Text","text":"hello"';
  return [
    '```json\n',
    '{$version"createSurface":{"surfaceId":"s1","catalogId":"$catalogId"}}',
    '\n```\n',
    '```json\n',
    '{$version"updateComponents":{"surfaceId":"s1","components":[{"id":"root",$component}]}}',
    '\n```',
  ];
}

Future<void> _waitForSurface(
  GenkitGenUiSession session,
  String surfaceId,
) async {
  if (session.messages.any((message) => message.surfaceId == surfaceId)) {
    return;
  }

  final completer = Completer<void>();
  void listener() {
    if (!completer.isCompleted &&
        session.messages.any((message) => message.surfaceId == surfaceId)) {
      completer.complete();
    }
  }

  session.addListener(listener);
  try {
    listener();
    await completer.future.timeout(const Duration(seconds: 1));
  } finally {
    session.removeListener(listener);
  }
}

final class _SessionTestBackend implements GenUiBackend {
  const _SessionTestBackend({required this.onSend, this.onCancel});

  final Stream<GenUiBackendEvent> Function(GenUiTurnRequest request) onSend;
  final void Function()? onCancel;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) => onSend(request);

  @override
  Future<void> cancelActiveTurn() async {
    onCancel?.call();
  }

  @override
  Future<void> dispose() async {}
}
