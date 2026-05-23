import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final Catalog activityCatalog = Catalog(
  [
    BasicCatalogItems.column,
    itineraryPlanItem,
    activityCardItem,
    choicePickerItem,
    checklistItem,
  ],
  catalogId: 'dev.leehack.genui.activity.v1',
  systemPromptFragments: const [
    'Use this catalog for compact activity and trip-planning interfaces.',
    'Prefer ItineraryPlan for multi-stop plans, ActivityCard for a single recommendation, Checklist for preparation steps, and ChoicePicker when you need user input.',
    'For planning requests, render at least one catalog component instead of returning prose only.',
    'When showing multiple visible components, make the root component a Column with children that reference the child component ids, then define each child as a flat component entry.',
    'For example, a plan with an activity card and checklist should use root Column children ["plan", "activity_card", "checklist"], with those three child ids defined separately.',
    'Column children must be component id strings, not inline component objects.',
  ],
);

final CatalogItem itineraryPlanItem = CatalogItem(
  name: 'ItineraryPlan',
  dataSchema: S.object(
    description: 'A practical itinerary with stops, timing, and budget notes.',
    properties: {
      'title': S.string(description: 'Short itinerary title.'),
      'summary': S.string(description: 'One sentence overview.'),
      'budget': S.string(description: 'Budget estimate or constraint.'),
      'stops': S.list(
        description: 'Ordered stops in the itinerary.',
        minItems: 1,
        items: S.object(
          properties: {
            'time': S.string(description: 'Time or sequence label.'),
            'title': S.string(description: 'Stop title.'),
            'details': S.string(description: 'Why this stop is useful.'),
          },
          required: ['title', 'details'],
        ),
      ),
    },
    required: ['title', 'summary', 'stops'],
  ),
  exampleData: [
    () => '''
[
  {
    "id": "root",
    "component": "ItineraryPlan",
    "title": "Rainy afternoon under \$50",
    "summary": "A compact indoor route with warm food and a flexible finish.",
    "budget": "About \$38 before transit",
    "stops": [
      {
        "time": "1:00 PM",
        "title": "Small museum stop",
        "details": "Start with a focused exhibit so the day has a clear anchor."
      },
      {
        "time": "2:45 PM",
        "title": "Coffee and pastry",
        "details": "Use the break to compare the next two nearby options."
      }
    ]
  }
]
''',
  ],
  widgetBuilder: (context) {
    final data = context.data as Map<String, Object?>;
    final title = data['title'] as String? ?? 'Itinerary';
    final summary = data['summary'] as String? ?? '';
    final budget = data['budget'] as String?;
    final stops = (data['stops'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .toList();

    return _CatalogSurface(
      accent: const Color(0xFF1F7A68),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route_outlined, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context.buildContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[const SizedBox(height: 8), Text(summary)],
          if (budget != null && budget.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CatalogChip(icon: Icons.payments_outlined, label: budget),
          ],
          const SizedBox(height: 14),
          for (final indexed in stops.indexed)
            _TimelineStop(index: indexed.$1, data: indexed.$2),
        ],
      ),
    );
  },
);

final CatalogItem activityCardItem = CatalogItem(
  name: 'ActivityCard',
  dataSchema: S.object(
    description: 'A card describing one suggested activity.',
    properties: {
      'title': S.string(description: 'Short activity title.'),
      'description': S.string(description: 'One or two sentence description.'),
      'duration': S.string(description: 'Estimated duration, such as 2 hours.'),
      'costLevel': S.string(
        description: 'Approximate cost level.',
        enumValues: ['free', 'low', 'medium', 'high'],
      ),
    },
    required: ['title', 'description'],
  ),
  exampleData: [
    () => '''
[
  {
    "id": "root",
    "component": "ActivityCard",
    "title": "Rainy afternoon museum stop",
    "description": "Visit a compact museum, then warm up at a nearby cafe.",
    "duration": "2-3 hours",
    "costLevel": "medium"
  }
]
''',
  ],
  widgetBuilder: (context) {
    final data = context.data as Map<String, Object?>;
    final title = data['title'] as String? ?? 'Untitled activity';
    final description = data['description'] as String? ?? '';
    final duration = data['duration'] as String?;
    final costLevel = data['costLevel'] as String?;

    return _CatalogSurface(
      accent: _costColor(costLevel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context.buildContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(description),
          if (duration != null || costLevel != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (duration != null)
                  _CatalogChip(icon: Icons.schedule, label: duration),
                if (costLevel != null)
                  _CatalogChip(
                    icon: Icons.payments_outlined,
                    label: 'Cost: $costLevel',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  },
);

final CatalogItem choicePickerItem = CatalogItem(
  name: 'ChoicePicker',
  dataSchema: S.object(
    description: 'A small set of choices for the user.',
    properties: {
      'question': S.string(description: 'Question to ask the user.'),
      'options': S.list(
        description: 'Short options the user can select.',
        items: S.string(),
        minItems: 1,
      ),
    },
    required: ['question', 'options'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, Object?>;
    final question = data['question'] as String? ?? 'Choose an option';
    final options = (data['options'] as List<Object?>? ?? const [])
        .map((value) => value.toString())
        .toList();

    return _CatalogSurface(
      accent: const Color(0xFFC45A2B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question,
            style: Theme.of(
              context.buildContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                OutlinedButton(
                  onPressed: () => context.dispatchEvent(
                    UserActionEvent(
                      name: 'choiceSelected',
                      sourceComponentId: context.id,
                      context: {'choice': option},
                    ),
                  ),
                  child: Text(option),
                ),
            ],
          ),
        ],
      ),
    );
  },
);

final CatalogItem checklistItem = CatalogItem(
  name: 'Checklist',
  dataSchema: S.object(
    description: 'A checklist of preparation steps.',
    properties: {
      'title': S.string(description: 'Checklist title.'),
      'items': S.list(
        description: 'Checklist item labels.',
        items: S.string(),
        minItems: 1,
      ),
    },
    required: ['title', 'items'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, Object?>;
    final title = data['title'] as String? ?? 'Checklist';
    final items = (data['items'] as List<Object?>? ?? const [])
        .map((value) => value.toString())
        .toList();

    return _CatalogSurface(
      accent: const Color(0xFF18334A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context.buildContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  },
);

class _CatalogSurface extends StatelessWidget {
  const _CatalogSurface({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogChip extends StatelessWidget {
  const _CatalogChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.index, required this.data});

  final int index;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final time = data['time'] as String?;
    final title = data['title'] as String? ?? 'Stop ${index + 1}';
    final details = data['details'] as String? ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (details.isNotEmpty)
                Container(
                  width: 1,
                  height: 34,
                  color: colorScheme.outlineVariant,
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (time != null && time.isNotEmpty)
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.tertiary,
                    ),
                  ),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (details.isNotEmpty) Text(details),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _costColor(String? costLevel) {
  return switch (costLevel) {
    'free' || 'low' => const Color(0xFF1F7A68),
    'high' => const Color(0xFFC45A2B),
    _ => const Color(0xFF18334A),
  };
}
