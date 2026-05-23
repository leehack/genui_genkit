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

Use another Hugging Face GGUF:

```bash
LLAMADART_GENUI_MODEL_SOURCE=hf://owner/repo/path/to/model.gguf flutter run -d macos
```

Refresh the package cache:

```bash
LLAMADART_GENUI_CACHE_POLICY=refresh flutter run -d macos
```

## Environment

- `GENUI_AI_ROUTE` — `local`, `gemini`, or `backend`; default `local`.
- `GENUI_BACKEND_URL` — remote Genkit flow URL, default `http://localhost:8080/genui`.
- `GENUI_GEMINI_API_KEY`, `GEMINI_API_KEY`, or `GOOGLE_API_KEY` — API key for direct Gemini.
- `GENUI_GEMINI_MODEL` — Gemini model name, default `gemini-3.5-flash`.
- `GENUI_GEMINI_TEMPERATURE` — direct Gemini temperature, default `0.2`.
- `GENUI_GEMINI_MAX_TOKENS` — direct Gemini max output tokens, default `2048`.
- Gemini model/API key and Backend URL can also be edited from the route settings button in the app.
- `LLAMADART_GENUI_MODEL_SOURCE` — local path, `https://...`, or `hf://owner/repo/file.gguf`; defaults to Gemma 4 E2B.
- `LLAMADART_MODEL_PATH` — legacy local-path override, still supported.
- `LLAMADART_GENUI_MMPROJ_SOURCE` / `LLAMADART_MMPROJ_PATH` — optional multimodal projector source.
- `LLAMADART_GENUI_CACHE_DIR` — package-managed model cache root. Defaults to the user's cache directory when available.
- `LLAMADART_GENUI_CACHE_POLICY` — `preferCached`, `refresh`, `cacheOnly`, or `noCache`.
- `LLAMADART_GENUI_MODEL_SHA256` / `LLAMADART_GENUI_MMPROJ_SHA256` — optional checksum verification.
- `LLAMADART_GENUI_BEARER_TOKEN` or `HUGGING_FACE_HUB_TOKEN` — optional token for private or rate-limited model downloads.
- `LLAMADART_GENUI_MODEL_NAME` — Genkit model name, default `local-genui`.
- `LLAMADART_GENUI_CONTEXT_SIZE` — default `8192`.
- `LLAMADART_GENUI_MAX_TOKENS` — default `2048`.
- `LLAMADART_GENUI_TEMPERATURE` — default `0.2`.
- `LLAMADART_GENUI_ENABLE_THINKING` — default `false`.

## Verify

```bash
flutter analyze
flutter test
flutter test integration_test -d macos
```
