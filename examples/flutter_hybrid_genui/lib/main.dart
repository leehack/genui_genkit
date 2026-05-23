import 'dart:io';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/runtime/app_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = AppRuntime.fromEnvironment(Platform.environment);

  runApp(FlutterHybridGenUiApp(runtime: runtime));
}
