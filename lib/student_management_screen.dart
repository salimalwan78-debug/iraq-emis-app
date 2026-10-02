import 'package:flutter/material.dart';
import 'select_student_screen.dart';

class StudentManagementScreen extends StatelessWidget {
  final String token;
  final String schoolId;
  final List<dynamic> allStudents;

  const StudentManagementScreen({super.key, required this.token, required this.schoolId, required this.allStudents});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('إدارة الطلاب', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildListTileCard(
              title: 'تعديل بيانات الطلاب',
              subtitle: 'ابحث عن طالب وقم بتحديث بياناته ومرحلته',
              icon: Icons.edit_document,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SelectStudentScreen(token: token, schoolId: schoolId, preLoadedStudents: allStudents)));
              },
            ),
            const SizedBox(height: 15),
            _buildListTileCard(
              title: 'إضافة طالب جديد',
              subtitle: 'تسجيل طالب جديد في المدرسة',
              icon: Icons.person_add_alt_1,
              color: Colors.green,
              onTap: () {
                // سيتم برمجتها لاحقاً
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTileCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 30),
        ),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
