import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import 'a2ui_stream_repairer.dart';
import 'backend.dart';

/// Message rendered by a host chat UI.
final class GenUiChatEntry {
  const GenUiChatEntry._({
    required this.isUser,
    this.text,
    this.surfaceId,
    this.isError = false,
  });

  const GenUiChatEntry.user(String text) : this._(isUser: true, text: text);

  const GenUiChatEntry.assistantText(String text)
    : this._(isUser: false, text: text);

  const GenUiChatEntry.assistantSurface(String surfaceId)
    : this._(isUser: false, surfaceId: surfaceId);

  const GenUiChatEntry.error(String text)
    : this._(isUser: false, text: text, isError: true);

  final bool isUser;
  final String? text;
  final String? surfaceId;
  final bool isError;

  GenUiChatEntry appendText(String chunk) {
    return GenUiChatEntry._(
      isUser: isUser,
      text: '${text ?? ''}$chunk',
      surfaceId: surfaceId,
      isError: isError,
    );
  }
}

/// Builds the system prompt used for a turn.
typedef GenUiSystemPromptBuilder =
    String Function(List<Catalog> catalogs, GenUiSystemPromptOptions options);

/// Supplies app metadata for each outgoing turn.
typedef GenUiMetadataBuilder = Map<String, Object?> Function();

final class GenUiSystemPromptOptions {
  const GenUiSystemPromptOptions({
    this.surfaceOperations,
    this.systemPromptFragments = const [],
    this.clientDataModel,
    this.technicalPossibilities = const TechnicalPossibilities(),
  });

  final SurfaceOperations? surfaceOperations;
  final Iterable<String> systemPromptFragments;
  final JsonMap? clientDataModel;
  final TechnicalPossibilities technicalPossibilities;
}

String defaultGenUiSystemPromptBuilder(
  List<Catalog> catalogs,
  GenUiSystemPromptOptions options,
) {
  final catalogIds = catalogs
      .map((catalog) => catalog.catalogId)
      .whereType<String>()
      .join(', ');
  final baseFragments = [
    'You are a helpful assistant that can generate interactive UI for the user.',
    if (catalogIds.isNotEmpty)
      'The available catalogIds are: $catalogIds. Do not invent URL-like catalog IDs.',
    'When you create a UI, output both required A2UI JSON blocks: first createSurface, then updateComponents for the same surfaceId. Every A2UI JSON block must include top-level "version": "v0.9". The updateComponents message must include a component with id "root" using one of the catalog components.',
    'Each updateComponents entry must be a flat component definition, for example { "id": "root", "component": "ActivityCard", ...properties }. The "component" value is the component name string; never nest a component object inside the "component" field.',
    'Only the component with id "root" is rendered as the surface entry point. If multiple components should be visible, the root component must reference the other component ids using a property supported by its schema.',
    'For layout components, children must be an array of component id strings, never inline component objects.',
    ...options.systemPromptFragments,
    PromptFragments.acknowledgeUser(),
    PromptFragments.uiGenerationRestriction(
      prefix: PromptBuilder.defaultImportancePrefix,
    ),
  ];
  return catalogs
      .map(
        (catalog) => PromptBuilder.custom(
          catalog: catalog,
          allowedOperations:
              options.surfaceOperations ??
              SurfaceOperations.createOnly(dataModel: false),
          systemPromptFragments: baseFragments,
          clientDataModel: options.clientDataModel,
          technicalPossibilities: options.technicalPossibilities,
        ).systemPromptJoined(),
      )
      .join('\n\n=====================================\n\n');
}

