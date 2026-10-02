import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart';

class LoadingDataScreen extends StatefulWidget {
  final String token;
  final String schoolId;

  const LoadingDataScreen({super.key, required this.token, required this.schoolId});

  @override
  State<LoadingDataScreen> createState() => _LoadingDataScreenState();
}

class _LoadingDataScreenState extends State<LoadingDataScreen> {
  String _statusText = "جاري الاتصال بخوادم الوزارة...";
  double _progressValue = 0.1;

  @override
  void initState() {
    super.initState();
    _startFetchingData();
  }

  Future<void> _startFetchingData() async {
    String authHeader = widget.token.toLowerCase().startsWith('bearer ') ? widget.token : 'Bearer ${widget.token}';
    final headers = {'Authorization': authHeader, 'Accept': 'application/json, text/plain, */*'};

    try {
      // 1. استخراج معرف الدخول من التوكن (مثل ali05.diw)
      String loginId = "مستخدم النظام";
      String jwt = authHeader.substring(7).trim();
      final parts = jwt.split('.');
      if (parts.length == 3) {
        String payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        Map<String, dynamic> data = jsonDecode(payload);
        loginId = data['unique_name'] ?? data['name'] ?? loginId;
      }

      // 2. جلب بيانات المدرسة
      setState(() { _statusText = "جاري جلب بيانات المدرسة..."; _progressValue = 0.3; });
      final schoolRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}'), headers: headers);
      final schoolData = schoolRes.statusCode == 200 ? jsonDecode(utf8.decode(schoolRes.bodyBytes)) : {};

      // 3. جلب سجلات الطلاب
      setState(() { _statusText = "جاري تحميل سجلات الطلاب وتوزيعاتهم..."; _progressValue = 0.6; });
      final studentsRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/student/getstudents?page=1&rowsPerPage=3000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}'), headers: headers);
      final studentsData = studentsRes.statusCode == 200 ? jsonDecode(utf8.decode(studentsRes.bodyBytes))['data'] ?? [] : [];

      // 4. جلب الكادر التعليمي واستخراج الاسم الحقيقي
      setState(() { _statusText = "جاري معالجة بيانات الحساب..."; _progressValue = 0.8; });
      final teachersRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/employee/getemployeesbyentities?page=1&rowsPerPage=1000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}&isTeacher=true'), headers: headers);
      final teachersData = teachersRes.statusCode == 200 ? jsonDecode(utf8.decode(teachersRes.bodyBytes))['data'] ?? [] : [];

      // البحث عن الاسم العربي الحقيقي بمطابقة معرف الدخول مع بيانات المعلمين
      String realUserName = loginId;
      for (var teacher in teachersData) {
        if (teacher['createdByUser'] == loginId || teacher['updatedByUser'] == loginId) {
          realUserName = teacher['employeeFullName'] ?? realUserName;
          break;
        }
      }

      setState(() { _statusText = "اكتمل التحميل بنجاح!"; _progressValue = 1.0; });
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              token: authHeader,
              schoolId: widget.schoolId,
              schoolName: schoolData['schoolName'] ?? 'مدرسة غير معروفة',
              userName: realUserName,
              allStudents: studentsData,
              allTeachers: teachersData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _statusText = "حدث خطأ أثناء التحميل: يرجى التحقق من الشبكة"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 40),
              LinearProgressIndicator(value: _progressValue, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent), minHeight: 6, borderRadius: BorderRadius.circular(10)),
              const SizedBox(height: 20),
              Text(_statusText, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
