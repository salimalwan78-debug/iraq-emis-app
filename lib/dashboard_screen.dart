import 'package:flutter/material.dart';
import 'edit_student_screen.dart';

class DashboardScreen extends StatelessWidget {
  // يمكنك تمرير هذه البيانات من شاشة تسجيل الدخول لاحقاً
  final String schoolName = "ثانوية الديوانية للمتميزين (1500799)";
  final String userName = "علي عيسى الفتلاوي";
  final String authToken = "YOUR_EXTRACTED_TOKEN"; // سيتم تعويضه بالتوكن المكتشف

  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم - EMIS'),
        backgroundColor: const Color(0xFF0F172A),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
              accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: Text(schoolName, style: const TextStyle(fontSize: 13, color: Colors.white70)),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.school, size: 40, color: Color(0xFF0F172A)),
              ),
            ),
            ExpansionTile(
              leading: const Icon(Icons.people_alt),
              title: const Text('الطلاب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: const Text('إضافة طالب جديد'),
                  onTap: () {
                    // الانتقال لشاشة الإضافة مستقبلاً
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('تعديل طالب'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditStudentScreen(token: authToken),
                      ),
                    );
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('المعلمون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                // الانتقال لشاشة المعلمين مستقبلاً
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dashboard_customize, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'مرحباً بك في $schoolName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
