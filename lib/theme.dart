import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF006D77),
  scaffoldBackgroundColor: const Color(0xFFFAFAFA),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF006D77),
    secondary: Color(0xFF83C5BE),
    surface: Color(0xFFFFFFFF),
    error: Color(0xFFE29578),
  ),
  textTheme: GoogleFonts.poppinsTextTheme(),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF006D77),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFFFB703),
    foregroundColor: Colors.black,
  ),
  useMaterial3: true,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF00A6A6),
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00A6A6),
    secondary: Color(0xFF264653),
    surface: Color(0xFF1E1E1E),
    error: Color(0xFFE76F51),
  ),
  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF264653),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFFFD166),
    foregroundColor: Colors.black,
  ),
  useMaterial3: true,
);
