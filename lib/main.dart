import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'loading_data_screen.dart'; // أو intro_screen.dart حسب نقطة البداية لديك

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تفعيل وضع ملء الشاشة (إخفاء أشرطة النظام العلوية والسفلية)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iraq EMIS',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'IQ'),
      ],
      locale: const Locale('ar', 'IQ'),
      theme: ThemeData(
        fontFamily: 'Tajawal',
        primarySwatch: Colors.blue,
      ),
      home: const Scaffold(body: Center(child: Text('بوابة الدخول'))), // استبدلها بشاشة البداية لديك
    );
  }
}
