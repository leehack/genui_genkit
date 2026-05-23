import 'package:flutter_hybrid_genui/src/activity_catalog.dart';
import 'package:flutter_hybrid_genui/src/app.dart';
import 'package:flutter_hybrid_genui/src/runtime/app_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders inline child components from the prompt flow', (
    tester,
  ) async {
    final session = GenkitGenUiSession(
      backend: LocalGenkitBackend(generate: (_) => _inlineChildrenStream()),
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
}

Stream<String> _inlineChildrenStream() {
  return Stream<String>.fromIterable([
    'Acknowledgment: building a local GenUI surface.\n\n',
    '''```json
{
  "createSurface": {
    "surfaceId": "activity_e2e",
    "catalogId": "dev.leehack.genui.activity.v1"
  }
}
```
''',
    '''```json
{
  "updateComponents": {
    "surfaceId": "activity_e2e",
    "components": [
      {
        "id": "root",
        "component": "Column",
        "align": "stretch",
        "children": [
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
                }
              ]
            }
          },
          {
            "id": "activity_card_1",
            "component": {
              "component": "ActivityCard",
              "title": "Cozy cafe stop",
              "description": "Find a local cafe near the route for a warm drink.",
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
                "Check local transit schedules"
              ]
            }
          }
        ]
      }
    ]
  }
}
```
''',
  ]);
}
