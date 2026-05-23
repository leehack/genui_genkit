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
