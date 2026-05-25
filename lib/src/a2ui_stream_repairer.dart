import 'dart:async';
import 'dart:convert';

/// Repairs narrow, common A2UI formatting mistakes in model text streams.
///
/// This intentionally does not invent A2UI messages. It only adds the required
/// protocol version to JSON objects that already contain a known A2UI message
/// key. It also normalizes common local-model shapes where component
/// definitions are nested under the `component` key, or inline under a layout
/// component's `children`, instead of being flat component entries. If a model
/// emits multiple sibling components without a root, it adds a root `Column`
/// that references those siblings so they can all render.
final class A2uiStreamRepairer extends StreamTransformerBase<String, String> {
  const A2uiStreamRepairer();

  @override
  Stream<String> bind(Stream<String> stream) {
    return _A2uiStreamRepair(stream).stream;
  }
}

/// Repairs complete model output with the same rules as [A2uiStreamRepairer].
///
/// Use this when a caller already has a full turn response and needs a
/// synchronous parser boundary instead of a long-lived stream.
String repairCompleteA2uiText(String text) {
  var buffer = text;
  final output = StringBuffer();

  while (buffer.isNotEmpty) {
    final candidate = _nextCompleteCandidate(buffer, flush: true);
    if (candidate == null) {
      output.write(buffer);
      break;
    }

    if (candidate.start > 0) {
      output.write(buffer.substring(0, candidate.start));
    }
    output.write(candidate.repaired);
    buffer = buffer.substring(candidate.end);
  }

  return output.toString();
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
      final candidate = _nextCompleteCandidate(_buffer, flush: flush);
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

_RepairCandidate? _nextCompleteCandidate(String text, {required bool flush}) {
  final markdown = _findMarkdownJson(text, flush: flush);
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

_RepairCandidate? _findMarkdownJson(String text, {required bool flush}) {
  final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(text);
  if (match == null) {
    return flush ? _findUnclosedMarkdownJson(text) : null;
  }

  final original = match.group(0) ?? '';
  final content = match.group(1) ?? '';
  final repaired = _repairJson(content);
  return _RepairCandidate(
    start: match.start,
    end: match.end,
    repaired: repaired == null ? original : '```json\n$repaired\n```',
  );
}

_RepairCandidate? _findUnclosedMarkdownJson(String text) {
  final match = RegExp(r'```(?:json)?\s*').firstMatch(text);
  if (match == null) return null;

  final content = text.substring(match.end);
  final json = _findBalancedJson(content);
  if (json == null) return null;

  final source = content.substring(json.start, json.end);
  final repaired = _repairJson(source, forceEncode: true);
  if (repaired == null) return null;

  return _RepairCandidate(
    start: match.start,
    end: match.end + json.end,
    repaired: '```json\n$repaired\n```',
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

String? _repairJson(String source, {bool forceEncode = false}) {
  final decoded = _decodeJson(source);
  if (decoded == null) return null;

  final repaired = _repairDecodedJson(decoded.value);
  if (!_containsA2uiValue(repaired)) return null;
  if (identical(repaired, decoded.value) &&
      !decoded.sanitized &&
      !forceEncode) {
    return null;
  }

  return const JsonEncoder.withIndent('  ').convert(repaired);
}

_DecodedJson? _decodeJson(String source) {
  try {
    return _DecodedJson(jsonDecode(source), sanitized: false);
  } on FormatException {
    final sanitized = _stripJsonCommentsAndTrailingCommas(source);
    if (sanitized == source) return null;
    try {
      return _DecodedJson(jsonDecode(sanitized), sanitized: true);
    } on FormatException {
      return null;
    }
  }
}

String _stripJsonCommentsAndTrailingCommas(String source) {
  final withoutComments = StringBuffer();
  var inString = false;
  var isEscaped = false;
  var i = 0;

  while (i < source.length) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (isEscaped) {
      withoutComments.write(char);
      isEscaped = false;
      i++;
      continue;
    }

    if (char == '\\') {
      withoutComments.write(char);
      isEscaped = true;
      i++;
      continue;
    }

    if (char == '"') {
      withoutComments.write(char);
      inString = !inString;
      i++;
      continue;
    }

    if (!inString && char == '/' && next == '/') {
      i += 2;
      while (i < source.length && source[i] != '\n' && source[i] != '\r') {
        i++;
      }
      continue;
    }

    if (!inString && char == '/' && next == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i = i + 1 < source.length ? i + 2 : source.length;
      continue;
    }

    withoutComments.write(char);
    i++;
  }

  return withoutComments.toString().replaceAll(RegExp(r',\s*(?=[}\]])'), '');
}

Object? _repairDecodedJson(Object? value) {
  if (value is Map<String, Object?>) {
    return _repairA2uiMessageValue(value);
  }

  if (value is List) {
    var changed = false;
    final repaired = <Object?>[];
    for (final item in value) {
      if (item is Map<String, Object?>) {
        final repairedItem = _repairA2uiMessageValue(item);
        changed = changed || !identical(repairedItem, item);
        if (repairedItem is List) {
          repaired.addAll(repairedItem);
        } else {
          repaired.add(repairedItem);
        }
      } else {
        repaired.add(item);
      }
    }
    return changed ? repaired : value;
  }

  return value;
}

Object? _repairA2uiMessageValue(Map<String, Object?> value) {
  final splitCreate = _splitCreateSurfaceComponents(value);
  if (splitCreate != null) {
    return [for (final message in splitCreate) _repairA2uiObject(message)];
  }

  final split = _splitA2uiOperations(value);
  if (split == null) return _repairA2uiObject(value);
  return [for (final message in split) _repairA2uiObject(message)];
}

List<Map<String, Object?>>? _splitCreateSurfaceComponents(
  Map<String, Object?> value,
) {
  if (value.containsKey('updateComponents')) return null;

  final createSurface = value['createSurface'];
  if (createSurface is! Map<String, Object?>) return null;

  final components = createSurface['components'];
  final surfaceId = createSurface['surfaceId'];
  if (components is! List || surfaceId is! String) return null;

  return [
    <String, Object?>{
      'version': value['version'] ?? 'v0.9',
      'createSurface': <String, Object?>{
        for (final entry in createSurface.entries)
          if (entry.key != 'components') entry.key: entry.value,
      },
    },
    <String, Object?>{
      'version': value['version'] ?? 'v0.9',
      'updateComponents': <String, Object?>{
        'surfaceId': surfaceId,
        'components': components,
      },
    },
  ];
}

List<Map<String, Object?>>? _splitA2uiOperations(Map<String, Object?> value) {
  final operationKeys = _a2uiOperationKeys
      .where((key) => value.containsKey(key))
      .toList(growable: false);
  if (operationKeys.length <= 1) return null;

  final version = value['version'] ?? 'v0.9';
  return [
    for (final key in operationKeys)
      <String, Object?>{'version': version, key: value[key]},
  ];
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
      changed = true;
    }
  }

  changed = _ensureComponentIds(normalizedComponents) || changed;
  changed = _ensureRootComponent(normalizedComponents) || changed;

  if (!changed) return updateComponents;
  return <String, Object?>{
    ...updateComponents,
    'components': normalizedComponents,
  };
}

bool _ensureComponentIds(List<Object?> components) {
  final existingIds = components
      .whereType<Map<String, Object?>>()
      .map((component) => component['id'])
      .whereType<String>()
      .toSet();
  var changed = false;

  for (var i = 0; i < components.length; i++) {
    final component = components[i];
    if (component is! Map<String, Object?>) continue;
    if (component['id'] is String || component['component'] is! String) {
      continue;
    }

    final id = _uniqueComponentId(
      component['component'] as String,
      existingIds,
    );
    existingIds.add(id);
    components[i] = <String, Object?>{...component, 'id': id};
    changed = true;
  }

  return changed;
}

bool _ensureRootComponent(List<Object?> components) {
  final hasRoot = components.any((component) {
    return component is Map<String, Object?> && component['id'] == 'root';
  });
  if (hasRoot) return false;

  final componentIndexes = <int>[];
  for (var i = 0; i < components.length; i++) {
    final component = components[i];
    if (component is Map<String, Object?> &&
        component['id'] is String &&
        component['component'] is String) {
      componentIndexes.add(i);
    }
  }

  if (componentIndexes.isEmpty) return false;

  if (componentIndexes.length == 1) {
    final index = componentIndexes.single;
    final component = components[index] as Map<String, Object?>;
    components[index] = <String, Object?>{...component, 'id': 'root'};
    return true;
  }

  components.insert(0, <String, Object?>{
    'id': 'root',
    'component': 'Column',
    'children': [
      for (final index in componentIndexes)
        (components[index] as Map<String, Object?>)['id'],
    ],
  });
  return true;
}

String _uniqueComponentId(String componentType, Set<String> existingIds) {
  final base = componentType
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase()
      .replaceAll(RegExp(r'^_|_$'), '');
  final normalizedBase = base.isEmpty ? 'component' : base;

  var suffix = 1;
  var candidate = normalizedBase;
  while (existingIds.contains(candidate) || candidate == 'root') {
    suffix++;
    candidate = '${normalizedBase}_$suffix';
  }
  return candidate;
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
  return _a2uiOperationKeys.any(value.containsKey);
}

bool _containsA2uiValue(Object? value) {
  if (value is Map<String, Object?>) return _containsA2uiMessageKey(value);
  if (value is List) return value.any(_containsA2uiValue);
  return false;
}

const _a2uiOperationKeys = <String>[
  'createSurface',
  'updateComponents',
  'updateDataModel',
  'deleteSurface',
  'action',
];

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

final class _DecodedJson {
  const _DecodedJson(this.value, {required this.sanitized});

  final Object? value;
  final bool sanitized;
}
