import 'package:flutter/foundation.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:llamadart/llamadart.dart' as llama;

import '../activity_catalog.dart';
import '../activity_prompt.dart';
import '../backend_server_route.dart';
import '../gemini_backend.dart';
import '../llama_backend.dart';
import '../model_config.dart';
import 'performance_tracking_backend.dart';

/// Runtime dependencies for the Flutter example.
///
/// Keeping this object separate from widgets makes startup/configuration
/// replaceable: tests can inject a fake session, while real runs wrap the
/// local llamadart backend.
final class AppRuntime {
  AppRuntime({
    required this.session,
    required this.backendLabel,
    HybridAppConfig? config,
    ValueNotifier<GenUiAiRoute>? selectedRoute,
    ValueNotifier<ModelConfig>? localModelConfig,
    ValueNotifier<GeminiModelConfig>? geminiConfig,
    ValueNotifier<BackendServerConfig>? backendConfig,
    ValueNotifier<TurnPerformanceSnapshot>? turnPerformance,
    this.modelStatus,
    this.prepareModel,
    void Function()? dispose,
  }) : config = config ?? _defaultTestConfig(),
       selectedRoute = selectedRoute ?? ValueNotifier(GenUiAiRoute.local),
       localModelConfig =
           localModelConfig ??
           ValueNotifier((config ?? _defaultTestConfig()).localModel),
       geminiConfig =
           geminiConfig ??
           ValueNotifier((config ?? _defaultTestConfig()).gemini),
       backendConfig =
           backendConfig ??
           ValueNotifier((config ?? _defaultTestConfig()).backend),
       turnPerformance =
           turnPerformance ??
           ValueNotifier(const TurnPerformanceSnapshot.idle()),
       _ownsSelectedRoute = selectedRoute == null,
       _ownsLocalModelConfig = localModelConfig == null,
       _ownsGeminiConfig = geminiConfig == null,
       _ownsBackendConfig = backendConfig == null,
       _ownsTurnPerformance = turnPerformance == null,
       _dispose = dispose;

  factory AppRuntime.fromEnvironment(Map<String, String> environment) {
    final config = HybridAppConfig.fromEnvironment(environment);
    final selectedRoute = ValueNotifier<GenUiAiRoute>(config.initialRoute);
    final localModelConfig = ValueNotifier<ModelConfig>(config.localModel);
    final geminiConfig = ValueNotifier<GeminiModelConfig>(config.gemini);
    final backendConfig = ValueNotifier<BackendServerConfig>(config.backend);
    final turnPerformance = ValueNotifier<TurnPerformanceSnapshot>(
      const TurnPerformanceSnapshot.idle(),
    );
    final modelStatus = ValueNotifier<ModelRuntimeStatus>(
      ModelRuntimeStatus.idle(config.localModel),
    );
    final localBackend = LlamaLocalGenkitBackend(
      localModelConfig,
      modelStatus: modelStatus,
    );
    final backend = HybridGenUiBackend(
      routes: {
        GenUiAiRoute.local.metadataValue: localBackend,
        GenUiAiRoute.gemini.metadataValue: GeminiGenkitBackend(geminiConfig),
        GenUiAiRoute.backend.metadataValue: BackendServerGenkitBackend(
          backendConfig,
        ),
      },
      policy: (_, _) => selectedRoute.value.metadataValue,
    );
    final trackingBackend = PerformanceTrackingBackend(
      delegate: backend,
      metrics: turnPerformance,
      routeForRequest: (request) {
        final metadataRoute = request.metadata['route'];
        if (metadataRoute is String && metadataRoute.isNotEmpty) {
          return metadataRoute;
        }
        return selectedRoute.value.metadataValue;
      },
      profileForRoute: (routeName) {
        if (routeName != GenUiAiRoute.local.metadataValue) return null;
        final local = localModelConfig.value;
        final inference = local.inferenceOptions;
        return TurnPerformanceProfile(
          backendName: inference.preferredBackend.name,
          gpuLayers: inference.gpuLayers,
          contextSize: inference.contextSize,
          batchSize: inference.batchSize,
          microBatchSize: inference.microBatchSize,
          maxTokens: local.maxTokens,
        );
      },
    );
    const systemPromptOptions = GenUiSystemPromptOptions();
    final localWarmUpSystemPrompt = activityGenUiSystemPromptBuilder([
      activityCatalog,
    ], systemPromptOptions);
    final session = GenkitGenUiSession(
      backend: trackingBackend,
      catalog: activityCatalog,
      systemPromptBuilder: activityGenUiSystemPromptBuilder,
      metadata: const {'app': 'flutter_hybrid_genui'},
      metadataBuilder: () => {
        'mode': 'hybrid',
        'route': selectedRoute.value.metadataValue,
        'initialRoute': config.initialRoute.metadataValue,
        'localModelSource':
            localModelConfig.value.modelSource.metadataSourceKey,
        'geminiModel': geminiConfig.value.modelName,
        'backendUrl': backendConfig.value.endpoint.toString(),
      },
    );

    return AppRuntime(
      session: session,
      backendLabel: 'Hybrid Genkit routes',
      config: config,
      selectedRoute: selectedRoute,
      localModelConfig: localModelConfig,
      geminiConfig: geminiConfig,
      backendConfig: backendConfig,
      turnPerformance: turnPerformance,
      modelStatus: modelStatus,
      prepareModel: () =>
          localBackend.prepare(warmUpSystemPrompt: localWarmUpSystemPrompt),
      dispose: () {
        session.dispose();
        modelStatus.dispose();
        selectedRoute.dispose();
        localModelConfig.dispose();
        geminiConfig.dispose();
        backendConfig.dispose();
        turnPerformance.dispose();
      },
    );
  }

