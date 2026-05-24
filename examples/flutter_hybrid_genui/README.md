# Flutter Hybrid GenUI Example

Experimental Flutter desktop app that can route each turn through local
llamadart, direct Gemini, or a backend Genkit flow. It is intended to be a
useful reference app, not only a smoke-test demo.

```text
Flutter GenUI → genui_genkit → Dart Genkit → local llamadart
                                      ├── direct Gemini
                                      └── remote Genkit flow
```

`genui` is experimental, so this example intentionally keeps the catalog small and exposes raw model output for debugging.

## What To Try

- Start on the Local route and let llamadart resolve/cache the default Gemma
  GGUF model.
- Switch to Gemini from the route selector and configure the model/API key from
  route settings.
- Switch to Backend after starting `examples/genui_backend_server`.
- Inspect the generated catalog UI first; use raw stream only when debugging
  model output or A2UI parsing.
- Compare Local inference profiles from route settings. The app shows TTFT,
  elapsed time, estimated decode/effective tok/s, output size, requested GPU
  backend, context, and batch settings after each turn.
- Use the Local status card to track both model download/cache progress and the
  separate model-loading warm-up before the first local turn. Preparing the
  model warms the same compact activity GenUI prompt used by chat turns.

## Run

```bash
cd examples/flutter_hybrid_genui
flutter pub get
flutter run -d macos
```

The app starts on the Local route. On first use, it resolves the default model
through llamadart's package-managed download/cache layer:

```text
hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf
```

The route selector in the status card can switch to Gemini or Backend before
sending a prompt.

The Local route settings can switch between Auto, CPU, and Vulkan, and can
adjust GPU layers, context size, batch sizes, temperature, and max tokens. Save
the settings, rerun the same prompt, and compare the performance strip to see
whether Vulkan improves the device you are testing.

## Route Gemini Directly

```bash
GEMINI_API_KEY="your-api-key" GENUI_AI_ROUTE=gemini flutter run -d macos
```

The Gemini route uses the same `GenkitBackend` adapter as local llamadart, but
registers the `genkit_google_genai` provider in the Flutter process.

## Route To A Genkit Backend

Start the backend example in another terminal:

```bash
cd ../genui_backend_server
dart run bin/server.dart
```

Then run this app:

```bash
GENUI_AI_ROUTE=backend GENUI_BACKEND_URL=http://localhost:8080/genui flutter run -d macos
```

## Configure The Local Model

Use a local file:

```bash
LLAMADART_GENUI_MODEL_SOURCE=~/Models/my-model.gguf flutter run -d macos
```

On Android and iOS, pass the same settings with Flutter defines because mobile
apps do not inherit your shell environment:

```bash
flutter run -d <device-id> \
  --dart-define=LLAMADART_GENUI_MODEL_SOURCE=/path/on/device/model.gguf \
  --dart-define=LLAMADART_GENUI_MODEL_LABEL="Local Gemma"
```

Use another Hugging Face GGUF:

```bash
LLAMADART_GENUI_MODEL_SOURCE=hf://owner/repo/path/to/model.gguf flutter run -d macos
```

Refresh the package cache:

```bash
LLAMADART_GENUI_CACHE_POLICY=refresh flutter run -d macos
```

## Benchmark Candidate Models

The skipped quality benchmark compares local GenUI reliability and throughput
for the default Gemma model, Liquid LFM2.5 1.2B Q4_0, Qwen3 0.6B Q8_0, and
Qwen3 1.7B Q4_K_M:

```bash
flutter test test/local_genui_quality_benchmark_test.dart \
  --dart-define=GENUI_RUN_LOCAL_QUALITY_BENCHMARK=true
```

Override `GENUI_QUALITY_BENCHMARK_MODELS` with semicolon-separated
`name|hf://owner/repo/file.gguf` entries to test other models.

## Environment

- `GENUI_AI_ROUTE` — `local`, `gemini`, or `backend`; default `local`.
- `GENUI_BACKEND_URL` — remote Genkit flow URL, default `http://localhost:8080/genui`.
- `GENUI_GEMINI_API_KEY`, `GEMINI_API_KEY`, or `GOOGLE_API_KEY` — API key for direct Gemini.
- `GENUI_GEMINI_MODEL` — Gemini model name, default `gemini-3.5-flash`.
- `GENUI_GEMINI_TEMPERATURE` — direct Gemini temperature, default `0.2`.
- `GENUI_GEMINI_MAX_TOKENS` — direct Gemini max output tokens, default `2048`.
- Gemini model/API key, Backend URL, and Local inference settings can also be edited from the route settings button in the app.
- `LLAMADART_GENUI_MODEL_SOURCE` — local path, `https://...`, or `hf://owner/repo/file.gguf`; defaults to Gemma 4 E2B.
- `LLAMADART_MODEL_PATH` — legacy local-path override, still supported.
- `LLAMADART_GENUI_MMPROJ_SOURCE` / `LLAMADART_MMPROJ_PATH` — optional multimodal projector source.
- `LLAMADART_GENUI_CACHE_DIR` — package-managed model cache root. On Android/iOS the app defaults to `<application support>/llamadart/genui`; on desktop the config falls back to the user's cache directory when available.
- `LLAMADART_GENUI_CACHE_POLICY` — `preferCached`, `refresh`, `cacheOnly`, or `noCache`.
- `LLAMADART_GENUI_MODEL_SHA256` / `LLAMADART_GENUI_MMPROJ_SHA256` — optional checksum verification.
- `LLAMADART_GENUI_BEARER_TOKEN` or `HUGGING_FACE_HUB_TOKEN` — optional token for private or rate-limited model downloads.
- `LLAMADART_GENUI_MODEL_NAME` — Genkit model name, default `local-genui`.
- `LLAMADART_GENUI_CONTEXT_SIZE` — default `4096`; the app uses a compact A2UI prompt so local Android runs avoid the heavier 8192-token context.
- `LLAMADART_GENUI_BATCH_SIZE` — default `512`.
- `LLAMADART_GENUI_MICRO_BATCH_SIZE` — default `256`.
- `LLAMADART_GENUI_GPU_BACKEND` — `auto`, `cpu`, `vulkan`, `metal`, `cuda`, `blas`, `opencl`, or `hip`; default `auto`.
- `LLAMADART_GENUI_GPU_LAYERS` — llamadart GPU layer count, default all supported layers when the selected backend uses GPU.
- `LLAMADART_GENUI_THREADS` / `LLAMADART_GENUI_THREADS_BATCH` — generation and prompt-eval thread counts, default `0` for llamadart auto.
- `LLAMADART_GENUI_FLASH_ATTENTION` — `auto`, `enabled`, or `disabled`; default `auto`.
- `LLAMADART_GENUI_CACHE_TYPE_K` / `LLAMADART_GENUI_CACHE_TYPE_V` — `f16`, `q8_0`, or `q4_0`; default `f16`.
- `LLAMADART_GENUI_MAX_TOKENS` — default `512` for local mobile responsiveness.
- `LLAMADART_GENUI_TEMPERATURE` — default `0.0` for deterministic local A2UI.
- `LLAMADART_GENUI_ENABLE_THINKING` — default `false`.

The app reads these keys from the process environment on desktop and from
`--dart-define` values on Flutter mobile builds.

## Verify

```bash
flutter analyze
flutter test
flutter test integration_test -d macos
```
