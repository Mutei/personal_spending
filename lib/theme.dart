import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      clipBehavior: Clip.none,
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

final ThemeData lightTheme = _buildTheme(
  brightness: Brightness.light,
  primary: const Color(0xFF006D77),
  secondary: const Color(0xFF83C5BE),
  surface: const Color(0xFFFFFFFF),
  scaffoldBackground: const Color(0xFFF4F7F8),
  error: const Color(0xFFE29578),
);

final ThemeData darkTheme = _buildTheme(
  brightness: Brightness.dark,
  primary: const Color(0xFF00A6A6),
  secondary: const Color(0xFF264653),
  surface: const Color(0xFF1E1E1E),
  scaffoldBackground: const Color(0xFF121212),
  error: const Color(0xFFE76F51),
);

ThemeData _buildTheme({
  required Brightness brightness,
  required Color primary,
  required Color secondary,
  required Color surface,
  required Color scaffoldBackground,
  required Color error,
}) {
  final baseScheme = brightness == Brightness.light
      ? ColorScheme.light(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
        )
      : ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
        );

  final textTheme =
      GoogleFonts.poppinsTextTheme(
        brightness == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme,
      ).copyWith(
        headlineSmall: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    primaryColor: primary,
    scaffoldBackgroundColor: scaffoldBackground,
    colorScheme: baseScheme,
    textTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBackground,
      foregroundColor: baseScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: baseScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brightness == Brightness.light
          ? const Color(0xFFFFB703)
          : const Color(0xFFFFD166),
      foregroundColor: Colors.black,
      extendedTextStyle: textTheme.titleSmall?.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w700,
      ),
    ),
    chipTheme: baseScheme.brightness == Brightness.light
        ? ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: baseScheme.outline.withValues(alpha: 0.18)),
            backgroundColor: surface,
            selectedColor: primary.withValues(alpha: 0.14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            labelStyle: textTheme.bodySmall,
          )
        : ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: baseScheme.outline.withValues(alpha: 0.22)),
            backgroundColor: surface,
            selectedColor: primary.withValues(alpha: 0.20),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            labelStyle: textTheme.bodySmall,
          ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: baseScheme.surfaceContainerHighest.withValues(alpha: 0.32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: baseScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: baseScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: baseScheme.outline.withValues(alpha: 0.20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: baseScheme.outlineVariant.withValues(alpha: 0.65),
      thickness: 1,
      space: 1,
    ),
  );
}