/// Builds a shorter system prompt for local/on-device models.
///
/// This keeps the A2UI schema but emits it as minified JSON and removes some of
/// the more verbose default prompt prose. It is useful for mobile providers
/// where prompt evaluation dominates perceived latency.
String compactGenUiSystemPromptBuilder(
  List<Catalog> catalogs,
  GenUiSystemPromptOptions options,
) {
  final catalogIds = catalogs
      .map((catalog) => catalog.catalogId)
      .whereType<String>()
      .join(', ');
  final surfaceOperations =
      options.surfaceOperations ??
      SurfaceOperations.createOnly(dataModel: false);
  final baseFragments = [
    'You generate compact interactive Flutter UI using A2UI.',
    if (catalogIds.isNotEmpty)
      'Use only these catalogIds: $catalogIds. Do not invent catalog IDs.',
    'When UI is useful, output separate fenced JSON blocks in this order: createSurface, then updateComponents for the same surfaceId. Never combine operations in one JSON object. Every block needs "version":"v0.9".',
    'updateComponents must include one visible root component with "id":"root". Components are flat objects like {"id":"root","component":"ActivityCard",...}. The component value is a string. For multiple visible widgets, use root Column with children as component id strings.',
    ...options.systemPromptFragments,
    PromptFragments.acknowledgeUser(),
    PromptFragments.uiGenerationRestriction(
      prefix: PromptBuilder.defaultImportancePrefix,
    ),
    ...options.technicalPossibilities.systemPromptFragment(),
    if (!surfaceOperations.update)
      'Do not update previous surfaces. Create a new surface with a new surfaceId when UI changes.',
    if (surfaceOperations.update)
      'You may update an existing surface with updateComponents when requested.',
    if (surfaceOperations.delete)
      'You may delete surfaces with deleteSurface when requested.',
    if (surfaceOperations.dataModel)
      'You may update the surface data model with updateDataModel when needed.',
  ];

  return catalogs
      .map((catalog) {
        final schema = A2uiMessage.a2uiMessageSchema(catalog).toJson();
        return [
          ...baseFragments,
          ...catalog.systemPromptFragments,
          'A2UI JSON schema:\n```json\n$schema\n```',
          if (options.clientDataModel != null)
            'Client Data Model:\n${jsonEncode(options.clientDataModel)}',
          'The schema above is reference material only. Do not copy, summarize, or explain it. For the user request, emit only the requested acknowledgement and A2UI JSON blocks.',
        ].map((fragment) => fragment.trim()).join('\n\n');
      })
      .join('\n\n=====================================\n\n');
}

/// High-level session that bridges GenUI transport events to a backend.
final class GenkitGenUiSession extends ChangeNotifier {
  GenkitGenUiSession({
    required GenUiBackend backend,
    Catalog? catalog,
    List<Catalog>? catalogs,
    GenUiSystemPromptBuilder systemPromptBuilder =
        defaultGenUiSystemPromptBuilder,
    GenUiSystemPromptOptions systemPromptOptions =
        const GenUiSystemPromptOptions(),
    Map<String, Object?> metadata = const {},
    GenUiMetadataBuilder? metadataBuilder,
  }) : _backend = backend,
       _catalogs = _normalizeCatalogs(catalog: catalog, catalogs: catalogs),
       _systemPromptBuilder = systemPromptBuilder,
       _systemPromptOptions = systemPromptOptions,
       _metadata = metadata,
       _metadataBuilder = metadataBuilder {
    _surfaceController = SurfaceController(catalogs: _catalogs);
    _transport = A2uiTransportAdapter(onSend: _sendToBackend);
    _surfaceSubscription = _surfaceController.surfaceUpdates.listen(
      _handleSurfaceUpdate,
      onError: _addError,
    );
    _submitSubscription = _surfaceController.onSubmit.listen((message) {
      if (!_disposed) {
        unawaited(_transport.sendRequest(message));
      }
    }, onError: _addError);
  }

  final GenUiBackend _backend;
  final List<Catalog> _catalogs;
  final GenUiSystemPromptBuilder _systemPromptBuilder;
  final GenUiSystemPromptOptions _systemPromptOptions;
  final Map<String, Object?> _metadata;
  final GenUiMetadataBuilder? _metadataBuilder;

  late final SurfaceController _surfaceController;
  late final A2uiTransportAdapter _transport;

  late final StreamSubscription<SurfaceUpdate> _surfaceSubscription;
  late final StreamSubscription<ChatMessage> _submitSubscription;
  StreamSubscription<GenUiBackendEvent>? _activeBackendSubscription;
  Completer<void>? _activeTurnCompleter;

  final _rawTextController = StreamController<String>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  final List<GenUiChatEntry> _messages = [];
  final List<ChatMessage> _history = [];

  var _isProcessing = false;
  var _disposed = false;
  var _activeTurnCancelled = false;
  int? _currentAssistantTextIndex;

  SurfaceController get surfaceController => _surfaceController;

