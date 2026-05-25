import 'dart:io';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/runtime/app_runtime.dart';
import 'src/runtime/cache_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = await resolveEnvironmentForFlutterApp(
    environmentWithDartDefines(Platform.environment),
  );
  final runtime = AppRuntime.fromEnvironment(environment);

  runApp(FlutterHybridGenUiApp(runtime: runtime));
}
