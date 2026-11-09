import 'dart:convert';
import 'dart:math';

import 'package:a2ui_agent/a2ui_agent.dart';

/// Finds the JSON blocks a model wrote in its reply.
///
/// Reads markdown-fenced JSON blocks, or, when the text has none, the first
/// JSON object or array in it, as `genui`'s parser did.
abstract final class JsonBlockParser {
  static final _fencedJson = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');

  /// Returns the values of the fenced JSON blocks in [text] that decode, or,
  /// when none does, the first JSON object or array in [text].
  static List<Object> parseJsonBlocks(String text) {
    final blocks = <Object>[
      for (final match in _fencedJson.allMatches(text))
        if (_decode(match.group(1)!) case final Object value) value,
    ];
    if (blocks.isNotEmpty) return blocks;
    return [?_firstJsonValue(text)];
  }

  /// Removes the fenced JSON blocks from [text], or, when it has none, the
  /// JSON object or array it starts with, and trims the rest.
  static String stripJsonBlock(String text) {
    var stripped = text.replaceAll(_fencedJson, '');
    if (stripped.length == text.length) {
      final json = _balancedJson(text);
      if (json != null) stripped = text.replaceFirst(json, '');
    }
    return stripped.trim();
  }

  static Object? _firstJsonValue(String text) {
    final starts = [text.indexOf('{'), text.indexOf('[')].where((i) => i >= 0);
    if (starts.isEmpty) return null;
    final rest = text.substring(starts.reduce(min));
    final json = _balancedJson(rest);
    return _decode(rest) ?? (json == null ? null : _decode(json));
  }

  static Object? _decode(String source) {
    try {
      return jsonDecode(source) as Object?;
    } on FormatException {
      return null;
    }
  }

  /// Returns the JSON object or array [input] starts with, matched by its
  /// brackets, or null when [input] does not start with one.
  static String? _balancedJson(String input) {
    if (input.isEmpty) return null;
    final open = input[0];
    final close = switch (open) {
      '{' => '}',
      '[' => ']',
      _ => null,
    };
    if (close == null) return null;

    var depth = 0;
    var inString = false;
    var isEscaped = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (isEscaped) {
        isEscaped = false;
        continue;
      }
      if (char == r'\') {
        isEscaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        if (depth == 0) return input.substring(0, i + 1);
      }
    }
    return null;
  }
}

/// Rewrites the `<a2ui-json>` blocks in [text] as fenced JSON blocks.
///
/// The default system prompts come from `package:a2ui_agent`, which asks the
/// model for `<a2ui-json>` blocks. Rewriting them lets [JsonBlockParser] and
/// the A2UI stream repairer read them like the fenced blocks other prompts
/// ask for.
String fenceA2uiJsonBlocks(String text) {
  if (!text.contains('a2ui-json>')) return text;
  return [
    for (final part in DirectJsonParser(const []).unwrap(text))
      switch (part) {
        TextPart(:final text) => text,
        RawA2uiPart(:final a2uiRaw) => '```json\n$a2uiRaw\n```',
      },
  ].join('\n');
}
