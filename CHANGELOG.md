# Changelog

## 0.1.1 - 2026-06-07

- Added GitHub Actions CI and tag-driven pub.dev release workflow automation.
- Added a manual macOS integration smoke workflow for the hybrid Flutter
  example.
- Documented Android Gemma 4 LiteRT-LM validation for the hybrid Flutter
  example and updated its local `genkit_llamadart`/`llamadart` dependency
  floors.
- Removed misleading llama.cpp-only load knobs from LiteRT-LM model params,
  loading status, and per-turn performance telemetry.
- Widened the provider-neutral adapter constraints to allow Genkit 0.14 and
  Schemantic 0.2 while the local-model examples remain on the
  `genkit_llamadart`-compatible Genkit 0.13 line.

## 0.1.0

- Initial experimental workspace for GenUI + Genkit integration.
- Added Flutter session/client package with Genkit, remote Genkit flow, custom SSE, and hybrid backends.
- Added on-device llamadart examples using llamadart's model download/cache manager through `genkit_llamadart`.
- Added a backend-mode example server using Genkit's official `genkit_shelf` integration.
- Added a hybrid macOS Flutter example with configurable local llamadart, direct Gemini, and backend Genkit routes.
- Added per-turn metadata builders for dynamic hybrid route configuration.
- Promoted `genui_genkit` to a single root package layout.
- Tightened analysis options and added contributor/pub.dev readiness docs plus package examples.
