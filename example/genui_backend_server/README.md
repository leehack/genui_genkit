# GenUI Backend Server Example

This example runs Genkit in backend mode and serves a streaming `genui` flow
with `genkit_shelf`. The Flutter hybrid example can connect to this server
through its Backend route.

```text
Flutter app
  |
  v
RemoteGenkitFlowBackend
  |
  v
genkit_shelf flow: /genui
  |
  v
Gemma via genkit_llamadart + llamadart cache
```

```sh
dart run bin/server.dart
```

By default the server resolves Gemma 4 through llamadart's package-managed
download/cache layer:

```text
hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf
```

Then start the Flutter example with:

```sh
GENUI_BACKEND_URL=http://localhost:8080/genui flutter run -d macos
```

Configuration:

- `GENUI_BACKEND_PORT` or `PORT`: server port, default `8080`
- `GENUI_BACKEND_MODEL_SOURCE`: local path, `https://...`, or `hf://owner/repo/file.gguf`; defaults to Gemma 4 E2B.
- `GENUI_BACKEND_CACHE_DIR`: package-managed model cache root.
- `GENUI_BACKEND_CACHE_POLICY`: `preferCached`, `refresh`, `cacheOnly`, or `noCache`.
- `GENUI_BACKEND_MODEL_SHA256`: optional checksum verification.
- `GENUI_BACKEND_BEARER_TOKEN` or `HUGGING_FACE_HUB_TOKEN`: optional token for private or rate-limited model downloads.
- `GENUI_BACKEND_MODEL_NAME`: Genkit model name, default `backend-gemma4`.
- `GENUI_BACKEND_CONTEXT_SIZE`: default `8192`.
- `GENUI_BACKEND_TEMPERATURE`: generation temperature, default `0.2`.
- `GENUI_BACKEND_MAX_TOKENS`: max output tokens, default `2048`.
- `GENUI_BACKEND_ENABLE_THINKING`: default `false`.

Verify:

```sh
dart analyze
dart test
```
