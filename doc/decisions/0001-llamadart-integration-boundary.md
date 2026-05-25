# ADR 0001: Keep Llamadart Model Lifecycle APIs In genkit_llamadart

## Status

Accepted. Implemented against `genkit_llamadart` prepared-model APIs.

## Context

`genui_genkit` is intended to be the provider-neutral Flutter GenUI runtime for
Genkit-backed apps. It should help apps render catalog-owned GenUI from any
Genkit model or flow, including local models, hosted providers, backend flows,
and hybrid routing.

The former `genui_genkit_llamadart` package existed because
`genkit_llamadart` requires callers to provide a resolved local GGUF path. A
useful Flutter on-device app needs more than that:

- model sources such as local paths, HTTP URLs, and `hf://` references
- package-managed download/cache resolution
- progress and error snapshots for loading UI
- checksum and private-token handling
- optional multimodal projector resolution
- model warm-up for lower first-turn latency
- predictable cleanup of download, plugin, Genkit, and native runtime state

Those responsibilities are generic to `genkit_llamadart`. They are not specific
to GenUI.

## Decision

Keep the root `genui_genkit` package provider-neutral. It should depend on
Genkit and Flutter GenUI concepts, but it should not import provider-specific
packages such as Gemini, OpenAI, or llamadart.

Use source/cache/progress/warm-up/lifecycle helpers from `genkit_llamadart`.
Flutter GenUI apps should use `genkit_llamadart` directly with
`genui_genkit.GenkitBackend`.

Remove the former `genui_genkit_llamadart` package. Provider-specific lifecycle
helpers belong in provider packages unless the behavior is truly specific to
GenUI.

Do not introduce a `genui_genkit_server` package for normal backend mode.
Backend examples should use Genkit's official server integration, such as
`genkit_shelf`.

## Upstream Work

The `genkit_llamadart` work was tracked in:

- https://github.com/leehack/genkit-llamadart/issues/3
- https://github.com/leehack/genkit-llamadart/issues/4
- https://github.com/leehack/genkit-llamadart/issues/5
- https://github.com/leehack/genkit-llamadart/issues/6

## Target Shape

The intended developer experience is:

```dart
final prepared = await llamaDart.prepareModel(
  name: 'local-genui',
  source: ModelSource.parse('hf://owner/repo/model.gguf'),
  modelParams: const ModelParams(contextSize: 4096),
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

The important boundary is that `genkit_llamadart` owns local-model lifecycle
and `genui_genkit` owns GenUI session/rendering behavior.

## Consequences

- The core `genui_genkit` package stays usable with every Genkit provider.
- App developers get one GenUI session/runtime API for local, hosted, backend,
  and hybrid execution.
- `genkit_llamadart` becomes the right package for non-GenUI local-model apps
  that also need source-backed setup and progress.
- A separate `genui_genkit_llamadart` package is not needed after the upstream
  API lands and examples migrate.
