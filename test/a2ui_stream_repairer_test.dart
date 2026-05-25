import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit/src/a2ui_stream_repairer.dart';

void main() {
  test('adds v0.9 to a markdown A2UI object missing only version', () async {
    final output = await Stream<String>.value('''Before.

```json
{"createSurface":{"surfaceId":"s1","catalogId":"test.catalog"}}
```
After.''').transform(const A2uiStreamRepairer()).join();

    expect(output, contains('"version": "v0.9"'));
    expect(output, contains('"createSurface"'));
    expect(output, startsWith('Before.'));
    expect(output, endsWith('After.'));
  });

  test('repairs split streamed A2UI blocks', () async {
    final chunks = Stream<String>.fromIterable([
      '```json\n{"updateComponents":',
      '{"surfaceId":"s1","components":[]}}\n```',
    ]);

    final output = await chunks.transform(const A2uiStreamRepairer()).join();
    final jsonText = output
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;

    expect(decoded['version'], 'v0.9');
    expect(decoded, contains('updateComponents'));
  });

  test('repairs an unclosed markdown A2UI block at stream end', () async {
    const input =
        '```json\n{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[]}}';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();
    final jsonText = output
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;

    expect(output, endsWith('\n```'));
    expect(decoded['version'], 'v0.9');
    expect(decoded, contains('updateComponents'));
  });

  test('repairs complete A2UI text synchronously', () {
    const input =
        'Ack\n```json\n{"updateComponents":{"surfaceId":"s1","components":[]}}';

    final output = repairCompleteA2uiText(input);
    final jsonText = output
        .replaceFirst('Ack', '')
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;

    expect(output, startsWith('Ack'));
    expect(output, endsWith('\n```'));
    expect(decoded['version'], 'v0.9');
    expect(decoded, contains('updateComponents'));
  });

  test('splits combined A2UI operations into separate messages', () async {
    const input = '''
```json
{
  "createSurface": {
    "surfaceId": "s1",
    "catalogId": "test.catalog"
  },
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "root",
        "component": "ActivityCard",
        "title": "Cafe",
        "description": "Warm drink nearby."
      }
    ]
  }
}
```
''';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();
    final jsonText = output
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as List<Object?>;
    final create = decoded[0] as Map<String, Object?>;
    final update = decoded[1] as Map<String, Object?>;

    expect(decoded, hasLength(2));
    expect(create['version'], 'v0.9');
    expect(create, contains('createSurface'));
    expect(create, isNot(contains('updateComponents')));
    expect(update['version'], 'v0.9');
    expect(update, contains('updateComponents'));
    expect(update, isNot(contains('createSurface')));
  });

  test(
    'flattens nested component definitions inside updateComponents',
    () async {
      const input = '''
```json
{
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "root",
        "component": {
          "component": "ActivityCard",
          "title": "Cafe stop",
          "description": "Warm drink nearby."
        }
      }
    ]
  }
}
```
''';

      final output = await Stream<String>.value(
        input,
      ).transform(const A2uiStreamRepairer()).join();
      final jsonText = output
          .replaceFirst('```json', '')
          .replaceFirst('```', '')
          .trim();
      final decoded = jsonDecode(jsonText) as Map<String, Object?>;
      final update = decoded['updateComponents'] as Map<String, Object?>;
      final components = update['components'] as List<Object?>;
      final root = components.single as Map<String, Object?>;

      expect(decoded['version'], 'v0.9');
      expect(root['id'], 'root');
      expect(root['component'], 'ActivityCard');
      expect(root['title'], 'Cafe stop');
      expect(root['description'], 'Warm drink nearby.');
    },
  );

  test('promotes a single component to root when root is missing', () async {
    const input = '''
```json
{
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "plan",
        "component": "ItineraryPlan",
        "title": "Rainy plan",
        "summary": "Stay dry.",
        "stops": []
      }
    ]
  }
}
```
''';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();
    final jsonText = output
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;
    final update = decoded['updateComponents'] as Map<String, Object?>;
    final components = update['components'] as List<Object?>;
    final root = components.single as Map<String, Object?>;

    expect(root['id'], 'root');
    expect(root['component'], 'ItineraryPlan');
  });

  test(
    'wraps sibling components in a root Column when root is missing',
    () async {
      const input = '''
```json
{
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "plan",
        "component": "ItineraryPlan",
        "title": "Rainy plan",
        "summary": "Stay dry.",
        "stops": []
      },
      {
        "id": "card",
        "component": "ActivityCard",
        "title": "Bookstore",
        "description": "Browse shelves."
      }
    ]
  }
}
```
''';

      final output = await Stream<String>.value(
        input,
      ).transform(const A2uiStreamRepairer()).join();
      final jsonText = output
          .replaceFirst('```json', '')
          .replaceFirst('```', '')
          .trim();
      final decoded = jsonDecode(jsonText) as Map<String, Object?>;
      final update = decoded['updateComponents'] as Map<String, Object?>;
      final components = update['components'] as List<Object?>;
      final root = components.first as Map<String, Object?>;
      final plan = components[1] as Map<String, Object?>;
      final card = components[2] as Map<String, Object?>;

      expect(root['id'], 'root');
      expect(root['component'], 'Column');
      expect(root['children'], ['plan', 'card']);
      expect(plan['id'], 'plan');
      expect(card['id'], 'card');
    },
  );

  test('drops string entries from updateComponents component lists', () async {
    const input = '''
```json
{
  "updateComponents": {
    "surfaceId": "s1",
    "components": ["root"]
  }
}
```
''';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();
    final jsonText = output
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;
    final update = decoded['updateComponents'] as Map<String, Object?>;
    final components = update['components'] as List<Object?>;

    expect(decoded['version'], 'v0.9');
    expect(components, isEmpty);
  });

  test(
    'moves component lists from createSurface into updateComponents',
    () async {
      const input = '''
```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "s1",
    "catalogId": "test.catalog",
    "components": [
      {
        "component": "ActivityCard",
        "title": "Cafe",
        "description": "Warm drink nearby."
      },
      {
        "component": "Checklist",
        "title": "Prep",
        "items": ["Umbrella"]
      }
    ]
  }
}
```
''';

      final output = await Stream<String>.value(
        input,
      ).transform(const A2uiStreamRepairer()).join();
      final jsonText = output
          .replaceFirst('```json', '')
          .replaceFirst('```', '')
          .trim();
      final decoded = jsonDecode(jsonText) as List<Object?>;
      final create = decoded[0] as Map<String, Object?>;
      final update = decoded[1] as Map<String, Object?>;
      final createSurface = create['createSurface'] as Map<String, Object?>;
      final updateComponents =
          update['updateComponents'] as Map<String, Object?>;
      final components = updateComponents['components'] as List<Object?>;
      final root = components.first as Map<String, Object?>;

      expect(createSurface, isNot(contains('components')));
      expect(updateComponents['surfaceId'], 's1');
      expect(root['component'], 'Column');
      expect(root['children'], ['activity_card', 'checklist']);
    },
  );

  test('extracts inline layout children into flat component entries', () async {
    const input = '''
```json
{
  "updateComponents": {
    "surfaceId": "s1",
    "components": [
      {
        "id": "root",
        "component": "Column",
        "children": [
          {
            "id": "plan",
            "component": {
              "component": "ItineraryPlan",
              "title": "Rainy plan",
              "summary": "Stay dry.",
              "stops": [
                {
                  "title": "Cafe",
                  "details": "Warm up."
                }
              ]
            }
          },
          {
            "id": "card",
            "component": "ActivityCard",
            "title": "Bookstore",
            "description": "Browse shelves."
          }
        ]
      }
    ]
  }
}
```
''';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();
    final jsonText = output
        .replaceFirst('```json', '')
        .replaceFirst('```', '')
        .trim();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;
    final update = decoded['updateComponents'] as Map<String, Object?>;
    final components = update['components'] as List<Object?>;
    final root = components.first as Map<String, Object?>;
    final plan = components[1] as Map<String, Object?>;
    final card = components[2] as Map<String, Object?>;

    expect(root['children'], ['plan', 'card']);
    expect(plan['id'], 'plan');
    expect(plan['component'], 'ItineraryPlan');
    expect(card['id'], 'card');
    expect(card['component'], 'ActivityCard');
  });

  test(
    'repairs A2UI JSON that includes comments and trailing commas',
    () async {
      const input = '''
```json
{
  // Models sometimes annotate JSON despite being asked not to.
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "s1",
    "catalogId": "test.catalog",
  },
}
```
''';

      final output = await Stream<String>.value(
        input,
      ).transform(const A2uiStreamRepairer()).join();
      final jsonText = output
          .replaceFirst('```json', '')
          .replaceFirst('```', '')
          .trim();
      final decoded = jsonDecode(jsonText) as Map<String, Object?>;

      expect(decoded['version'], 'v0.9');
      expect(decoded, contains('createSurface'));
      expect(jsonText, isNot(contains('//')));
    },
  );

  test('does not strip comment-like text inside strings', () async {
    const input =
        '{"createSurface":{"surfaceId":"https://example.test/s1","catalogId":"test.catalog"}}';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();
    final decoded = jsonDecode(output) as Map<String, Object?>;
    final create = decoded['createSurface'] as Map<String, Object?>;

    expect(decoded['version'], 'v0.9');
    expect(create['surfaceId'], 'https://example.test/s1');
  });

  test(
    'waits for a closing markdown fence before repairing inner JSON',
    () async {
      final chunks = Stream<String>.fromIterable([
        '```json\n',
        '{"createSurface":{"surfaceId":"s1","catalogId":"test.catalog"}}',
        '\n```',
      ]);

      final output = await chunks.transform(const A2uiStreamRepairer()).join();

      expect(output, startsWith('```json\n'));
      expect(output, endsWith('\n```'));
      expect(output, contains('"version": "v0.9"'));
    },
  );

  test('leaves non-A2UI JSON unchanged', () async {
    const input = '{"status":"ok"}';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();

    expect(output, input);
  });

  test('does not overwrite an explicit version', () async {
    const input =
        '{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"test.catalog"}}';

    final output = await Stream<String>.value(
      input,
    ).transform(const A2uiStreamRepairer()).join();

    expect(output, input);
  });
}
