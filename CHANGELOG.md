# Changelog

## Unreleased

- Breaking: move from `genui` to the A2UI Dart SDKs that replace it,
  `a2ui_core`, `a2ui_flutter` and `a2ui_agent`. Sessions still speak A2UI
  v0.9.
  - `GenkitGenUiSession` takes `a2ui_flutter` `CatalogImplementation`s instead
    of genui `Catalog`s, and `catalogs` returns them.
  - `GenkitGenUiSession.processor`, an `a2ui_core` `MessageProcessor`,
    replaces `surfaceController`.
  - `GenUiSystemPromptBuilder` receives `CatalogImplementation`s, and
    `GenUiSystemPromptOptions.clientDataModel` is a `Map<String, Object?>`.
  - `SurfaceOperations` and `TechnicalPossibilities` are now part of this
    package, with the same constructors and fields.
  - `ChatMessage` and `ChatMessageRole`, used by `GenUiTurnRequest` and the
    Genkit message helpers, come from `genai_primitives`, which `genui`
    re-exported. Remote backends receive the same JSON as before.
  - `defaultGenUiSystemPromptBuilder` and `compactGenUiSystemPromptBuilder`
    take the A2UI output rules and schemas from `a2ui_agent`, which ask the
    model for JSON arrays in `<a2ui-json>` blocks instead of markdown-fenced
    JSON. Sessions read both forms and repair them as before.
  - Each A2UI message is checked against the catalog before it is applied,
    and a message that fails is rejected and reported to the backend. `genui`
    applied invalid components before reporting them, accepted unknown
    catalog ids, and held an `updateDataModel` for a surface that did not
    exist yet until the surface was created.
  - `GenUiMessageView` renders surfaces with `A2uiSurface` and still renders
    Markdown in Text components.
- Update the hybrid example to `a2ui_flutter`. Its components accept
  properties their schemas do not list, as genui's `CatalogItem` did.
- Select package and example CI checks by their dependencies while retaining
  package publication checks and full validation for shared or unknown inputs.
- Keep analyzer configuration stable during current Flutter dependency setup and
  await benchmark inference before disposing its download controller.

## 0.2.0 - 2026-07-28

- Added guarded release-preparation automation that tags the exact merged
  commit, publishes it to pub.dev, and creates the matching GitHub Release.
- Added compatibility with Genkit 0.15, GenUI 0.10, and the extracted
  `a2ui_core` message types.
- Upgraded the hybrid and backend examples to `genkit_llamadart` 1.4.0 and the
  current compatible Genkit, provider, server, llamadart, and GenUI packages.
- Raised the hybrid example's macOS deployment target to 14.0, adopted
  Flutter's Swift Package Manager integration, and made its macOS integration
  smoke run automatically for relevant pull requests and pushes to `main`.
- Moved the opt-in LiteRT-LM device smoke and GenUI benchmark out of
  `integration_test` so default integration runs do not launch their
  heavyweight targets.

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
