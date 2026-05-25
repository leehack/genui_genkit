import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

void main() {
  testWidgets('GenUiMessageList renders session chat entries', (tester) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => Stream.value('ack')),
      catalog: const Catalog([], catalogId: 'test.catalog'),
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
