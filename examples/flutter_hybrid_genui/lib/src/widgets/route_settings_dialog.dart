import 'package:flutter/material.dart';
import 'package:llamadart/llamadart.dart' as llama;

import '../model_config.dart';
import '../runtime/app_runtime.dart';

Future<void> showRouteSettingsDialog(
  BuildContext context,
  AppRuntime runtime,
  GenUiAiRoute selectedRoute,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return switch (selectedRoute) {
        GenUiAiRoute.gemini => _GeminiSettingsDialog(runtime: runtime),
        GenUiAiRoute.backend => _BackendSettingsDialog(runtime: runtime),
        GenUiAiRoute.local => _LocalSettingsDialog(runtime: runtime),
      };
    },
  );
}

class _GeminiSettingsDialog extends StatefulWidget {
  const _GeminiSettingsDialog({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_GeminiSettingsDialog> createState() => _GeminiSettingsDialogState();
}

class _GeminiSettingsDialogState extends State<_GeminiSettingsDialog> {
  late final _modelController = TextEditingController(
    text: widget.runtime.geminiConfig.value.modelName,
  );
  late final _apiKeyController = TextEditingController(
    text: widget.runtime.geminiConfig.value.apiKey ?? '',
  );
  late final _temperatureController = TextEditingController(
    text: widget.runtime.geminiConfig.value.temperature.toString(),
  );
  late final _maxTokensController = TextEditingController(
    text: widget.runtime.geminiConfig.value.maxTokens.toString(),
  );
  String? _errorText;

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  void _save() {
    final modelName = _modelController.text.trim();
    final temperature = double.tryParse(_temperatureController.text.trim());
    final maxTokens = int.tryParse(_maxTokensController.text.trim());
    if (modelName.isEmpty || temperature == null || maxTokens == null) {
      setState(() => _errorText = 'Check the model and numeric values.');
      return;
    }

    widget.runtime.geminiConfig.value = GeminiModelConfig(
      modelName: modelName,
      apiKey: _emptyToNull(_apiKeyController.text),
      temperature: temperature,
      maxTokens: maxTokens,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gemini settings'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                prefixIcon: Icon(Icons.auto_awesome),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API key',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _temperatureController,
                    decoration: const InputDecoration(labelText: 'Temperature'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxTokensController,
                    decoration: const InputDecoration(labelText: 'Max tokens'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _BackendSettingsDialog extends StatefulWidget {
  const _BackendSettingsDialog({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_BackendSettingsDialog> createState() => _BackendSettingsDialogState();
}

class _BackendSettingsDialogState extends State<_BackendSettingsDialog> {
  late final _urlController = TextEditingController(
    text: widget.runtime.backendConfig.value.endpoint.toString(),
  );
  String? _errorText;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _errorText = 'Enter a valid backend URL.');
      return;
    }

    widget.runtime.backendConfig.value = BackendServerConfig(endpoint: uri);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backend settings'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              keyboardType: TextInputType.url,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _LocalSettingsDialog extends StatefulWidget {
  const _LocalSettingsDialog({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_LocalSettingsDialog> createState() => _LocalSettingsDialogState();
}

class _LocalSettingsDialogState extends State<_LocalSettingsDialog> {
  late final _modelSourceController = TextEditingController(
    text: widget.runtime.localModelConfig.value.modelSource.metadataSourceKey,
  );
  late final _contextSizeController = TextEditingController(
    text: widget.runtime.localModelConfig.value.inferenceOptions.contextSize
        .toString(),
  );
  late final _gpuLayersController = TextEditingController(
    text: widget.runtime.localModelConfig.value.inferenceOptions.gpuLayers
        .toString(),
  );
  late final _batchSizeController = TextEditingController(
    text: widget.runtime.localModelConfig.value.inferenceOptions.batchSize
        .toString(),
  );
  late final _microBatchSizeController = TextEditingController(
    text: widget.runtime.localModelConfig.value.inferenceOptions.microBatchSize
        .toString(),
  );
  late final _temperatureController = TextEditingController(
    text: widget.runtime.localModelConfig.value.temperature.toString(),
  );
  late final _maxTokensController = TextEditingController(
    text: widget.runtime.localModelConfig.value.maxTokens.toString(),
  );
  late llama.GpuBackend _preferredBackend =
      widget.runtime.localModelConfig.value.inferenceOptions.preferredBackend;
  String? _errorText;

  @override
  void dispose() {
    _modelSourceController.dispose();
    _contextSizeController.dispose();
    _gpuLayersController.dispose();
    _batchSizeController.dispose();
    _microBatchSizeController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  void _save() {
    final current = widget.runtime.localModelConfig.value;
    final sourceText = _modelSourceController.text.trim();
    final contextSize = int.tryParse(_contextSizeController.text.trim());
    final gpuLayers = int.tryParse(_gpuLayersController.text.trim());
    final batchSize = int.tryParse(_batchSizeController.text.trim());
    final microBatchSize = int.tryParse(_microBatchSizeController.text.trim());
    final temperature = double.tryParse(_temperatureController.text.trim());
    final maxTokens = int.tryParse(_maxTokensController.text.trim());

    if (sourceText.isEmpty ||
        contextSize == null ||
        gpuLayers == null ||
        batchSize == null ||
        microBatchSize == null ||
        temperature == null ||
        maxTokens == null) {
      setState(() => _errorText = 'Check the model and numeric values.');
      return;
    }

    late final llama.ModelSource source;
    try {
      source = llama.ModelSource.parse(sourceText);
    } catch (error) {
      setState(() => _errorText = 'Invalid model source: $error');
      return;
    }

    widget.runtime.localModelConfig.value = current.copyWith(
      modelSource: source,
      modelSourceDisplayName: source.displayName,
      inferenceOptions: current.inferenceOptions.copyWith(
        contextSize: contextSize,
        gpuLayers: gpuLayers,
        preferredBackend: _preferredBackend,
        batchSize: batchSize,
        microBatchSize: microBatchSize,
      ),
      temperature: temperature,
      maxTokens: maxTokens,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Local settings'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _modelSourceController,
                decoration: const InputDecoration(
                  labelText: 'Model source',
                  prefixIcon: Icon(Icons.memory),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<llama.GpuBackend>(
                  selected: {_preferredBackend},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _preferredBackend = selection.single);
                  },
                  segments: const [
                    ButtonSegment<llama.GpuBackend>(
                      value: llama.GpuBackend.auto,
                      icon: Icon(Icons.auto_mode, size: 18),
                      label: Text('Auto'),
                    ),
                    ButtonSegment<llama.GpuBackend>(
                      value: llama.GpuBackend.cpu,
                      icon: Icon(Icons.memory_outlined, size: 18),
                      label: Text('CPU'),
                    ),
                    ButtonSegment<llama.GpuBackend>(
                      value: llama.GpuBackend.vulkan,
                      icon: Icon(Icons.bolt_outlined, size: 18),
                      label: Text('Vulkan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contextSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Context',
                        prefixIcon: Icon(Icons.dashboard_customize_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _gpuLayersController,
                      decoration: const InputDecoration(
                        labelText: 'GPU layers',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _batchSizeController,
                      decoration: const InputDecoration(labelText: 'Batch'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _microBatchSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Microbatch',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _temperatureController,
                      decoration: const InputDecoration(
                        labelText: 'Temperature',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxTokensController,
                      decoration: const InputDecoration(
                        labelText: 'Max tokens',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}
