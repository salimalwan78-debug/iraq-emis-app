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
  String _errorMessage = "";
  
  // المتغيرات الديناميكية
  String schoolName = "";
  String schoolCensus = "";
  String studentsCount = "0";
  String teachersCount = "0";
  String userName = "مستخدم النظام";

  @override
  void initState() {
    super.initState();
    _extractUserNameFromToken();

    // نتحقق من وجود التوكن ورقم المدرسة قبل البدء بالجلب
    if (widget.schoolId.isNotEmpty && widget.token.isNotEmpty) {
      _fetchDashboardData();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "بيانات الدخول غير مكتملة. يرجى تسجيل الدخول من جديد.";
        });
      }
    }
  }

  // فك تشفير التوكن (JWT) واستخراج اسم المستخدم (مثلاً: ali05.diw)
  void _extractUserNameFromToken() {
    try {
      String jwt = widget.token;
      if (jwt.toLowerCase().startsWith('bearer ')) {
        jwt = jwt.substring(7).trim();
      }

      final parts = jwt.split('.');
      if (parts.length == 3) {
        String normalized = base64Url.normalize(parts[1]);
        String payload = utf8.decode(base64Url.decode(normalized));
        Map<String, dynamic> payloadMap = jsonDecode(payload);

        if (mounted) {
          setState(() {
            userName = payloadMap['name'] ??
                       payloadMap['unique_name'] ??
                       payloadMap['preferred_username'] ??
                       payloadMap['given_name'] ??
                       "مستخدم النظام";
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في فك تشفير التوكن: $e');
    }
  }

  // جلب إحصائيات المدرسة من السيرفر
  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final url = Uri.parse('https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}');

    // حل المشكلة الجذرية لخطأ 401: التأكد من وجود كلمة Bearer قبل إرسال التوكن للسيرفر
    String authHeader = widget.token.toLowerCase().startsWith('bearer ')
        ? widget.token
        : 'Bearer ${widget.token}';

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': authHeader,
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
            _isLoading = false; // البيانات اكتملت بنجاح
          });
        }
      } else if (response.statusCode == 401) {
        _showError('غير مصرح (401): انتهت صلاحية الجلسة أو التوكن غير صالح.');
      } else {
        _showError('حدث خطأ في جلب الإحصائيات: ${response.statusCode}');
      }
    } catch (e) {
      _showError('فشل الاتصال بخادم الوزارة. الرجاء التحقق من الإنترنت.');
    }
  }

  // دالة إظهار الخطأ في الشاشة ومنع عرض واجهة التحكم
  void _showError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
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
      body: _buildBody(),
    );
  }

  // دالة بناء محتوى الشاشة بناءً على الحالة (تحميل، خطأ، أو نجاح)
  Widget _buildBody() {
    // 1. حالة التحميل
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري جلب البيانات والإحصائيات المدرسية...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // 2. حالة الفشل (لا تظهر أزرار التحكم نهائياً)
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 80),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
              )
            ],
          ),
        ),
      );
    }

    // 3. حالة النجاح (تظهر لوحة التحكم التفاعلية)
    return SafeArea(
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
