# Agent Workflow

This repository builds a Flutter GenUI library on top of Genkit. Treat the
primary product goal as:

- Make it easy for Flutter developers to build GenUI apps with Genkit.
- Support on-device generation through `llamadart`.
- Support remote providers through normal Genkit provider plugins.
- Support hybrid apps that can choose local, direct remote, or backend-hosted
  Genkit per turn.

## Architecture Rules

- Prefer SOLID and KISS together: keep responsibilities clear, depend on the
  `GenUiBackend` abstraction, and avoid abstractions that do not remove real
  complexity.
- Keep `packages/genui_genkit` provider-neutral. Do not import Gemini, OpenAI,
  llamadart, or other provider plugins into the core package.
- Use `GenUiBackend` as the backend boundary. New execution paths should adapt
  to that interface instead of leaking provider details into widgets or session
  code.
- Use `GenkitBackend` for client-mode Genkit execution after the host app has
  registered its provider and selected a `ModelRef`.
- Use `RemoteGenkitFlowBackend` for backend-mode Genkit flows served by
  Genkit's official server integration, such as `genkit_shelf`.
- Keep `RemoteGenUiBackend` as an escape hatch for custom HTTP/SSE protocols
  that are not normal Genkit remote actions.
- Use `HybridGenUiBackend` for per-turn routing. Route policy can inspect the
  prompt, metadata, privacy mode, network state, feature flags, or UI-selected
  route.
- Keep `packages/genui_genkit_llamadart` optional. It may depend on
  `llamadart` and `genkit_llamadart`; the core package should not.
- For llamadart models, use llamadart's package-managed download/cache APIs.
  Do not require users to pass a local model path for the normal example flow.
- Flutter renders only local GenUI catalog widgets. Streamed A2UI can reference
  known components, but must never execute arbitrary Flutter code.
- Prefer small, single-purpose classes: configuration parsing, backend
  execution, routing, runtime state, and widgets should stay separated.
- Remove unused demos, fake production paths, and stale config fields during
  cleanup passes.

## Examples

`examples/flutter_hybrid_genui` is a useful reference app, not a throwaway demo.
Keep it able to run in three routes:

- Local: on-device llamadart through `genui_genkit_llamadart`.
- Gemini: direct Genkit provider execution in the Flutter process.
- Backend: remote Genkit flow through `RemoteGenkitFlowBackend`.

For this app:

- Keep local model defaults useful and configurable from environment variables.
- Keep Gemini model, API key, temperature, max tokens, and backend URL
  configurable from the UI as well as environment variables.
- When a user asks for the "latest" provider default, verify current official
  provider docs before changing model IDs.
- Keep the route selector obvious, and make route errors actionable.
- Keep chat and rendered GenUI space generous. Raw stream/debug output should
  be secondary, collapsible, and readable.
- Enter should send chat messages; multiline input should still be possible by
  an explicit UI affordance or platform convention.
- Avoid placeholder or missing icons in the visible UI.
- Prefer deterministic fake backends only for tests and smoke fixtures, not as
  the main example runtime.

`examples/genui_backend_server` demonstrates backend mode:

- Serve Genkit flows through `genkit_shelf`.
- Use Gemma through llamadart by default.
- Resolve the model through llamadart's download/cache manager.
- Keep the flow contract compatible with the Flutter hybrid app's Backend
  route.

Do not recreate a separate `genui_genkit_server` package unless there is a
clear feature gap that Genkit's official server integration cannot cover.

## Dependency Rules

- Use hosted package dependencies for packages that are not part of this repo.
- If local dependency development is needed, use an uncommitted
  `pubspec_overrides.yaml` instead of committing path dependencies.
- Keep public API docs, package READMEs, example READMEs, and
  `docs/architecture.md` in sync with behavior changes.
- Keep package READMEs pub.dev-friendly: start with the value proposition, add
  a visual explanation when useful, and include a copyable minimal example.

## Lint Rules

- Use the root `analysis_options.yaml` strict analyzer settings and additional
  stable lints as the repo baseline.
- Treat discarded futures, raw generics, owned stream/subscription cleanup, and
  stale async state as real maintenance issues.
- Add lint suppressions only with a local explanation and only when an upstream
  API forces the shape.

## Testing Workflow

There is no root Dart workspace command. Run checks inside the package or
example you changed.

Core package:

```sh
cd packages/genui_genkit
flutter analyze
flutter test
```

Llamadart integration:

```sh
cd packages/genui_genkit_llamadart
flutter analyze
flutter test
```

Flutter hybrid example:

```sh
cd examples/flutter_hybrid_genui
flutter analyze
flutter test
flutter test integration_test -d macos
```

Backend server example:

```sh
cd examples/genui_backend_server
dart analyze
dart test
dart run bin/server.dart
```

When testing the backend server manually, report the bound URL and stop the
server before finishing unless the user asks to leave it running.

## Review Checklist

Before finishing a change, check:

- Does the core package remain provider-neutral?
- Does local generation still use llamadart's cache/download manager?
- Can the Flutter example still switch Local, Gemini, and Backend routes?
- Are model names, API keys, backend URLs, and local model sources configurable?
- Does generated UI render through the catalog instead of appearing only as raw
  stream text?
- Are parser and validation failures visible but not allowed to destroy the
  main chat/rendering layout?
- Did relevant unit, widget, and integration tests run?
- Did docs change when public behavior changed?
