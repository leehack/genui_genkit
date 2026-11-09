import 'dart:convert';

import 'package:genai_primitives/genai_primitives.dart';

/// MIME type of the data part that carries a generated UI interaction, such as
/// an A2UI action or error, in a [ChatMessage].
///
/// This is the type `genui` used, so remote backends read these parts as
/// before.
const uiInteractionMimeType = 'application/vnd.genui.interaction+json';

/// Creates a data part that carries [interaction], an A2UI message encoded as
/// a JSON string.
DataPart uiInteractionPart(String interaction) {
  return DataPart(
    utf8.encode(jsonEncode({'interaction': interaction})),
    mimeType: uiInteractionMimeType,
  );
}

/// Returns the interactions carried by the UI interaction parts of [parts].
Iterable<String> uiInteractionsOf(Iterable<StandardPart> parts) sync* {
  for (final part in parts) {
    if (part is! DataPart || part.mimeType != uiInteractionMimeType) continue;
    final json = jsonDecode(utf8.decode(part.bytes));
    if (json case {'interaction': final String interaction}) {
      yield interaction;
    }
  }
}
