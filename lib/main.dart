import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'intro_screen.dart'; // استدعاء شاشة الفيديو الافتتاحية

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
      // الخطأ كان هنا: تم تصحيحه ليوجه التطبيق إلى شاشة البداية الفعلية
      home: const IntroScreen(),
    );
  }
}
