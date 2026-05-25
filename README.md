# genui_genkit

Build Flutter GenUI apps that can stream generated UI from any Genkit-backed
model: on-device llamadart, direct hosted providers, backend-hosted Genkit
flows, or a hybrid mix of all three.

> Experimental: Flutter `genui` is experimental and its APIs may change.

## Why This Exists

Genkit is good at connecting to AI providers. Flutter GenUI is good at safely
rendering app-owned UI components from A2UI messages. This repo connects those
two pieces so app developers can focus on catalog design, routing policy, and
product UX instead of transport glue.

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

## Packages

- `packages/genui_genkit` - Flutter session and backend adapters for Genkit,
  remote Genkit flows, custom SSE backends, and hybrid routing.
- `packages/genui_genkit_llamadart` - optional on-device helper that resolves
  GGUF model sources through llamadart's download/cache manager, then registers
  the cached model with `genkit_llamadart`.

## Execution Modes

| Mode | Use When | Main API |
| --- | --- | --- |
| Client mode | Flutter owns Genkit directly. Good for desktop apps, prototypes, and local/offline routes. | `GenkitBackend` |
| Backend mode | Model execution belongs on a server. Flutter consumes a Genkit flow over SSE. | `RemoteGenkitFlowBackend` |
| Hybrid mode | Each turn can choose local, direct hosted, or backend routes. | `HybridGenUiBackend` |

## Minimal Examples

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
import 'package:genui_genkit_llamadart/genui_genkit_llamadart.dart';
import 'package:llamadart/llamadart.dart' as llama;

final backend = LlamaDartGenUiBackend(
  LlamaDartGenUiConfig(
    modelSource: llama.ModelSource.parse(
      'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf',
    ),
  ),
);

await backend.prepare();
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

## Examples

- `examples/flutter_hybrid_genui` - Flutter desktop workbench with Local,
  Gemini, and Backend routes configurable from the UI.
- `examples/genui_backend_server` - Dart Genkit backend using `genkit_shelf`
  and Gemma through llamadart.

Run the Flutter example:

```sh
cd examples/flutter_hybrid_genui
flutter pub get
flutter run -d macos
```

Run the backend example:

```sh
cd examples/genui_backend_server
dart run bin/server.dart
```

Then point the Flutter app at it:

```sh
GENUI_AI_ROUTE=backend \
GENUI_BACKEND_URL=http://localhost:8080/genui \
flutter run -d macos
```

## Documentation

- [Architecture](docs/architecture.md)
- [Architecture decisions](docs/decisions/0001-llamadart-integration-boundary.md)
- [Contributing](CONTRIBUTING.md)
- [Core package README](packages/genui_genkit/README.md)
- [llamadart package README](packages/genui_genkit_llamadart/README.md)

## Verify

Run checks inside each package or example you touched:

```sh
cd packages/genui_genkit && flutter analyze && flutter test
cd packages/genui_genkit_llamadart && flutter analyze && flutter test
cd examples/flutter_hybrid_genui && flutter analyze && flutter test
cd examples/genui_backend_server && dart analyze && dart test
```
