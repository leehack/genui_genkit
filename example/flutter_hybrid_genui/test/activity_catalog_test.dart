import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hybrid_genui/src/activity_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Reports = ({
  List<A2uiRendererAction> actions,
  List<A2uiRendererError> errors,
});

/// Renders [components] on a surface of the activity catalog, and returns the
/// actions and errors the surface reports.
Future<_Reports> _pumpSurface(
  WidgetTester tester,
  List<Map<String, Object?>> components,
) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [activityCatalog],
    validationConfig: ValidationConfig.strict,
  );
  addTearDown(processor.dispose);
  final reports = (
    actions: <A2uiRendererAction>[],
    errors: <A2uiRendererError>[],
  );
  processor.model.onAction.subscribe(reports.actions.add);
  processor.model.onError.subscribe(reports.errors.add);
  processor.processMessages([
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': 'plan', 'catalogId': activityCatalog.id},
    },
    {
      'version': 'v0.9',
      'updateComponents': {'surfaceId': 'plan', 'components': components},
    },
  ]);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: A2uiSurface(surface: processor.model.getSurface('plan')!),
        ),
      ),
    ),
  );
  return reports;
}

void main() {
  testWidgets('renders a Column of activity components', (tester) async {
    final reports = await _pumpSurface(tester, [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['plan', 'activity', 'checklist'],
      },
      {
        'id': 'plan',
        'component': 'ItineraryPlan',
        'title': 'Rainy afternoon',
        'summary': 'A compact indoor route.',
        'budget': 'About 40 dollars',
        'stops': [
          {'time': '1:00 PM', 'title': 'Museum', 'details': 'Start indoors.'},
        ],
      },
      {
        'id': 'activity',
        'component': 'ActivityCard',
        'title': 'Cafe stop',
        'description': 'A warm drink near the route.',
        'duration': '1 hour',
        'costLevel': 'low',
      },
      {
        'id': 'checklist',
        'component': 'Checklist',
        'title': 'Prep',
        'items': ['Umbrella'],
      },
    ]);

    expect(reports.errors, isEmpty);
    expect(find.text('Rainy afternoon'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('Cafe stop'), findsOneWidget);
    expect(find.text('Cost: low'), findsOneWidget);
    expect(find.text('Umbrella'), findsOneWidget);
  });

  testWidgets('ChoicePicker dispatches the selected choice', (tester) async {
    final reports = await _pumpSurface(tester, [
      {
        'id': 'root',
        'component': 'ChoicePicker',
        'question': 'Where next?',
        'options': ['Museum', 'Park'],
      },
    ]);

    await tester.tap(find.text('Park'));
    await tester.pump();

    expect(reports.errors, isEmpty);
    final action = reports.actions.single;
    expect(action.name, 'choiceSelected');
    expect(action.sourceComponentId, 'root');
    expect(action.context, {'choice': 'Park'});
  });

  testWidgets('accepts properties the schema does not list', (tester) async {
    final reports = await _pumpSurface(tester, [
      {
        'id': 'root',
        'component': 'ActivityCard',
        'title': 'Cafe stop',
        'description': 'A warm drink near the route.',
        'mood': 'cozy',
      },
    ]);

    expect(reports.errors, isEmpty);
    expect(find.text('Cafe stop'), findsOneWidget);
  });
}
