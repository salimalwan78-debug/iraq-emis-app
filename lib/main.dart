import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'intro_screen.dart'; // استيراد شاشة البداية المتحركة

void main() {
  runApp(const EmisApp());
}

class EmisApp extends StatelessWidget {
  const EmisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام EMIS العراقي',
      debugShowCheckedModeBanner: false,
      supportedLocales: const [
        Locale('ar', 'IQ'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('ar', 'IQ'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      // جعل شاشة البداية المتحركة هي الواجهة الافتتاحية للتطبيق
      home: const IntroScreen(),
    );
  }
}
