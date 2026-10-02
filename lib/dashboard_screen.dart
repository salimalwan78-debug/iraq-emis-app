import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'edit_student_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String token;
  final String schoolId;

  const DashboardScreen({super.key, required this.token, required this.schoolId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  
  // المتغيرات هنا أصبحت ديناميكية وتنتظر البيانات من السيرفر (بدون كلمة final)
  String schoolName = "جاري التحميل...";
  String schoolCensus = "";
  String studentsCount = "0";
  String teachersCount = "0";
  String userName = "جاري القراءة..."; 

  @override
  void initState() {
    super.initState();
    _extractUserNameFromToken(); 
    
    if (widget.schoolId.isNotEmpty) {
      _fetchDashboardData();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة لفك تشفير التوكن (JWT) واستخراج اسم المستخدم محلياً
  void _extractUserNameFromToken() {
    try {
      String jwt = widget.token;
      if (jwt.toLowerCase().startsWith('bearer ')) {
        jwt = jwt.substring(7).trim();
      }
      
      final parts = jwt.split('.');
      if (parts.length == 3) {
        final String normalized = base64Url.normalize(parts[1]);
        final String payload = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> payloadMap = jsonDecode(payload);
        
        if (mounted) {
          setState(() {
            userName = payloadMap['name'] ?? 
                       payloadMap['unique_name'] ?? 
                       payloadMap['preferred_username'] ?? 
                       payloadMap['given_name'] ?? 
                       "مستخدم النظام";
          });
        }
      } else {
        if (mounted) setState(() => userName = "مستخدم النظام");
      }
    } catch (e) {
      debugPrint('خطأ في فك تشفير التوكن: $e');
      if (mounted) setState(() => userName = "مستخدم النظام");
    }
  }

  // دالة جلب اسم المدرسة وعدد الطلاب والمعلمين من سيرفر الوزارة بناءً على رقم المدرسة المكتشف
  Future<void> _fetchDashboardData() async {
    final url = Uri.parse('https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': widget.token,
          'Accept': 'application/json, text/plain, */*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            schoolName = data['schoolName'] ?? 'مدرسة غير معروفة';
            schoolCensus = data['sensusNumber'] ?? widget.schoolId;
            studentsCount = (data['totalStudents'] ?? 0).toString();
            teachersCount = (data['totalTeachers'] ?? 0).toString();
            _isLoading = false;
          });
        }
      } else {
        _showError('حدث خطأ في جلب الإحصائيات: ${response.statusCode}');
      }
    } catch (e) {
      _showError('فشل الاتصال بخادم الوزارة');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('نظام الإدارة المدرسية - EMIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.person, size: 35, color: Colors.white),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('مرحباً أستاذ،', style: TextStyle(color: Colors.blue[200], fontSize: 14)),
                                  Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.school, color: Colors.amber, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$schoolName ($schoolCensus)',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildStatCard('إجمالي الطلاب', studentsCount, Icons.people, Colors.blue),
                          const SizedBox(width: 15),
                          _buildStatCard('إجمالي المعلمين', teachersCount, Icons.work, Colors.orange),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('إدارة الطلاب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildActionCard(
                            title: 'تعديل طالب',
                            icon: Icons.edit_document,
                            color: Colors.indigo,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => EditStudentScreen(token: widget.token)),
                              );
                            },
                          ),
                          const SizedBox(width: 15),
                          _buildActionCard(
                            title: 'إضافة طالب',
                            icon: Icons.person_add_alt_1,
                            color: Colors.green,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('إدارة المعلمين', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildActionCard(
                            title: 'قائمة المعلمين',
                            icon: Icons.recent_actors,
                            color: Colors.deepPurple,
                            onTap: () {},
                          ),
                          const SizedBox(width: 15),
                          Expanded(child: Container()), 
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
