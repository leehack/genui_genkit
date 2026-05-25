import 'dart:io';

import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:genui_backend_server/src/server_config.dart';
import 'package:genui_backend_server/src/turn_request.dart';

Future<void> main() async {
  final config = GenUiBackendServerConfig.fromEnvironment(Platform.environment);
  final prepared = await llamaDart.prepareModel(
    name: config.modelName,
    source: config.modelSource,
    modelParams: ModelParams(contextSize: config.contextSize),
    options: config.loadOptionsFor(config.modelSource),
    supportsEmbeddings: false,
  );

  final ai = genkit.Genkit(plugins: [prepared.plugin]);
  final flow = ai
      .defineFlow<Map<String, Object?>, Map<String, Object?>, String, void>(
        name: 'genui',
        streamSchema: .string(),
        fn: (input, context) async {
          final turn = GenUiFlowTurnRequest.fromJson(input);
          final stream = ai.generateStream<LlamaDartGenerationConfig, Object?>(
            model: prepared.modelRef,
            messages: genkitMessagesForTurn(turn),
            config: LlamaDartGenerationConfig(
              temperature: config.temperature,
              maxTokens: config.maxTokens,
              enableThinking: config.enableThinking,
            ),
          );

          await for (final chunk in stream) {
            final text = chunk.text;
            if (text.isNotEmpty) {
              context.sendChunk(text);
            }
          }

          return resultMetadataFromResponse(await stream.onResult);
        },
      );

  final server = await startFlowServer(
    flows: [flow],
    port: config.port,
    cors: const {'origin': '*'},
  );

  stdout.writeln(
    'GenUI backend listening on http://localhost:${server.port}/genui',
  );
  stdout.writeln('Gemma model: ${config.modelSourceDisplayName}');
  stdout.writeln('Model file: ${prepared.modelEntry.filePath}');
}
