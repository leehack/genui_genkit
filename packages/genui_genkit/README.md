# genui_genkit

Build Flutter GenUI sessions backed by Genkit models, remote Genkit flows, or
hybrid local/remote routing.

`genui_genkit` keeps provider setup outside the package. Register Gemini,
OpenAI, llamadart, or another Genkit provider in your app, then pass the
configured Genkit model into the same GenUI session pipeline.

```text
Flutter app
  |
  v
GenkitGenUiSession
  |
  +-- GenkitBackend ------------> Genkit model in Flutter
  +-- RemoteGenkitFlowBackend --> Genkit flow on a server
  +-- HybridGenUiBackend -------> route per turn
```

## What It Provides

- `GenkitGenUiSession` - owns chat history, A2UI parsing, surface lifecycle,
  raw text, errors, cancellation, and per-turn metadata.
- `GenkitBackend` - adapts any configured Dart Genkit model to GenUI text/A2UI
  streams.
- `RemoteGenkitFlowBackend` - consumes a Genkit flow served by `genkit_shelf`
  or a compatible Genkit server.
- `RemoteGenUiBackend` - consumes a custom HTTP/SSE backend when you are not
  using Genkit's remote action protocol.
- `HybridGenUiBackend` - routes each turn across local, remote, or custom
  backends.
- Lightweight widgets - message list, message view, prompt composer, and
  thinking indicator.

## Client Mode

```dart
final session = GenkitGenUiSession(
  backend: GenkitBackend(
    ai: ai,
    model: modelRef,
    options: const GenkitGenerateOptions(maxTurns: 4),
  ),
  catalog: appCatalog,
);
```

The host app owns provider setup. For Gemini, OpenAI, llamadart, or another
provider, register the plugin with Genkit first and pass the resulting
`ModelRef` to `GenkitBackend`.

## Backend Mode

Use `RemoteGenkitFlowBackend` when Flutter should call a backend-hosted Genkit
flow:

```dart
final backend = RemoteGenkitFlowBackend(
  flowUrl: Uri.parse('https://api.example.com/genui'),
);
```

The request body is a serialized `GenUiTurnRequest`. The flow stream chunks are
treated as model text that can contain A2UI JSON blocks.

## Hybrid Mode

Use `HybridGenUiBackend` when the app should choose a route per turn:

```dart
final backend = HybridGenUiBackend(
  routes: {
    'local': localBackend,
    'remote': remoteBackend,
  },
  policy: (request, routes) {
    return request.metadata['privacy'] == 'local' ? 'local' : 'remote';
  },
);
```

Per-turn metadata can be static or dynamic:

```dart
final session = GenkitGenUiSession(
  backend: backend,
  catalog: appCatalog,
  metadata: const {'app': 'my_app'},
  metadataBuilder: () => {'route': selectedRoute.value},
);
```

## Safety Boundary

Flutter renders only local catalog widgets. Remote or local models can reference
known catalog component names and data, but they cannot execute arbitrary
Flutter code.

## More Examples

See:

- `example/main.dart` for a minimal session.
- `../../examples/flutter_hybrid_genui` for Local, Gemini, and Backend routes.
- `../../examples/genui_backend_server` for a backend Genkit flow.
