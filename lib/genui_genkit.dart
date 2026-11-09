/// Experimental GenUI + Genkit adapter APIs.
///
/// The public surface is intentionally small while Flutter GenUI APIs are
/// experimental. [GenkitBackend] adapts any configured Genkit model into a
/// text/A2UI stream; [GenkitGenUiSession] parses the A2UI messages in those
/// chunks and renders them with an A2UI `MessageProcessor`.
library;

export 'src/backend.dart';
export 'src/genkit_backend.dart';
export 'src/hybrid_backend.dart';
export 'src/prompt_options.dart';
export 'src/remote_backend.dart';
export 'src/remote_genkit_flow_backend.dart';
export 'src/session.dart';
export 'src/widgets.dart';
