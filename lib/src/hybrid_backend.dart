import 'dart:async';

import 'backend.dart';

/// Chooses which named backend should handle a turn.
typedef GenUiRoutePolicy =
    FutureOr<String> Function(
      GenUiTurnRequest request,
      Map<String, GenUiBackend> routes,
    );

/// Routes each turn to one of several backends.
///
/// This is useful for hybrid apps where private/offline tasks use an on-device
/// backend and larger or network-only tasks use a remote backend.
final class HybridGenUiBackend implements GenUiBackend {
  HybridGenUiBackend({
    required Map<String, GenUiBackend> routes,
    required GenUiRoutePolicy policy,
  }) : _routes = Map.unmodifiable(routes),
       _policy = policy {
    if (_routes.isEmpty) {
      throw ArgumentError.value(routes, 'routes', 'Must not be empty.');
    }
  }

  final Map<String, GenUiBackend> _routes;
  final GenUiRoutePolicy _policy;
  GenUiBackend? _activeBackend;
  var _disposed = false;

  Map<String, GenUiBackend> get routes => _routes;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError('HybridGenUiBackend has been disposed.');
      return;
    }

    try {
      final routeName = await _policy(request, _routes);
      final backend = _routes[routeName];
      if (backend == null) {
        yield GenUiBackendError('Unknown GenUI backend route: $routeName');
        return;
      }
      _activeBackend = backend;
      yield* backend.send(request);
    } catch (error, stackTrace) {
      yield GenUiBackendError(
        error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _activeBackend = null;
    }
  }

  @override
  Future<void> cancelActiveTurn() async {
    await _activeBackend?.cancelActiveTurn();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final backends = Set<GenUiBackend>.identity()..addAll(_routes.values);
    for (final backend in backends) {
      await backend.dispose();
    }
  }
}
