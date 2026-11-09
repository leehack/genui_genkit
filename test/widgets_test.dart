import 'dart:convert';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart' as v0_9;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_primitives/genai_primitives.dart';
import 'package:genui_genkit/genui_genkit.dart';

void main() {
  testWidgets('GenUiMessageList renders session chat entries', (tester) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => Stream.value('ack')),
      catalog: CatalogImplementation(id: 'test.catalog', components: const []),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenUiMessageList(session: session)),
      ),
    );
    await session.sendText('hello');
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('ack'), findsOneWidget);

    session.dispose();
  });

  testWidgets('GenUiMessageList sends surface actions to the backend', (
    tester,
  ) async {
    final catalog = v0_9.basicCatalog();
    final requests = <GenUiTurnRequest>[];
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (request) {
          requests.add(request);
          if (requests.length > 1) return Stream.value('Thanks!');
          return Stream<String>.value('''
```json
[
  {"version": "v0.9", "createSurface": {"surfaceId": "s1", "catalogId": "${catalog.id}"}},
  {"version": "v0.9", "updateComponents": {"surfaceId": "s1", "components": [
    {"id": "root", "component": "Button", "child": "label", "action": {"event": {"name": "submit"}}},
    {"id": "label", "component": "Text", "text": "Submit"}
  ]}}
]
```''');
        },
      ),
      catalog: catalog,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenUiMessageList(session: session)),
      ),
    );
    await session.sendText('go');
    await tester.pump();
    expect(find.byType(MarkdownBody), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    final part = requests.last.message.parts.whereType<DataPart>().single;
    expect(part.mimeType, 'application/vnd.genui.interaction+json');
    final envelope =
        jsonDecode(utf8.decode(part.bytes)) as Map<String, Object?>;
    final interaction =
        jsonDecode(envelope['interaction']! as String) as Map<String, Object?>;
    expect(interaction['version'], 'v0.9');
    expect(
      interaction['action'],
      allOf(
        containsPair('name', 'submit'),
        containsPair('surfaceId', 's1'),
        containsPair('sourceComponentId', 'root'),
      ),
    );
    expect(find.text('Thanks!'), findsOneWidget);

    session.dispose();
  });

  testWidgets('GenUiPromptComposer submits trimmed text', (tester) async {
    final submissions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenUiPromptComposer(onSubmit: submissions.add)),
      ),
    );

    await tester.enterText(find.byType(TextField), '  build UI  ');
    await tester.tap(find.byTooltip('Send'));

    expect(submissions, ['build UI']);
    expect(find.text('build UI'), findsNothing);
  });
}
