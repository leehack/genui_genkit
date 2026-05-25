import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

import 'activity_catalog.dart';

String activityGenUiSystemPromptBuilder(
  List<Catalog> catalogs,
  GenUiSystemPromptOptions options,
) {
  final catalog = catalogs
      .where((catalog) => catalog.catalogId == activityCatalog.catalogId)
      .firstOrNull;
  if (catalog == null) {
    return compactGenUiSystemPromptBuilder(catalogs, options);
  }

  final fragments = [
    'You generate compact Flutter GenUI for activity and trip planning.',
    'Answer with one short acknowledgement, then one fenced JSON A2UI array. Do not explain the JSON.',
    'Use only catalogId "${activityCatalog.catalogId}". Do not invent components.',
    'Use exactly this JSON shape, replacing only the user-facing strings:',
    '```json\n[{"version":"v0.9","createSurface":{"surfaceId":"plan_1","catalogId":"${activityCatalog.catalogId}","sendDataModel":true}},{"version":"v0.9","updateComponents":{"surfaceId":"plan_1","components":[{"id":"root","component":"Column","children":["plan","activity","checklist"]},{"id":"plan","component":"ItineraryPlan","title":"Title","summary":"Summary","budget":"Budget","stops":[{"time":"1:00 PM","title":"Stop","details":"Details"}]},{"id":"activity","component":"ActivityCard","title":"Activity","description":"Description","duration":"1 hour","costLevel":"low"},{"id":"checklist","component":"Checklist","title":"Prep","items":["Item one","Item two"]}]}}]\n```',
    'Every item in updateComponents.components must be an object with "id" and "component". Never output strings like "root" inside components.',
    'Component entries are flat objects. The "component" value is a string.',
    'The rendered entry point is the component with "id":"root". For multiple visible widgets, make root a Column with children as component id strings.',
    'Components: Column {"id":"root","component":"Column","children":["plan"]}; ItineraryPlan {"id":"plan","component":"ItineraryPlan","title":"...","summary":"...","budget":"...","stops":[{"time":"...","title":"...","details":"..."}]}; ActivityCard {"id":"activity","component":"ActivityCard","title":"...","description":"...","duration":"...","costLevel":"low"}; Checklist {"id":"checklist","component":"Checklist","title":"...","items":["..."]}; ChoicePicker {"id":"choice","component":"ChoicePicker","question":"...","options":["..."]}.',
    'For itinerary prompts, prefer root Column children ["plan","activity","checklist"] and define those ids separately.',
    'Keep strings concise and valid JSON. No comments, trailing commas, inline component objects, or markdown inside JSON.',
    ...options.systemPromptFragments,
    PromptFragments.acknowledgeUser(),
    PromptFragments.uiGenerationRestriction(
      prefix: PromptBuilder.defaultImportancePrefix,
    ),
  ];

  return fragments.map((fragment) => fragment.trim()).join('\n\n');
}
