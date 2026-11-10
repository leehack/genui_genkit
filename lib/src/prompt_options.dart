/// The A2UI operations a model may use on surfaces.
///
/// Passed to the system prompt builders through
/// `GenUiSystemPromptOptions.surfaceOperations`, which tell the model which
/// messages it may write.
final class SurfaceOperations {
  /// Creates surface operations. At least one of [create], [update] and
  /// [delete] must be enabled.
  SurfaceOperations({
    this.create = false,
    this.update = false,
    this.delete = false,
    this.dataModel = false,
  }) : assert(
         create || update || delete,
         'At least one operation must be enabled.',
       );

  /// The model creates a new surface for each reply.
  SurfaceOperations.createOnly({required bool dataModel})
    : this(create: true, dataModel: dataModel);

  /// The model updates the surfaces of earlier turns.
  SurfaceOperations.updateOnly({required bool dataModel})
    : this(update: true, dataModel: dataModel);

  /// The model creates surfaces and updates the surfaces of earlier turns.
  SurfaceOperations.createAndUpdate({required bool dataModel})
    : this(create: true, update: true, dataModel: dataModel);

  /// The model creates, updates and deletes surfaces.
  SurfaceOperations.all({required bool dataModel})
    : this(create: true, update: true, delete: true, dataModel: dataModel);

  /// Whether the model may create surfaces.
  final bool create;

  /// Whether the model may update the surfaces of earlier turns.
  final bool update;

  /// Whether the model may delete surfaces.
  final bool delete;

  /// Whether the model may write the data model with `updateDataModel`.
  final bool dataModel;

  /// The A2UI message types these operations allow.
  List<String> get allowedMessages => [
    if (create) 'createSurface',
    if (create || update) 'updateComponents',
    if (dataModel) 'updateDataModel',
    if (delete) 'deleteSurface',
  ];
}

/// What the model can do besides writing text, stated in the system prompt.
final class TechnicalPossibilities {
  /// Creates technical possibilities. All are off by default.
  const TechnicalPossibilities({
    this.codeExecution = false,
    this.toolCall = false,
    this.functionCall = false,
    this.importancePrefix = 'IMPORTANT: ',
  });

  /// Whether the model can execute code.
  final bool codeExecution;

  /// Whether the model can use tools.
  final bool toolCall;

  /// Whether the model can make function calls.
  final bool functionCall;

  /// Prefix of each prompt fragment, to stress it to the model.
  final String importancePrefix;

  /// Prompt fragments that tell the model what it cannot do.
  Iterable<String> systemPromptFragment() {
    return [
      if (!codeExecution)
        '${importancePrefix}You do not have the ability to execute code. If you need to perform calculations, do them yourself.',
      if (!toolCall)
        '${importancePrefix}You do not have the ability to use tools for UI generation.',
      if (!functionCall)
        '${importancePrefix}You do not have the ability to use function calls for UI generation.',
    ];
  }
}