  factory AppRuntime.test({
    required GenkitGenUiSession session,
    String backendLabel = 'Injected test backend',
    HybridAppConfig? config,
    ValueNotifier<GenUiAiRoute>? selectedRoute,
    ValueNotifier<ModelConfig>? localModelConfig,
    ValueNotifier<GeminiModelConfig>? geminiConfig,
    ValueNotifier<BackendServerConfig>? backendConfig,
    ValueNotifier<TurnPerformanceSnapshot>? turnPerformance,
    ValueListenable<ModelRuntimeStatus>? modelStatus,
    Future<void> Function()? prepareModel,
  }) {
    return AppRuntime(
      session: session,
      backendLabel: backendLabel,
      config: config,
      selectedRoute: selectedRoute,
      localModelConfig: localModelConfig,
      geminiConfig: geminiConfig,
      backendConfig: backendConfig,
      turnPerformance: turnPerformance,
      modelStatus: modelStatus,
      prepareModel: prepareModel,
    );
  }

  final GenkitGenUiSession session;
  final String backendLabel;
  final HybridAppConfig config;
  final ValueNotifier<GenUiAiRoute> selectedRoute;
  final ValueNotifier<ModelConfig> localModelConfig;
  final ValueNotifier<GeminiModelConfig> geminiConfig;
  final ValueNotifier<BackendServerConfig> backendConfig;
  final ValueNotifier<TurnPerformanceSnapshot> turnPerformance;
  final ValueListenable<ModelRuntimeStatus>? modelStatus;
  final Future<void> Function()? prepareModel;
  final bool _ownsSelectedRoute;
  final bool _ownsLocalModelConfig;
  final bool _ownsGeminiConfig;
  final bool _ownsBackendConfig;
  final bool _ownsTurnPerformance;
  final void Function()? _dispose;
  var _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final dispose = _dispose;
    if (dispose == null) {
      session.dispose();
      if (_ownsSelectedRoute) selectedRoute.dispose();
      if (_ownsLocalModelConfig) localModelConfig.dispose();
      if (_ownsGeminiConfig) geminiConfig.dispose();
      if (_ownsBackendConfig) backendConfig.dispose();
      if (_ownsTurnPerformance) turnPerformance.dispose();
      return;
    }
    dispose();
  }
}

