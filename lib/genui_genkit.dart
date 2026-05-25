/// Experimental GenUI + Genkit adapter APIs.
///
/// The public surface is intentionally small while Flutter GenUI APIs are
/// experimental. [GenkitBackend] adapts any configured Genkit model into a
/// text/A2UI stream; [GenkitGenUiSession] pipes those chunks into GenUI's A2UI
/// transport and surface controller.
library;

export 'src/backend.dart';
export 'src/genkit_backend.dart';
export 'src/hybrid_backend.dart';
export 'src/remote_backend.dart';
export 'src/remote_genkit_flow_backend.dart';
export 'src/session.dart';
export 'src/widgets.dart';
