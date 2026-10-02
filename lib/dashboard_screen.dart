import 'package:flutter/material.dart';
import 'student_management_screen.dart';
import 'teachers_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String token;
  final String schoolId;
  final String schoolName;
  final String userName;
  final List<dynamic> allStudents;
  final List<dynamic> allTeachers;

  const DashboardScreen({
    super.key,
    required this.token,
    required this.schoolId,
    required this.schoolName,
    required this.userName,
    required this.allStudents,
    required this.allTeachers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // لون خلفية هادئ
      body: Column(
        children: [
          // الترويسة العلوية بتصميم السماء
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF87CEEB)], // تدرج لوني أزرق سماوي
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // صورة التلميذ (الـ Avatar)
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/avatar.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // بيانات المستخدم والمدرسة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صباح الخير', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(userName, style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school, color: Colors.amber, size: 18),
                            const SizedBox(width: 5),
                            Flexible(child: Text(schoolName, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.settings, color: Colors.white, size: 28),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // شبكة الأزرار المركزية
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.9,
              children: [
                _buildMenuCard(
                  title: 'إدارة الطلاب',
                  icon: Icons.people_alt_rounded,
                  color: Colors.orange,
                  onTap: () {
                    // الانتقال لصفحة إدارة الطلاب المستقلة
                    Navigator.push(context, MaterialPageRoute(builder: (context) => StudentManagementScreen(token: token, schoolId: schoolId, allStudents: allStudents)));
                  },
                ),
                _buildMenuCard(
                  title: 'إدارة المعلمين',
                  icon: Icons.work_rounded,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachersListScreen()));
                  },
                ),
                _buildMenuCard(title: 'الدرجات', icon: Icons.bar_chart_rounded, color: Colors.indigo, onTap: () {}),
                _buildMenuCard(title: 'إرسال البيانات', icon: Icons.cloud_upload_rounded, color: Colors.green, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), spreadRadius: 2, blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 45, color: color),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