HybridAppConfig _defaultTestConfig() {
  return HybridAppConfig.fromEnvironment(const {'HOME': '/tmp'});
}

enum ModelRuntimePhase {
  idle,
  resolving,
  checkingCache,
  downloading,
  verifying,
  loading,
  ready,
  failed,
  cancelled,
}

final class ModelRuntimeStatus {
  const ModelRuntimeStatus({
    required this.config,
    required this.phase,
    this.assetLabel = 'Model',
    this.progress,
    this.resolvedModelPath,
    this.errorMessage,
  });

  factory ModelRuntimeStatus.idle(ModelConfig config) {
    return ModelRuntimeStatus(config: config, phase: ModelRuntimePhase.idle);
  }

  factory ModelRuntimeStatus.loading({
    required ModelConfig config,
    String assetLabel = 'Model',
    String? resolvedModelPath,
  }) {
    return ModelRuntimeStatus(
      config: config,
      phase: ModelRuntimePhase.loading,
      assetLabel: assetLabel,
      resolvedModelPath: resolvedModelPath,
    );
  }

  factory ModelRuntimeStatus.ready({
    required ModelConfig config,
    String assetLabel = 'Model',
    String? resolvedModelPath,
  }) {
    return ModelRuntimeStatus(
      config: config,
      phase: ModelRuntimePhase.ready,
      assetLabel: assetLabel,
      resolvedModelPath: resolvedModelPath,
    );
  }

  factory ModelRuntimeStatus.fromDownload({
    required ModelConfig config,
    required llama.ModelDownloadTaskSnapshot snapshot,
    required String assetLabel,
  }) {
    return ModelRuntimeStatus(
      config: config,
      phase: switch (snapshot.stage) {
        llama.ModelDownloadTaskStage.idle => ModelRuntimePhase.idle,
        llama.ModelDownloadTaskStage.resolving => ModelRuntimePhase.resolving,
        llama.ModelDownloadTaskStage.checkingCache =>
          ModelRuntimePhase.checkingCache,
        llama.ModelDownloadTaskStage.downloading =>
          ModelRuntimePhase.downloading,
        llama.ModelDownloadTaskStage.verifying => ModelRuntimePhase.verifying,
        llama.ModelDownloadTaskStage.ready => ModelRuntimePhase.ready,
        llama.ModelDownloadTaskStage.failed => ModelRuntimePhase.failed,
        llama.ModelDownloadTaskStage.cancelled => ModelRuntimePhase.cancelled,
      },
      assetLabel: assetLabel,
      progress: snapshot.fraction,
      resolvedModelPath: snapshot.entry?.filePath,
      errorMessage: snapshot.errorMessage,
    );
  }

  final ModelConfig config;
  final ModelRuntimePhase phase;
  final String assetLabel;
  final double? progress;
  final String? resolvedModelPath;
  final String? errorMessage;

  bool get isRunning {
    return switch (phase) {
      ModelRuntimePhase.resolving ||
      ModelRuntimePhase.checkingCache ||
      ModelRuntimePhase.downloading ||
      ModelRuntimePhase.verifying ||
      ModelRuntimePhase.loading => true,
      _ => false,
    };
  }

  bool get isReady => phase == ModelRuntimePhase.ready;

  ModelRuntimeStatus copyWith({
    ModelRuntimePhase? phase,
    String? assetLabel,
    double? progress,
    String? resolvedModelPath,
    String? errorMessage,
  }) {
    return ModelRuntimeStatus(
      config: config,
      phase: phase ?? this.phase,
      assetLabel: assetLabel ?? this.assetLabel,
      progress: progress ?? this.progress,
      resolvedModelPath: resolvedModelPath ?? this.resolvedModelPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@visibleForTesting
AppRuntime runtimeForSession(GenkitGenUiSession session) {
  return AppRuntime.test(session: session);
}
