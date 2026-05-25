import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genui_genkit/genui_genkit.dart';

import 'model_config.dart';

/// Direct Gemini route for the hybrid example.
///
/// The app still talks through the common [GenkitBackend], so the only
/// provider-specific work here is Genkit plugin setup and option mapping.
final class GeminiGenkitBackend implements GenUiBackend {
  GeminiGenkitBackend(this.config);

  final ValueListenable<GeminiModelConfig> config;

  GenkitBackend<GeminiOptions>? _backend;
  GeminiModelConfig? _activeConfig;
  var _disposed = false;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError('GeminiGenkitBackend has been disposed.');
      return;
    }
    final currentConfig = config.value;
    if (!currentConfig.hasApiKey) {
      yield const GenUiBackendError(
        'Gemini API key is not configured. Set GENUI_GEMINI_API_KEY, '
        'GEMINI_API_KEY, or GOOGLE_API_KEY before using this route.',
      );
      return;
    }

    final backend = await _ensureBackend(currentConfig);
    yield* backend.send(request);
  }

  @override
  FutureOr<void> cancelActiveTurn() {
    return _backend?.cancelActiveTurn();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _backend?.dispose();
    _backend = null;
  }

  Future<GenkitBackend<GeminiOptions>> _ensureBackend(
    GeminiModelConfig currentConfig,
  ) async {
    final existing = _backend;
    final activeConfig = _activeConfig;
    if (existing != null &&
        activeConfig != null &&
        currentConfig.sameRuntimeConfig(activeConfig)) {
      return existing;
    }

    await existing?.dispose();

    final ai = genkit.Genkit(plugins: [googleAI(apiKey: currentConfig.apiKey)]);
    _activeConfig = currentConfig;
    return _backend = GenkitBackend<GeminiOptions>(
      ai: ai,
      model: googleAI.gemini(currentConfig.modelName),
      config: GeminiOptions(
        temperature: currentConfig.temperature,
        maxOutputTokens: currentConfig.maxTokens,
      ),
      onDispose: ai.shutdown,
    );
  }
}
