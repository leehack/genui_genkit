import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hybrid_genui/src/activity_catalog.dart';
import 'package:flutter_hybrid_genui/src/app.dart';
import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_hybrid_genui/src/runtime/app_runtime.dart';
import 'package:flutter_hybrid_genui/src/widgets/raw_output_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit/genui_genkit.dart';

void main() {
  testWidgets('starts in hybrid mode with the default local route', (
    tester,
  ) async {
    final runtime = AppRuntime.fromEnvironment(const {'HOME': '/Users/test'});
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));

    expect(find.text('Active AI route'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Local model queued'), findsOneWidget);
    expect(find.text(defaultModelDisplayName), findsOneWidget);
    expect(find.text('Build day plan'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('route selector exposes Gemini configuration state', (
    tester,
  ) async {
    final runtime = AppRuntime.fromEnvironment(const {'HOME': '/Users/test'});
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();

    expect(runtime.selectedRoute.value, GenUiAiRoute.gemini);
    expect(find.text('Gemini key missing'), findsOneWidget);
  });

  testWidgets('mobile layout keeps AI config compact', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtime = AppRuntime.fromEnvironment(const {'HOME': '/Users/test'});
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));
    await tester.pumpAndSettle();

    expect(find.text('Active AI route'), findsNothing);
    expect(find.text('Local route'), findsOneWidget);
    expect(find.byTooltip('AI route'), findsOneWidget);
    expect(find.byTooltip('Route settings'), findsOneWidget);
    expect(find.text('Local model queued'), findsOneWidget);

    await tester.tap(find.byTooltip('AI route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini').last);
    await tester.pumpAndSettle();

    expect(runtime.selectedRoute.value, GenUiAiRoute.gemini);
    expect(find.text('Gemini route'), findsOneWidget);
    expect(find.text('API key missing'), findsOneWidget);
  });

  testWidgets('Gemini and backend settings can be edited in the UI', (
    tester,
  ) async {
    final runtime = AppRuntime.fromEnvironment(const {'HOME': '/Users/test'});
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Route settings'));
    await tester.pumpAndSettle();

    final geminiFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(geminiFields.at(0), 'gemini-test');
    await tester.enterText(geminiFields.at(1), 'test-key');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(runtime.geminiConfig.value.modelName, 'gemini-test');
    expect(runtime.geminiConfig.value.apiKey, 'test-key');

    await tester.tap(find.text('Backend'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Route settings'));
    await tester.pumpAndSettle();

    final backendFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(backendFields.first, 'http://localhost:9999/genui');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      runtime.backendConfig.value.endpoint,
      Uri.parse('http://localhost:9999/genui'),
    );
  });

  testWidgets('renders prompt buttons with an injected session', (
    tester,
  ) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => Stream.value('hello')),
      catalog: activityCatalog,
    );
    final runtime = AppRuntime.test(session: session);
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));

    expect(find.text('Build day plan'), findsOneWidget);
    expect(find.text('Compare options'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('renders A2UI sample output as a Flutter widget', (tester) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => _sampleActivityStream()),
      catalog: activityCatalog,
    );
    final runtime = AppRuntime.test(session: session);
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));
    await tester.tap(find.text('Build day plan'));
    await tester.pumpAndSettle();

    expect(find.text('Rainy afternoon in Montreal'), findsOneWidget);
    expect(find.text('Cozy cafe stop'), findsOneWidget);
    expect(find.text('Rainy day prep'), findsOneWidget);
    expect(find.text('Cost: low'), findsOneWidget);
  });

  testWidgets('assistant prose trims trailing blank lines in chat', (
    tester,
  ) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(
        generate: (_) => Stream.value('Acknowledgment\n\n\n'),
      ),
      catalog: activityCatalog,
    );
    final runtime = AppRuntime.test(session: session);
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));
    await tester.tap(find.text('Build day plan'));
    await tester.pumpAndSettle();

    expect(find.text('Acknowledgment'), findsOneWidget);
    expect(find.text('Acknowledgment\n\n\n'), findsNothing);
  });

  testWidgets('pressing enter sends the composed chat message', (tester) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => Stream.value('Ack')),
      catalog: activityCatalog,
    );
    final runtime = AppRuntime.test(session: session);
    addTearDown(runtime.dispose);

    await tester.pumpWidget(FlutterHybridGenUiApp(runtime: runtime));
    await tester.enterText(find.byType(TextField), 'Send with enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Send with enter'), findsOneWidget);
    expect(find.text('Ack'), findsOneWidget);
  });

  testWidgets('expanded raw output panel fits bounded inspector height', (
    tester,
  ) async {
    final rawText = List.filled(80, '{"chunk":"value"}').join('\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 240,
            child: RawOutputPanel(
              rawText: rawText,
              initiallyExpanded: true,
              maxHeight: 520,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Raw stream'), findsOneWidget);
  });
}

Stream<String> _sampleActivityStream() {
  return Stream<String>.fromIterable([
    'Rendered a local GenUI activity card.\n\n',
    '''```json
{
  "createSurface": {
    "surfaceId": "activity_test",
    "catalogId": "dev.leehack.genui.activity.v1"
  }
}
```
''',
    '''```json
{
  "updateComponents": {
    "surfaceId": "activity_test",
    "components": [
      {
        "id": "root",
        "component": {
          "component": "Column",
          "align": "stretch",
          "children": ["plan", "activity_card_1", "checklist_1"]
        }
      },
      {
        "id": "plan",
        "component": {
          "component": "ItineraryPlan",
          "title": "Rainy afternoon in Montreal",
          "summary": "A compact indoor route with one flexible cafe break.",
          "budget": "Under \$50 before transit",
          "stops": [
            {
              "time": "1:00 PM",
              "title": "Explore the Old Port",
              "details": "Walk under covered sections and keep the route short."
            },
            {
              "time": "3:00 PM",
              "title": "Warm up indoors",
              "details": "Pick a nearby library or small museum if the rain gets heavy."
            }
          ]
        }
      },
      {
        "id": "activity_card_1",
        "component": {
          "component": "ActivityCard",
          "title": "Cozy cafe stop",
          "description": "Find a local cafe near the route for a warm drink and people-watching.",
          "duration": "1 hour",
          "costLevel": "low"
        }
      },
      {
        "id": "checklist_1",
        "component": {
          "component": "Checklist",
          "title": "Rainy day prep",
          "items": [
            "Wear waterproof shoes",
            "Pack a warm sweater",
            "Check local transit schedules"
          ]
        }
      }
    ]
  }
}
```
''',
  ]);
}
