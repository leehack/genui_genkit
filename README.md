# genui_genkit

Build Flutter GenUI apps that can stream generated UI from any Genkit-backed
model: on-device llamadart, direct hosted providers, backend-hosted Genkit
flows, or a hybrid mix of all three.

> Experimental: Flutter `genui` is experimental and its APIs may change.

## What This Package Provides

Genkit is good at connecting to AI providers. Flutter GenUI is good at safely
rendering app-owned UI components from A2UI messages. This package connects those
two pieces so app developers can focus on catalog design, routing policy, and
product UX instead of transport glue.

- `GenkitGenUiSession` bridges chat turns, GenUI catalog prompts, streamed model
  text, A2UI parsing, and local surface rendering.
- `GenkitBackend` adapts any configured Genkit `ModelRef`.
- `RemoteGenkitFlowBackend` calls backend-hosted Genkit flows served through
  Genkit's remote action protocol, such as `genkit_shelf`.
- `RemoteGenUiBackend` remains available for custom HTTP/SSE protocols.
- `HybridGenUiBackend` routes each turn to a named local or remote backend.

```text
User prompt / UI action
        |
        v
GenkitGenUiSession
        |
        v
GenUiBackend interface
   |-----------|------------------|
   v           v                  v
llamadart   Gemini/OpenAI/etc   Genkit backend flow
   |           |                  |
   '-----------'------------------'
        |
        v
streamed text + A2UI JSON
        |
        v
Flutter GenUI catalog renderer
```

The model can only reference widgets that the app registered in its local
catalog. It cannot execute arbitrary Flutter code.

## Install

Add the core adapter and the Genkit/GenUI APIs your app will use:

```sh
flutter pub add genui_genkit genkit genui
```

Then add the Genkit provider plugin you want in the host app. For example:

```sh
flutter pub add genkit_llamadart
flutter pub add genkit_google_genai
```

`genui_genkit` stays provider-neutral. It does not import Gemini, OpenAI,
llamadart, or any other model provider plugin.

## Quick Start

This minimal example uses `LocalGenkitBackend` to show the session shape without
requiring a provider key or a downloaded model:

```dart
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

  for (final message in session.messages) {
    if (message.text case final text?) {
      print(text);
    }
  }

  session.dispose();
}
```

In a real app, replace `LocalGenkitBackend` with `GenkitBackend`,
`RemoteGenkitFlowBackend`, or `HybridGenUiBackend`.

## Execution Modes

| Mode | Use When | Main API |
| --- | --- | --- |
| Client mode | Flutter owns Genkit directly. Good for desktop apps, prototypes, and local/offline routes. | `GenkitBackend` |
| Backend mode | Model execution belongs on a server. Flutter consumes a Genkit flow over SSE. | `RemoteGenkitFlowBackend` |
| Hybrid mode | Each turn can choose local, direct hosted, or backend routes. | `HybridGenUiBackend` |

## Genkit Model Example

Client mode with any configured Genkit model:

```dart
final session = GenkitGenUiSession(
  backend: GenkitBackend(
    ai: ai,
    model: modelRef,
  ),
  catalog: appCatalog,
);
```

On-device llamadart with package-managed cache/download:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genui_genkit/genui_genkit.dart';

final prepared = await llamaDart.prepareModel(
  name: 'local-genui',
  source: ModelSource.parse(
    'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf',
  ),
);
final ai = Genkit(plugins: [prepared.plugin]);

final session = GenkitGenUiSession(
  backend: GenkitBackend<LlamaDartGenerationConfig>(
    ai: ai,
    model: prepared.modelRef,
    config: const LlamaDartGenerationConfig(maxTokens: 512),
  ),
  catalog: appCatalog,
);
```

Backend mode through a Genkit flow:

```dart
final session = GenkitGenUiSession(
  backend: RemoteGenkitFlowBackend(
    flowUrl: Uri.parse('https://api.example.com/genui'),
  ),
  catalog: appCatalog,
);
```

Hybrid routing:

```dart
final backend = HybridGenUiBackend(
  routes: {
    'local': localLlamaDartBackend,
    'gemini': directGeminiBackend,
    'backend': remoteGenkitFlowBackend,
  },
  policy: (request, routes) {
    return request.metadata['privacy'] == 'local' ? 'local' : 'backend';
  },
);
```

## Project Layout

- `lib/` - provider-neutral Flutter session and backend adapters for Genkit,
  remote Genkit flows, custom SSE backends, and hybrid routing.
- `example/` - minimal package example for pub.dev.
- `example/flutter_hybrid_genui` - product-like Flutter app with Local,
  Gemini, and Backend routes.
- `example/genui_backend_server` - backend-mode Genkit server example.

## Examples

- `example/flutter_hybrid_genui` - Flutter desktop workbench with Local,
  Gemini, and Backend routes configurable from the UI.
- `example/genui_backend_server` - Dart Genkit backend using `genkit_shelf`
  and Gemma through llamadart.

Run the Flutter example:

```sh
cd example/flutter_hybrid_genui
flutter pub get
flutter run -d macos
```

Run the backend example:

```sh
cd example/genui_backend_server
dart run bin/server.dart
```

Then point the Flutter app at it:

```sh
cd ../flutter_hybrid_genui
GENUI_AI_ROUTE=backend \
GENUI_BACKEND_URL=http://localhost:8080/genui \
flutter run -d macos
```

## Documentation

- [Architecture](doc/architecture.md)
- [Architecture decisions](doc/decisions/0001-llamadart-integration-boundary.md)
- [Contributing](CONTRIBUTING.md)

## Verify

Run checks for the package and each example you touched:

```sh
flutter analyze && flutter test
cd example/flutter_hybrid_genui && flutter analyze && flutter test
cd example/genui_backend_server && dart analyze && dart test
```