  List<Catalog> get catalogs => List.unmodifiable(_catalogs);

  Stream<String> get rawText => _rawTextController.stream;

  Stream<Object> get errors => _errorController.stream;

  List<GenUiChatEntry> get messages => List.unmodifiable(_messages);

  bool get isProcessing => _isProcessing;

  Future<void> cancelActiveTurn() async {
    if (_disposed || !_isProcessing) return;
    _activeTurnCancelled = true;
    final activeTurnCompleter = _activeTurnCompleter;
    if (activeTurnCompleter != null && !activeTurnCompleter.isCompleted) {
      activeTurnCompleter.complete();
    }
    await _activeBackendSubscription?.cancel();
    await Future<void>.sync(_backend.cancelActiveTurn);
    _activeBackendSubscription = null;
    _activeTurnCompleter = null;
    if (!_disposed) {
      _isProcessing = false;
      _notifyIfAlive();
    }
  }

  void clear() {
    if (_disposed || _isProcessing) return;
    _messages.clear();
    _history.clear();
    _currentAssistantTextIndex = null;
    _notifyIfAlive();
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _disposed || _isProcessing) return;

    _messages.add(GenUiChatEntry.user(trimmed));
    _currentAssistantTextIndex = null;
    _notifyIfAlive();

    await _transport.sendRequest(ChatMessage.user(trimmed));
  }

  Future<void> _sendToBackend(ChatMessage message) async {
    if (_disposed) return;
    if (_isProcessing) {
      _addError(StateError('A GenUI turn is already in progress.'));
      return;
    }

    _isProcessing = true;
    _notifyIfAlive();

    final assistantRaw = StringBuffer();
    final done = Completer<void>();
    _activeTurnCompleter = done;
    _activeTurnCancelled = false;

    try {
      final request = _turnRequestFor(message);
      _activeBackendSubscription = _backend
          .send(request)
          .listen(
            (event) {
              if (_disposed) return;
              switch (event) {
                case GenUiTextChunk(:final text):
                  assistantRaw.write(text);
                  if (!_rawTextController.isClosed) {
                    _rawTextController.add(text);
                  }
                case GenUiBackendError(
                  :final message,
                  :final cause,
                  :final stackTrace,
                ):
                  _addError(cause ?? message, stackTrace);
                case GenUiTurnDone():
                  break;
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!_disposed) {
                _addError(error, stackTrace);
              }
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: false,
          );

      await done.future;
      if (!_disposed && !_activeTurnCancelled) {
        _history.add(message);
        final assistantText = assistantRaw.toString();
        if (assistantText.isNotEmpty) {
          _handleAssistantOutput(assistantText);
          _history.add(ChatMessage.model(assistantText));
        }
      }
    } catch (error, stackTrace) {
      _addError(error, stackTrace);
    } finally {
      _activeBackendSubscription = null;
      _activeTurnCompleter = null;
      if (!_disposed) {
        _isProcessing = false;
        _notifyIfAlive();
      }
    }
  }

  void _handleAssistantOutput(String output) {
    if (!_containsPotentialJson(output)) {
      _appendAssistantText(output);
      return;
    }

    final repaired = repairCompleteA2uiText(output);

    final messages = <A2uiMessage>[];
    var containsA2ui = false;
    for (final block in JsonBlockParser.parseJsonBlocks(repaired)) {
      for (final json in _a2uiJsonMapsFrom(block)) {
        containsA2ui = true;
        try {
          messages.add(A2uiMessage.fromJson(json));
        } catch (error, stackTrace) {
          _addError(error, stackTrace);
        }
      }
    }

    final visibleText = containsA2ui
        ? JsonBlockParser.stripJsonBlock(repaired)
        : repaired;
    if (visibleText.trim().isNotEmpty) {
      _appendAssistantText(visibleText);
    }

    for (final message in messages) {
      _handleA2uiMessage(message);
    }
  }

  void _handleA2uiMessage(A2uiMessage message) {
    if (message case UpdateComponents(
      :final surfaceId,
    ) when !_surfaceController.registry.hasSurface(surfaceId)) {
      final catalogId = _defaultCatalogId();
      if (catalogId != null) {
        _surfaceController.handleMessage(
          CreateSurface(surfaceId: surfaceId, catalogId: catalogId),
        );
      }
    }

    _surfaceController.handleMessage(message);
  }

  void _appendAssistantText(String chunk) {
    if (_disposed) return;
    if (_currentAssistantTextIndex == null) {
      _messages.add(GenUiChatEntry.assistantText(chunk));
      _currentAssistantTextIndex = _messages.length - 1;
    } else {
      final index = _currentAssistantTextIndex!;
      _messages[index] = _messages[index].appendText(chunk);
    }
    _notifyIfAlive();
  }

  void _handleSurfaceUpdate(SurfaceUpdate update) {
    if (_disposed) return;
    switch (update) {
      case SurfaceAdded():
        break;
      case SurfaceRemoved(:final surfaceId):
        _messages.removeWhere((entry) => entry.surfaceId == surfaceId);
        _notifyIfAlive();
      case ComponentsUpdated(:final surfaceId, :final definition):
        _ensureSurfaceMessage(
          surfaceId,
          hasVisibleRoot: definition.components.containsKey('root'),
        );
    }
  }

  void _ensureSurfaceMessage(String surfaceId, {required bool hasVisibleRoot}) {
    if (!hasVisibleRoot) return;
    final exists = _messages.any((entry) => entry.surfaceId == surfaceId);
    if (exists) return;

    _messages.add(GenUiChatEntry.assistantSurface(surfaceId));
    _currentAssistantTextIndex = null;
    _notifyIfAlive();
  }

  void _addError(Object error, [StackTrace? stackTrace]) {
    if (_disposed) return;
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
    _messages.add(GenUiChatEntry.error(error.toString()));
    _notifyIfAlive();
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  GenUiTurnRequest _turnRequestFor(ChatMessage message) {
    return GenUiTurnRequest(
      message: message,
      history: List.unmodifiable(_history),
      systemPrompt: _systemPromptBuilder(_catalogs, _systemPromptOptions),
      catalogId: _catalogs.first.catalogId,
      metadata: _metadataForTurn(),
    );
  }

  Map<String, Object?> _metadataForTurn() {
    final dynamicMetadata = _metadataBuilder?.call();
    if (dynamicMetadata == null || dynamicMetadata.isEmpty) {
      return _metadata;
    }
    if (_metadata.isEmpty) {
      return dynamicMetadata;
    }
    return {..._metadata, ...dynamicMetadata};
  }

  String? _defaultCatalogId() {
    for (final catalog in _catalogs) {
      final catalogId = catalog.catalogId;
      if (catalogId != null && catalogId.isNotEmpty) {
        return catalogId;
      }
    }
    return null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final activeTurnCompleter = _activeTurnCompleter;
    if (activeTurnCompleter != null && !activeTurnCompleter.isCompleted) {
      activeTurnCompleter.complete();
    }
    unawaited(_activeBackendSubscription?.cancel());
    unawaited(Future<void>.sync(_backend.cancelActiveTurn));
    unawaited(_surfaceSubscription.cancel());
    unawaited(_submitSubscription.cancel());
    _transport.dispose();
    _surfaceController.dispose();
    unawaited(Future<void>.sync(_backend.dispose));
    unawaited(_rawTextController.close());
    unawaited(_errorController.close());
    super.dispose();
  }
}

List<Catalog> _normalizeCatalogs({Catalog? catalog, List<Catalog>? catalogs}) {
  final normalized = [?catalog, ...?catalogs];
  if (normalized.isEmpty) {
    throw ArgumentError('GenkitGenUiSession requires at least one catalog.');
  }
  return List.unmodifiable(normalized);
}

bool _containsPotentialJson(String text) {
  return text.contains('{') || text.contains('```');
}

Iterable<Map<String, Object?>> _a2uiJsonMapsFrom(Object? value) sync* {
  if (value is Map) {
    final json = Map<String, Object?>.from(value);
    if (_a2uiMessageKeys.any(json.containsKey)) {
      yield json;
    }
    return;
  }

  if (value is List) {
    for (final item in value) {
      yield* _a2uiJsonMapsFrom(item);
    }
  }
}

const _a2uiMessageKeys = <String>[
  'createSurface',
  'updateComponents',
  'updateDataModel',
  'deleteSurface',
  'action',
];
