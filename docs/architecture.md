# Architecture

`genui_genkit` separates model execution from Flutter rendering. Genkit
providers produce text and A2UI JSON; Flutter GenUI renders only app-owned
catalog widgets.

## Overview

```text
User prompt or GenUI submit event
        |
        v
GenkitGenUiSession
  - chat history
  - system prompt assembly
  - raw stream capture
  - A2UI parsing and repair
  - surface lifecycle
        |
        v
GenUiBackend
  |--------------------|------------------------|-------------------|
  v                    v                        v
GenkitBackend      RemoteGenkitFlowBackend   HybridGenUiBackend
  |                    |                        |
  v                    v                        v
Genkit model in     Genkit flow served        route to any named
Flutter process     by genkit_shelf           backend per turn
```

## Request Lifecycle

1. The app calls `GenkitGenUiSession.sendText` or a rendered GenUI component
   submits an interaction.
2. The session builds a `GenUiTurnRequest` containing the message, history,
   catalog ID, system prompt, and metadata.
3. A `GenUiBackend` streams `GenUiTextChunk` events.
4. The session forwards raw chunks to debug listeners and to GenUI's A2UI
   parser.
5. Plain assistant text becomes chat messages.
6. A2UI messages update the local `SurfaceController`.
7. Flutter renders the referenced surface using the local catalog.

```text
text chunk: "Here is a plan..."
        -> assistant chat text

text chunk: {"version":"v0.9","createSurface":...}
        -> A2UI parser
        -> SurfaceController
        -> registered Flutter widget
```

## Modes

**Client mode** keeps Genkit in the Flutter process. This is useful for local
desktop apps, quick prototypes, and on-device models. The host app registers
the provider plugin and passes a `ModelRef` to `GenkitBackend`.

**Backend mode** keeps model execution on a server. Flutter uses
`RemoteGenkitFlowBackend`, while the server exposes a normal Genkit flow with
`genkit_shelf`. The client sends the current turn and history as flow input and
consumes the streaming Genkit response.

**Hybrid mode** composes any mix of local and remote backends with
`HybridGenUiBackend`. A route policy can inspect the prompt, metadata, privacy
settings, network state, or user-selected route and return the backend key for
that turn.

## Package Boundaries

- `packages/genui_genkit` owns the Flutter session, backend interfaces,
  provider-neutral Genkit adapter, remote flow adapter, hybrid router, and
  lightweight widgets.
- `packages/genui_genkit_llamadart` owns on-device model resolution and
  `genkit_llamadart` registration. It depends on native model packages so the
  core package does not have to.
- `examples/flutter_hybrid_genui` demonstrates a product-like client app with
  Local, Gemini, and Backend routes.
- `examples/genui_backend_server` demonstrates backend mode with
  `genkit_shelf` and Gemma through llamadart.

## Safety Boundary

The renderer never executes streamed Flutter code. A model can only reference
widgets already registered in the local GenUI catalog. This matters in backend
and hosted-provider modes: remote AI providers generate A2UI protocol messages,
while Flutter remains responsible for rendering known components and handling
user interactions.

## Design Principles

- Keep provider setup outside the core package.
- Prefer composition through `GenUiBackend` over provider-specific branches.
- Keep dynamic runtime settings in config objects and per-turn metadata.
- Keep example fake backends in tests, not in production paths.
- Prefer small adapters over broad inheritance hierarchies.
- Use llamadart's download/cache manager for remote model sources.

## When To Add New Surface Area

Add a new public API only when it removes real integration work for app
developers. If a feature is specific to one provider, put it in a provider
package or example route instead of the core package.

For backend serving, use Genkit's official server integration first. A separate
server package is justified only if Genkit's server APIs cannot express the
needed protocol.
