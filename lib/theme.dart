import 'package:fluent_ui/fluent_ui.dart';

FluentThemeData buildLightTheme() {
  return FluentThemeData(
    accentColor: Colors.blue,
    visualDensity: VisualDensity.standard,
    focusTheme: const FocusThemeData(
      glowFactor: 1.5,
    ),
  );
}

FluentThemeData buildDarkTheme() {
  return FluentThemeData.dark().copyWith(
    accentColor: Colors.blue,
    visualDensity: VisualDensity.standard,
    focusTheme: const FocusThemeData(
      glowFactor: 1.5,
    ),
  );
}
