# Contributing

This repo is experimental, but changes should still be small, testable, and
easy to reason about.

## Development Principles

- **SOLID where it helps**: keep responsibilities clear, depend on interfaces
  such as `GenUiBackend`, and extend behavior through composition.
- **KISS by default**: prefer small adapters and explicit data objects over
  framework-heavy abstractions.
- Keep `packages/genui_genkit` provider-neutral.
- Keep llamadart-specific setup in `packages/genui_genkit_llamadart` or an
  example route.
- Use Genkit's official server integrations, such as `genkit_shelf`, before
  adding custom server infrastructure.
- Remove dead demos, fake runtime paths, and unused config fields when they no
  longer explain or test real behavior.

## Documentation Expectations

When public behavior changes, update the relevant docs in the same change:

- root `README.md` for the overall project story
- package READMEs for pub.dev-facing usage
- `docs/architecture.md` for architecture or mode changes
- example READMEs for runnable commands and environment variables
- `AGENTS.md` for durable agent workflow rules

Package READMEs should start with a short value proposition, show a visual or
diagram when it helps, and include copyable Dart snippets.

## Lint Policy

The repo uses `package:lints/recommended.yaml`, strict analyzer language
options, and a focused set of additional stable lints in the root
`analysis_options.yaml`.

The goal is not maximum lint count. The goal is maintainable code with:

- explicit generic types where they affect API safety
- no discarded futures unless intentionally wrapped with `unawaited`
- owned subscriptions and stream controllers closed or cancelled
- small functions with clear return types
- no committed path dependencies for packages outside this repo

Use `pubspec_overrides.yaml` for local dependency development and keep it
uncommitted.

## Test Matrix

Run checks inside each package or example you changed.

```sh
cd packages/genui_genkit
flutter analyze
flutter test
```

```sh
cd packages/genui_genkit_llamadart
flutter analyze
flutter test
```

```sh
cd examples/flutter_hybrid_genui
flutter analyze
flutter test
flutter test integration_test -d macos
```

```sh
cd examples/genui_backend_server
dart analyze
dart test
dart run bin/server.dart
```

For backend server manual tests, report the bound URL and stop the server when
finished unless the user explicitly asks to leave it running.

## Pub.dev Readiness

Before publishing a package:

- remove `publish_to: none`
- verify `LICENSE`, `README.md`, `CHANGELOG.md`, and `example/`
- run analysis and tests from the package directory
- check that the README explains scope and limitations
- confirm public APIs have enough Dart doc comments for generated docs
- avoid URLs or badges that cannot be rendered from pub.dev
