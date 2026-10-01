٥import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dashboard_screen.dart';

class EmisWebviewScreen extends StatefulWidget {
  const EmisWebviewScreen({super.key});

  @override
  State<EmisWebviewScreen> createState() => _EmisWebviewScreenState();
}

class _EmisWebviewScreenState extends State<EmisWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://emis.moedu.gov.iq'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'بوابة تسجيل الدخول - EMIS الرسمية',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
        actions: [
          // زر تحديث الصفحة
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.reload(),
          ),
          // زر الانتقال إلى لوحة تحكم التطبيق بعد إتمام تسجيل الدخول بنجاح
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            tooltip: 'الدخول إلى التطبيق بعد تسجيل الدخول',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
