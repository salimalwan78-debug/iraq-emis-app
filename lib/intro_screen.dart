import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _emisAnimation;
  late Animation<Offset> _studentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // حركة كلمة EMIS من اليسار إلى المنتصف
    _emisAnimation = Tween<Offset>(
      begin: const Offset(-2.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // حركة الطالب من اليمين إلى المنتصف
    _studentAnimation = Tween<Offset>(
      begin: const Offset(2.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // بدء الحركة فور فتح الشاشة
    _controller.forward();

    // الانتقال التلقائي إلى لوحة التحكم (Dashboard) بعد 4 ثوانٍ
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB), // خلفية دافئة مشابهة لتصميم الفيديو
      body: SafeArea(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // كلمة EMIS القادمة من اليسار[span_1](start_span)[span_1](end_span)
              SlideTransition(
                position: _emisAnimation,
                child: const Text(
                  'EMIS',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    letterSpacing: 3,
                  ),
                ),
              ),
              // شخصية الطالب القادمة من اليمين[span_2](start_span)[span_2](end_span) (يمكن استبدالها بصورة لاحقاً)
              SlideTransition(
                position: _studentAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 70,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
