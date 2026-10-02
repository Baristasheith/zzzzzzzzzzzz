import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/profile/presentation/screens/shik_home_screen.dart';

void main() {
  runApp(const ShikApp());
}

class ShikApp extends StatelessWidget {
  const ShikApp({super.key});

  @override
  Widget build(BuildContext context) {
    const sky = Color(0xFF13A9D6);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شيك',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F9FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: sky,
          primary: sky,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F9FB),
          foregroundColor: Color(0xFF172D38),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const ShikHomeScreen(),
    );
  }
}