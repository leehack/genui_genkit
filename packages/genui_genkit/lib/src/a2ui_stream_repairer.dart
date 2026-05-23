import 'dart:async';
import 'dart:convert';

/// Repairs narrow, common A2UI formatting mistakes in model text streams.
///
/// This intentionally does not invent A2UI messages. It only adds the required
/// protocol version to JSON objects that already contain a known A2UI message
/// key. It also normalizes common local-model shapes where component
/// definitions are nested under the `component` key, or inline under a layout
/// component's `children`, instead of being flat component entries.
final class A2uiStreamRepairer extends StreamTransformerBase<String, String> {
  const A2uiStreamRepairer();

  @override
  Stream<String> bind(Stream<String> stream) {
    return _A2uiStreamRepair(stream).stream;
  }
}

final class _A2uiStreamRepair {
  _A2uiStreamRepair(Stream<String> input) {
    _controller = StreamController<String>(
      onListen: () {
        _subscription = input.listen(
          _onData,
          onError: _controller.addError,
          onDone: _onDone,
          cancelOnError: false,
        );
      },
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: () => _subscription?.cancel(),
    );
  }

  late final StreamController<String> _controller;
  StreamSubscription<String>? _subscription;
  var _buffer = '';

  Stream<String> get stream => _controller.stream;

  void _onData(String chunk) {
    _buffer += chunk;
    _processBuffer(flush: false);
  }

  void _onDone() {
    _processBuffer(flush: true);
    if (_buffer.isNotEmpty) {
      _controller.add(_buffer);
      _buffer = '';
    }
    unawaited(_controller.close());
  }

  void _processBuffer({required bool flush}) {
    while (_buffer.isNotEmpty) {
      final candidate = _nextCompleteCandidate(_buffer);
      if (candidate != null) {
        if (candidate.start > 0) {
          _controller.add(_buffer.substring(0, candidate.start));
        }
        _controller.add(candidate.repaired);
        _buffer = _buffer.substring(candidate.end);
        continue;
      }

      final potentialStart = _firstPotentialJsonStart(_buffer);
      if (potentialStart == -1) {
        _controller.add(_buffer);
        _buffer = '';
        break;
      }

      if (potentialStart > 0) {
        _controller.add(_buffer.substring(0, potentialStart));
        _buffer = _buffer.substring(potentialStart);
        continue;
      }

      if (flush) {
        _controller.add(_buffer);
        _buffer = '';
      }
      break;
    }
  }
}

_RepairCandidate? _nextCompleteCandidate(String text) {
  final markdown = _findMarkdownJson(text);
  final balancedJson = _findBalancedJson(text);
  final markdownStart = text.indexOf('```');
  if (markdownStart != -1 &&
      (balancedJson == null || markdownStart <= balancedJson.start)) {
    return markdown;
  }
  if (markdown == null) return balancedJson;
  if (balancedJson == null) return markdown;
  return markdown.start <= balancedJson.start ? markdown : balancedJson;
}

_RepairCandidate? _findMarkdownJson(String text) {
  final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(text);
  if (match == null) return null;

  final original = match.group(0) ?? '';
  final content = match.group(1) ?? '';
  final repaired = _repairJson(content);
  return _RepairCandidate(
    start: match.start,
    end: match.end,
    repaired: repaired == null ? original : '```json\n$repaired\n```',
  );
}

