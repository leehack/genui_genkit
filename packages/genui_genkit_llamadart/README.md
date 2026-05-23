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

await backend.prepare();
```

Use `backend.snapshots` to show download/cache progress in a Flutter UI.

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
- context size, temperature, max tokens, and thinking mode

## Local Dependency Development

This package depends on hosted `genkit_llamadart`. If you need to test against
a local checkout, use an uncommitted `pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  genkit_llamadart:
    path: /path/to/genkit-llamadart
```
