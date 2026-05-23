import 'package:flutter/material.dart';

import 'runtime/app_runtime.dart';
import 'screens/genui_demo_screen.dart';

class FlutterHybridGenUiApp extends StatelessWidget {
  const FlutterHybridGenUiApp({super.key, required this.runtime});

  final AppRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI Genkit Hybrid Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF18334A),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFD7E7F2),
          onPrimaryContainer: Color(0xFF0D263A),
          secondary: Color(0xFF1F7A68),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFD8EFE7),
          onSecondaryContainer: Color(0xFF0D352D),
          tertiary: Color(0xFFC45A2B),
          onTertiary: Color(0xFFFFFFFF),
          tertiaryContainer: Color(0xFFFFDCCB),
          onTertiaryContainer: Color(0xFF4E1D08),
          error: Color(0xFFBA1A1A),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFFFDAD6),
          onErrorContainer: Color(0xFF410002),
          surface: Color(0xFFF7F2E8),
          onSurface: Color(0xFF1E1B16),
          surfaceContainerHighest: Color(0xFFE8DFCF),
          onSurfaceVariant: Color(0xFF51483B),
          outline: Color(0xFF807568),
          outlineVariant: Color(0xFFD1C6B7),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFF34302A),
          onInverseSurface: Color(0xFFF5EFE5),
          inversePrimary: Color(0xFFA8CBE0),
        ),
        useMaterial3: true,
        fontFamily: 'Avenir Next',
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFBF3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFD1C6B7)),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: Color(0xFFC5B8A6)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFBF3),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCFC3B3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1F7A68), width: 1.5),
          ),
        ),
      ),
      home: GenUiDemoScreen(runtime: runtime),
    );
  }
}