_RepairCandidate? _findBalancedJson(String input) {
  final start = input.indexOf('{');
  if (start == -1) return null;

  var balance = 0;
  var inString = false;
  var isEscaped = false;

  for (var i = start; i < input.length; i++) {
    final char = input[i];

    if (isEscaped) {
      isEscaped = false;
      continue;
    }
    if (char == '\\') {
      isEscaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;

    if (char == '{') {
      balance++;
    } else if (char == '}') {
      balance--;
      if (balance == 0) {
        final original = input.substring(start, i + 1);
        return _RepairCandidate(
          start: start,
          end: i + 1,
          repaired: _repairJson(original) ?? original,
        );
      }
    }
  }

  return null;
}

String? _repairJson(String source) {
  try {
    final decoded = jsonDecode(source);
    final repaired = _repairDecodedJson(decoded);
    if (identical(repaired, decoded)) return null;
    return const JsonEncoder.withIndent('  ').convert(repaired);
  } on FormatException {
    return null;
  }
}

Object? _repairDecodedJson(Object? value) {
  if (value is Map<String, Object?>) {
    return _repairA2uiObject(value);
  }

  if (value is List) {
    var changed = false;
    final repaired = <Object?>[];
    for (final item in value) {
      if (item is Map<String, Object?>) {
        final repairedItem = _repairA2uiObject(item);
        changed = changed || !identical(repairedItem, item);
        repaired.add(repairedItem);
      } else {
        repaired.add(item);
      }
    }
    return changed ? repaired : value;
  }

  return value;
}

Map<String, Object?> _repairA2uiObject(Map<String, Object?> value) {
  final normalized = _normalizeA2uiObject(value);
  if (normalized['version'] == null && _containsA2uiMessageKey(normalized)) {
    return <String, Object?>{'version': 'v0.9', ...normalized};
  }
  return normalized;
}

Map<String, Object?> _normalizeA2uiObject(Map<String, Object?> value) {
  final updateComponents = value['updateComponents'];
  if (updateComponents is! Map<String, Object?>) return value;

  final normalizedUpdate = _normalizeUpdateComponents(updateComponents);
  if (identical(normalizedUpdate, updateComponents)) return value;

  return <String, Object?>{...value, 'updateComponents': normalizedUpdate};
}

Map<String, Object?> _normalizeUpdateComponents(
  Map<String, Object?> updateComponents,
) {
  final components = updateComponents['components'];
  if (components is! List) return updateComponents;

  var changed = false;
  final normalizedComponents = <Object?>[];
  for (final component in components) {
    if (component is Map<String, Object?>) {
      final normalized = _normalizeComponentTree(component);
      changed = changed || normalized.changed;
      normalizedComponents.add(normalized.component);
      normalizedComponents.addAll(normalized.extractedComponents);
    } else {
      normalizedComponents.add(component);
    }
  }

  if (!changed) return updateComponents;
  return <String, Object?>{
    ...updateComponents,
    'components': normalizedComponents,
  };
}

_NormalizedComponent _normalizeComponentTree(Map<String, Object?> component) {
  var normalized = _normalizeComponentDefinition(component);
  var changed = !identical(normalized, component);
  final extracted = <Map<String, Object?>>[];

  final children = normalized['children'];
  if (children is List) {
    final childRefs = <Object?>[];
    for (final child in children) {
      if (child is Map<String, Object?>) {
        final normalizedChild = _normalizeComponentTree(child);
        final childId = normalizedChild.component['id'];
        final childType = normalizedChild.component['component'];
        if (childId is String && childType is String) {
          childRefs.add(childId);
          extracted.add(normalizedChild.component);
          extracted.addAll(normalizedChild.extractedComponents);
          changed = true;
          continue;
        }
      }
      childRefs.add(child);
    }

    if (changed) {
      normalized = <String, Object?>{...normalized, 'children': childRefs};
    }
  }

  return _NormalizedComponent(
    component: normalized,
    extractedComponents: extracted,
    changed: changed,
  );
}

Map<String, Object?> _normalizeComponentDefinition(
  Map<String, Object?> component,
) {
  final nested = component['component'];
  if (nested is! Map<String, Object?>) return component;

  final nestedType = nested['component'];
  if (nestedType is! String) return component;

  final id = component['id'] ?? nested['id'];
  final normalized = <String, Object?>{...nested, ...component};
  normalized['component'] = nestedType;
  if (id != null) normalized['id'] = id;
  return normalized;
}

final class _NormalizedComponent {
  const _NormalizedComponent({
    required this.component,
    required this.extractedComponents,
    required this.changed,
  });

  final Map<String, Object?> component;
  final List<Map<String, Object?>> extractedComponents;
  final bool changed;
}

bool _containsA2uiMessageKey(Map<String, Object?> value) {
  return value.containsKey('createSurface') ||
      value.containsKey('updateComponents') ||
      value.containsKey('updateDataModel') ||
      value.containsKey('deleteSurface') ||
      value.containsKey('action');
}

int _firstPotentialJsonStart(String text) {
  final markdownStart = text.indexOf('```');
  final braceStart = text.indexOf('{');
  if (markdownStart == -1) return braceStart;
  if (braceStart == -1) return markdownStart;
  return markdownStart < braceStart ? markdownStart : braceStart;
}

final class _RepairCandidate {
  const _RepairCandidate({
    required this.start,
    required this.end,
    required this.repaired,
  });

  final int start;
  final int end;
  final String repaired;
}
