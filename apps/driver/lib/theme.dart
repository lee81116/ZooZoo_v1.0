import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff6a5c4a),
      surfaceTint: Color(0xff6a5c4a),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffe3d0b9),
      onPrimaryContainer: Color(0xff665846),
      secondary: Color(0xff705b3e),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffd4b996),
      onSecondaryContainer: Color(0xff5c492d),
      tertiary: Color(0xff361f1a),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff4e342e),
      onTertiaryContainer: Color(0xffc19c94),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffdf8f7),
      onSurface: Color(0xff1d1b1b),
      onSurfaceVariant: Color(0xff4d453f),
      outline: Color(0xff7f756e),
      outlineVariant: Color(0xffd0c4bc),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff32302f),
      inversePrimary: Color(0xffd6c4ad),
      primaryFixed: Color(0xfff3e0c8),
      onPrimaryFixed: Color(0xff241a0c),
      primaryFixedDim: Color(0xffd6c4ad),
      onPrimaryFixedVariant: Color(0xff514534),
      secondaryFixed: Color(0xfffbdeb9),
      onSecondaryFixed: Color(0xff271903),
      secondaryFixedDim: Color(0xffdec29f),
      onSecondaryFixedVariant: Color(0xff564428),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff2b1611),
      tertiaryFixedDim: Color(0xffe5beb5),
      onTertiaryFixedVariant: Color(0xff5c403a),
      surfaceDim: Color(0xffded9d8),
      surfaceBright: Color(0xfffdf8f7),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f2f1),
      surfaceContainer: Color(0xfff2edeb),
      surfaceContainerHigh: Color(0xffece7e6),
      surfaceContainerHighest: Color(0xffe6e1e0),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff403424),
      surfaceTint: Color(0xff6a5c4a),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff796b58),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff443319),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff7f694b),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff361f1a),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff4e342e),
      onTertiaryContainer: Color(0xffebc4bb),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffdf8f7),
      onSurface: Color(0xff121110),
      onSurfaceVariant: Color(0xff3c352f),
      outline: Color(0xff59514b),
      outlineVariant: Color(0xff756b65),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff32302f),
      inversePrimary: Color(0xffd6c4ad),
      primaryFixed: Color(0xff796b58),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff605341),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff7f694b),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff665135),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff85665e),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff6b4e47),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffcac5c4),
      surfaceBright: Color(0xfffdf8f7),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f2f1),
      surfaceContainer: Color(0xffece7e6),
      surfaceContainerHigh: Color(0xffe1dcda),
      surfaceContainerHighest: Color(0xffd5d1cf),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff352a1b),
      surfaceTint: Color(0xff6a5c4a),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff544736),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff392910),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff59462b),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff361f1a),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff4e342e),
      onTertiaryContainer: Color(0xfffffcff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffdf8f7),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff322b25),
      outlineVariant: Color(0xff504842),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff32302f),
      inversePrimary: Color(0xffd6c4ad),
      primaryFixed: Color(0xff544736),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff3c3121),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff59462b),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff413016),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff5e423c),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff452c27),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffbcb8b7),
      surfaceBright: Color(0xfffdf8f7),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff5f0ee),
      surfaceContainer: Color(0xffe6e1e0),
      surfaceContainerHigh: Color(0xffd8d3d2),
      surfaceContainerHighest: Color(0xffcac5c4),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffecd7),
      surfaceTint: Color(0xffd6c4ad),
      onPrimary: Color(0xff3a2f1f),
      primaryContainer: Color(0xffe3d0b9),
      onPrimaryContainer: Color(0xff665846),
      secondary: Color(0xfff1d5b0),
      onSecondary: Color(0xff3e2d14),
      secondaryContainer: Color(0xffd4b996),
      onSecondaryContainer: Color(0xff5c492d),
      tertiary: Color(0xffe5beb5),
      onTertiary: Color(0xff432a25),
      tertiaryContainer: Color(0xff4e342e),
      onTertiaryContainer: Color(0xffc19c94),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff141313),
      onSurface: Color(0xffe6e1e0),
      onSurfaceVariant: Color(0xffd0c4bc),
      outline: Color(0xff998f87),
      outlineVariant: Color(0xff4d453f),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe6e1e0),
      inversePrimary: Color(0xff6a5c4a),
      primaryFixed: Color(0xfff3e0c8),
      onPrimaryFixed: Color(0xff241a0c),
      primaryFixedDim: Color(0xffd6c4ad),
      onPrimaryFixedVariant: Color(0xff514534),
      secondaryFixed: Color(0xfffbdeb9),
      onSecondaryFixed: Color(0xff271903),
      secondaryFixedDim: Color(0xffdec29f),
      onSecondaryFixedVariant: Color(0xff564428),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff2b1611),
      tertiaryFixedDim: Color(0xffe5beb5),
      onTertiaryFixedVariant: Color(0xff5c403a),
      surfaceDim: Color(0xff141313),
      surfaceBright: Color(0xff3b3938),
      surfaceContainerLowest: Color(0xff0f0e0d),
      surfaceContainerLow: Color(0xff1d1b1b),
      surfaceContainer: Color(0xff211f1f),
      surfaceContainerHigh: Color(0xff2b2a29),
      surfaceContainerHighest: Color(0xff363434),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffecd7),
      surfaceTint: Color(0xffd6c4ad),
      onPrimary: Color(0xff3a2f1f),
      primaryContainer: Color(0xffe3d0b9),
      onPrimaryContainer: Color(0xff493c2c),
      secondary: Color(0xfff5d8b3),
      onSecondary: Color(0xff32230a),
      secondaryContainer: Color(0xffd4b996),
      onSecondaryContainer: Color(0xff3d2d13),
      tertiary: Color(0xfffcd3ca),
      onTertiary: Color(0xff37201a),
      tertiaryContainer: Color(0xffac8981),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff141313),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffe7dad2),
      outline: Color(0xffbbb0a8),
      outlineVariant: Color(0xff998e87),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe6e1e0),
      inversePrimary: Color(0xff534635),
      primaryFixed: Color(0xfff3e0c8),
      onPrimaryFixed: Color(0xff181004),
      primaryFixedDim: Color(0xffd6c4ad),
      onPrimaryFixedVariant: Color(0xff403424),
      secondaryFixed: Color(0xfffbdeb9),
      onSecondaryFixed: Color(0xff1b0f00),
      secondaryFixedDim: Color(0xffdec29f),
      onSecondaryFixedVariant: Color(0xff443319),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff1f0c07),
      tertiaryFixedDim: Color(0xffe5beb5),
      onTertiaryFixedVariant: Color(0xff49302a),
      surfaceDim: Color(0xff141313),
      surfaceBright: Color(0xff464443),
      surfaceContainerLowest: Color(0xff080707),
      surfaceContainerLow: Color(0xff1f1d1d),
      surfaceContainer: Color(0xff292727),
      surfaceContainerHigh: Color(0xff343231),
      surfaceContainerHighest: Color(0xff3f3d3c),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffedd9),
      surfaceTint: Color(0xffd6c4ad),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffe3d0b9),
      onPrimaryContainer: Color(0xff261c0e),
      secondary: Color(0xffffedd9),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffdabe9b),
      onSecondaryContainer: Color(0xff130900),
      tertiary: Color(0xffffece8),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffe1bab1),
      onTertiaryContainer: Color(0xff180604),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff141313),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xfffbeee5),
      outlineVariant: Color(0xffccc0b8),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe6e1e0),
      inversePrimary: Color(0xff534635),
      primaryFixed: Color(0xfff3e0c8),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffd6c4ad),
      onPrimaryFixedVariant: Color(0xff181004),
      secondaryFixed: Color(0xfffbdeb9),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffdec29f),
      onSecondaryFixedVariant: Color(0xff1b0f00),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffe5beb5),
      onTertiaryFixedVariant: Color(0xff1f0c07),
      surfaceDim: Color(0xff141313),
      surfaceBright: Color(0xff524f4f),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff211f1f),
      surfaceContainer: Color(0xff32302f),
      surfaceContainerHigh: Color(0xff3d3b3a),
      surfaceContainerHighest: Color(0xff484646),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }


  ThemeData theme(ColorScheme colorScheme) => ThemeData(
     useMaterial3: true,
     brightness: colorScheme.brightness,
     colorScheme: colorScheme,
     textTheme: textTheme.apply(
       bodyColor: colorScheme.onSurface,
       displayColor: colorScheme.onSurface,
     ),
     scaffoldBackgroundColor: colorScheme.surface,
     canvasColor: colorScheme.surface,
  );


  List<ExtendedColor> get extendedColors => [
  ];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
