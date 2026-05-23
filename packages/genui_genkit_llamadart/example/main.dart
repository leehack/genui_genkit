import 'package:genui_genkit_llamadart/genui_genkit_llamadart.dart';
import 'package:llamadart/llamadart.dart' as llama;

Future<void> main() async {
  final backend = LlamaDartGenUiBackend(
    LlamaDartGenUiConfig(
      modelSource: llama.ModelSource.parse(
        'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf',
      ),
    ),
  );

  // Call `await backend.prepare()` when the app is ready to resolve, download,
  // cache, and load the model.
  await backend.dispose();
}
