# Changelog

## 0.1.0-dev

- Initial experimental workspace for GenUI + Genkit integration.
- Added Flutter session/client package with Genkit, remote Genkit flow, custom SSE, and hybrid backends.
- Added on-device llamadart examples using llamadart's model download/cache manager through `genkit_llamadart`.
- Added a backend-mode example server using Genkit's official `genkit_shelf` integration.
- Added a hybrid macOS Flutter example with configurable local llamadart, direct Gemini, and backend Genkit routes.
- Added per-turn metadata builders for dynamic hybrid route configuration.
- Promoted `genui_genkit` to a single root package layout.
- Tightened analysis options and added contributor/pub.dev readiness docs plus package examples.
