# ADR 0001: Move Generic Llamadart Model Lifecycle APIs To genkit_llamadart

## Status

Accepted, pending upstream `genkit_llamadart` support.

## Context

`genui_genkit` is intended to be the provider-neutral Flutter GenUI runtime for
Genkit-backed apps. It should help apps render catalog-owned GenUI from any
Genkit model or flow, including local models, hosted providers, backend flows,
and hybrid routing.

The current `genui_genkit_llamadart` package exists because
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

Keep `packages/genui_genkit` provider-neutral. It should depend on Genkit and
Flutter GenUI concepts, but it should not import provider-specific packages such
as Gemini, OpenAI, or llamadart.

Move source/cache/progress/warm-up/lifecycle helpers into `genkit_llamadart`.
Once those upstream APIs exist, Flutter GenUI apps should use
`genkit_llamadart` directly with `genui_genkit.GenkitBackend`.

Treat `packages/genui_genkit_llamadart` as transitional. It may remain while it
removes meaningful boilerplate, but it should not grow additional GenUI-specific
features unless the behavior is truly specific to GenUI.

Do not introduce a `genui_genkit_server` package for normal backend mode.
Backend examples should use Genkit's official server integration, such as
`genkit_shelf`.

## Upstream Work

The `genkit_llamadart` work is tracked in:

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

Exact API names can change upstream. The important boundary is that
`genkit_llamadart` owns local-model lifecycle and `genui_genkit` owns GenUI
session/rendering behavior.

## Consequences

- The core `genui_genkit` package stays usable with every Genkit provider.
- App developers get one GenUI session/runtime API for local, hosted, backend,
  and hybrid execution.
- `genkit_llamadart` becomes the right package for non-GenUI local-model apps
  that also need source-backed setup and progress.
- `genui_genkit_llamadart` can be deprecated or removed after the upstream API
  lands and the examples migrate.
- Until then, `genui_genkit_llamadart` remains useful as a temporary convenience
  layer for the example app and early users.
