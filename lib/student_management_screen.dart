import 'package:flutter/material.dart';
import 'select_student_screen.dart';
import 'app_core.dart';

class StudentManagementScreen extends StatelessWidget {
  final String token;
  final String schoolId;
  final List<dynamic> allStudents;

  const StudentManagementScreen({super.key, required this.token, required this.schoolId, required this.allStudents});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, currentMode, child) {
        bool isDark = currentMode == ThemeMode.dark;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
          appBar: AppBar(title: const Text('إدارة الطلاب', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1A237E), iconTheme: const IconThemeData(color: Colors.white)),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildCard(context, 'تعديل بيانات الطلاب', 'تعديل الصف، الشعبة، السكن، والصورة', Icons.edit_document, Colors.indigo, isDark, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SelectStudentScreen(token: token, schoolId: schoolId, preLoadedStudents: allStudents)));
                }),
                const SizedBox(height: 15),
                _buildCard(context, 'إضافة طالب جديد', 'إضافة سجل طالب جديد كلياً للمدرسة', Icons.person_add, Colors.green, isDark, () {}),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildCard(BuildContext context, String title, String sub, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(15),
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 30)),
          title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          subtitle: Text(sub, style: const TextStyle(color: Colors.grey)),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.black54),
        ),
      ),
    );
  }
}
