import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:genui_genkit/genui_genkit.dart';

Future<void> main() async {
  final session = GenkitGenUiSession(
    backend: LocalGenkitBackend(
      generate: (request) => Stream.value('Hello ${request.message.text}'),
    ),
    catalog: CatalogImplementation(
      id: 'dev.example.app.v1',
      components: const [],
    ),
  );

  await session.sendText('GenUI');

  assert(session.messages.length == 2);
  session.dispose();
}
