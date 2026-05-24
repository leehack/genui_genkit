# genui_genkit_llamadart

Run Flutter GenUI turns on-device by resolving llamadart models and adapting
them through Genkit.

This package is intentionally optional. Apps that only use hosted providers or
backend Genkit flows can depend on `genui_genkit` without pulling in native
model dependencies.

```text
ModelSource
  |
  v
llamadart download/cache manager
  |
  v
cached GGUF path
  |
  v
genkit_llamadart model registration
  |
  v
GenkitBackend
```

## Minimal Use

```dart
import 'package:genui_genkit_llamadart/genui_genkit_llamadart.dart';
import 'package:llamadart/llamadart.dart' as llama;

final backend = LlamaDartGenUiBackend(
  LlamaDartGenUiConfig(
    modelSource: llama.ModelSource.parse(
      'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf',
    ),
    cachePolicy: llama.ModelCachePolicy.preferCached,
  ),
);
final systemPromptUsedByYourSession = '...';

await backend.prepare(warmUpSystemPrompt: systemPromptUsedByYourSession);
```

Use `backend.snapshots` to show download/cache progress in a Flutter UI. Keep a
separate indeterminate "loading model" state while `prepare()` is still pending;
`prepare()` resolves the file and performs a warm-up request so the first real
user turn does not hide model loading behind chat latency. Pass the same compact
system prompt your session will use when you want llamadart prompt-prefix reuse
to reduce the first turn's time to first token. If no prompt is supplied,
`prepare()` falls back to a tiny one-token warm-up.

## Model Sources

`modelSource` accepts any `llamadart` `ModelSource`:

```dart
llama.ModelSource.parse('/path/to/model.gguf');
llama.ModelSource.parse('https://example.com/model.gguf');
llama.ModelSource.parse('hf://owner/repo/path/to/model.gguf');
```

Remote sources use llamadart's package-managed download/cache layer. Local file
paths are passed through without remote-only options such as bearer tokens.

## Configuration

`LlamaDartGenUiConfig` supports:

- model and optional multimodal projector sources
- cache directory and cache policy
- optional SHA-256 verification
- bearer tokens for private or rate-limited downloads
- Genkit model name
- load-time inference options such as context size, GPU backend/layers, thread
  counts, batch sizes, flash attention, and KV cache type
- generation options such as temperature, max tokens, and thinking mode

The default local GenUI profile uses `contextSize: 4096`, `batchSize: 512`,
`microBatchSize: 256`, `maxTokens: 512`, and automatic backend/thread
selection. This keeps enough context for compact A2UI prompts while matching
the fastest stable Pixel 9 Pro Gemma 4 E2B profile measured in the example
benchmark. Pair it with `compactGenUiSystemPromptBuilder` for mobile/on-device
apps; use `LlamaDartInferenceOptions.mobileCompact` only for shorter prompts or
benchmarks.

## Local Dependency Development

This package depends on hosted `genkit_llamadart`. If you need to test against
a local checkout, use an uncommitted `pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  genkit_llamadart:
    path: /path/to/genkit-llamadart
```
