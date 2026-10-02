var foundToken = searchStorage(localStorage) || searchStorage(sessionStorage);
        
        // إذا اكتشفنا المدرسة والـ Token، نرسلها لفلاتر عبر القناة
        if (schoolMatch && foundToken) {
            AuthChannel.postMessage(JSON.stringify({
                schoolId: schoolMatch[1],
                token: foundToken
            }));
        }
      })();
    ''';
    
    _controller.runJavaScript(jsCode);
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.reload(),
          ),
          // أبقينا الزر اليدوي كخطة بديلة (Fallback) في حال تأخر السكربت
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            tooltip: 'تخطي للوحة التحكم',
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
