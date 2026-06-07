import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_hybrid_genui/src/llama_backend.dart';
import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_hybrid_genui/src/runtime/app_runtime.dart';
import 'package:flutter_hybrid_genui/src/runtime/cache_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:integration_test/integration_test.dart';

const _runLocalLiteRtSmoke = bool.fromEnvironment(
  'GENUI_RUN_LOCAL_LITERT_SMOKE',
);

const _smokeSystemPrompt =
    'You are a device validation assistant. Reply in plain text only.';

const _smokeUserPrompt = String.fromEnvironment(
  'GENUI_LOCAL_SMOKE_PROMPT',
  defaultValue: 'Reply with one short sentence that includes the word ready.',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loads a LiteRT-LM model and streams through the local Genkit backend',
    (tester) async {
      final environment = await resolveEnvironmentForFlutterApp(
        environmentWithDartDefines(Platform.environment),
      );
      final config = ModelConfig.fromEnvironment(environment);

      expect(
        config.isLiteRtLmModel,
        isTrue,
        reason:
            'Set LLAMADART_GENUI_MODEL_SOURCE to a .litertlm bundle for this '
            'explicit smoke test.',
      );

      final configNotifier = ValueNotifier(config);
      final status = ValueNotifier(ModelRuntimeStatus.idle(config));
      final backend = LlamaLocalGenkitBackend(
        configNotifier,
        modelStatus: status,
      );
      addTearDown(() async {
        await backend.dispose();
        configNotifier.dispose();
        status.dispose();
      });

      await backend
          .prepare(warmUpSystemPrompt: _smokeSystemPrompt)
          .timeout(const Duration(minutes: 30));

      expect(status.value.phase, ModelRuntimePhase.ready);
      expect(status.value.resolvedModelPath, endsWith('.litertlm'));

      final output = StringBuffer();
      await for (final event
          in backend
              .send(
                GenUiTurnRequest(
                  message: ChatMessage.user(_smokeUserPrompt),
                  systemPrompt: _smokeSystemPrompt,
                  metadata: const {'route': 'local', 'smoke': 'litert-lm'},
                ),
              )
              .timeout(const Duration(minutes: 5))) {
        switch (event) {
          case GenUiTextChunk(:final text):
            output.write(text);
          case GenUiBackendError(:final message, :final cause):
            fail('LiteRT-LM backend smoke failed: $message\n$cause');
          case GenUiTurnDone():
            break;
        }
      }

      expect(output.toString().trim(), isNotEmpty);
    },
    skip: !_runLocalLiteRtSmoke,
    timeout: const Timeout(Duration(minutes: 35)),
  );
}
