import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

Future<void> main() async {
  final session = GenkitGenUiSession(
    backend: LocalGenkitBackend(
      generate: (request) => Stream.value('Hello ${request.message.text}'),
    ),
    catalog: const Catalog([], catalogId: 'dev.example.app.v1'),
  );

  await session.sendText('GenUI');

  assert(session.messages.length == 2);
  session.dispose();
}
