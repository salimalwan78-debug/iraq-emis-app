import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart';
import 'app_core.dart';

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
    AppCore.playRelaxMusic();
    _startFetchingData();
  }

  Future<void> _startFetchingData() async {
    String authHeader = widget.token.toLowerCase().startsWith('bearer ') ? widget.token : 'Bearer ${widget.token}';
    final headers = {'Authorization': authHeader, 'Accept': 'application/json, text/plain, */*'};

    try {
      setState(() { _statusText = "جاري جلب بيانات الحساب..."; _progressValue = 0.2; });
      // جلب الاسم الحقيقي بناءً على تحليل السجلات التي أرفقتها
      String realUserName = "مستخدم النظام";
      final userRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/account/getloggedinuser'), headers: headers);
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(userRes.bodyBytes));
        realUserName = userData['employeeName'] ?? userData['fullName'] ?? realUserName;
      }

      setState(() { _statusText = "جاري جلب بيانات المدرسة..."; _progressValue = 0.4; });
      final schoolRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}'), headers: headers);
      final schoolData = schoolRes.statusCode == 200 ? jsonDecode(utf8.decode(schoolRes.bodyBytes)) : {};

      setState(() { _statusText = "جاري تحميل سجلات الطلاب..."; _progressValue = 0.7; });
      final studentsRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/student/getstudents?page=1&rowsPerPage=3000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}'), headers: headers);
      final studentsData = studentsRes.statusCode == 200 ? jsonDecode(utf8.decode(studentsRes.bodyBytes))['data'] ?? [] : [];

      setState(() { _statusText = "جاري إعداد بيئة العمل..."; _progressValue = 0.9; });
      final teachersRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/employee/getemployeesbyentities?page=1&rowsPerPage=1000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}&isTeacher=true'), headers: headers);
      final teachersData = teachersRes.statusCode == 200 ? jsonDecode(utf8.decode(teachersRes.bodyBytes))['data'] ?? [] : [];

      setState(() { _statusText = "اكتمل التحميل بنجاح!"; _progressValue = 1.0; });
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              token: authHeader, schoolId: widget.schoolId, schoolName: schoolData['schoolName'] ?? 'المدرسة',
              userName: realUserName, allStudents: studentsData, allTeachers: teachersData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _statusText = "حدث خطأ. تحقق من الشبكة"; });
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
              // استخدام صورة avatar.png (بدون خلفية)
              Image.asset('assets/avatar.png', width: 140, height: 140, fit: BoxFit.contain),
              const SizedBox(height: 30),
              const Text('نظام الإدارة المدرسية - EMIS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
