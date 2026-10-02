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
    AppCore.playRelaxMusic(); // تشغيل الصوت الهادئ
    _startFetchingData();
  }

  // خوارزمية ذكية لاستخراج الاسم الحقيقي بدلاً من ali05.diw
  String _extractRealNameFromToken() {
    try {
      String jwt = widget.token.toLowerCase().startsWith('bearer ') ? widget.token.substring(7).trim() : widget.token;
      final parts = jwt.split('.');
      if (parts.length == 3) {
        String payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        Map<String, dynamic> data = jsonDecode(payload);
        
        String bestName = "مستخدم النظام";
        int maxLength = 0;
        final arabicRegex = RegExp(r'[\u0600-\u06FF]');
        
        // البحث عن أطول نص يحتوي على حروف عربية في التوكن (وهو دائماً الاسم الحقيقي)
        data.forEach((key, value) {
          if (value is String && arabicRegex.hasMatch(value) && value.length > maxLength) {
            maxLength = value.length;
            bestName = value;
          }
        });
        return bestName;
      }
    } catch (e) {
      debugPrint("Token Decode Error: $e");
    }
    return "مستخدم النظام";
  }

  Future<void> _startFetchingData() async {
    String authHeader = widget.token.toLowerCase().startsWith('bearer ') ? widget.token : 'Bearer ${widget.token}';
    final headers = {'Authorization': authHeader, 'Accept': 'application/json'};

    try {
      String realUserName = _extractRealNameFromToken();

      setState(() { _statusText = "جاري جلب بيانات المدرسة..."; _progressValue = 0.3; });
      final schoolRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}'), headers: headers);
      final schoolData = schoolRes.statusCode == 200 ? jsonDecode(utf8.decode(schoolRes.bodyBytes)) : {};

      setState(() { _statusText = "جاري تحميل سجلات الطلاب وتوزيعاتهم..."; _progressValue = 0.6; });
      final studentsRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/student/getstudents?page=1&rowsPerPage=3000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}'), headers: headers);
      final studentsData = studentsRes.statusCode == 200 ? jsonDecode(utf8.decode(studentsRes.bodyBytes))['data'] ?? [] : [];

      setState(() { _statusText = "جاري تحميل بيانات الكادر التعليمي..."; _progressValue = 0.9; });
      final teachersRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/employee/getemployeesbyentities?page=1&rowsPerPage=1000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}&isTeacher=true'), headers: headers);
      final teachersData = teachersRes.statusCode == 200 ? jsonDecode(utf8.decode(teachersRes.bodyBytes))['data'] ?? [] : [];

      setState(() { _statusText = "اكتمل التحميل بنجاح!"; _progressValue = 1.0; });
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              token: authHeader, schoolId: widget.schoolId, schoolName: schoolData['schoolName'] ?? 'مدرسة',
              userName: realUserName, allStudents: studentsData, allTeachers: teachersData,
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
              const Icon(Icons.school_rounded, size: 100, color: Colors.amber),
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
