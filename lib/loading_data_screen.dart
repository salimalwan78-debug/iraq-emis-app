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

  // خوارزمية ذكية لاستخراج الاسم العربي الحقيقي من التوكن
  String _extractRealNameFromToken() {
    try {
      String jwt = widget.token.toLowerCase().startsWith('bearer ') ? widget.token.substring(7).trim() : widget.token;
      final parts = jwt.split('.');
      if (parts.length == 3) {
        String payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        Map<String, dynamic> data = jsonDecode(payload);
        
        // البحث عن أي قيمة تحتوي على حروف عربية (الاسم الحقيقي)
        final arabicRegex = RegExp(r'[\u0600-\u06FF]');
        for (var value in data.values) {
          if (value is String && arabicRegex.hasMatch(value)) {
            return value; 
          }
        }
        return data['unique_name'] ?? data['name'] ?? "مستخدم النظام";
      }
    } catch (e) {
      debugPrint("خطأ في فك التوكن: $e");
    }
    return "مستخدم النظام";
  }

  Future<void> _startFetchingData() async {
    String authHeader = widget.token.toLowerCase().startsWith('bearer ') ? widget.token : 'Bearer ${widget.token}';
    final headers = {'Authorization': authHeader, 'Accept': 'application/json, text/plain, */*'};

    try {
      String realUserName = _extractRealNameFromToken();

      setState(() { _statusText = "جاري جلب بيانات المدرسة..."; _progressValue = 0.4; });
      final schoolRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/school/getschoolinformation/${widget.schoolId}'), headers: headers);
      if (schoolRes.statusCode != 200 && schoolRes.statusCode != 204) throw Exception("فشل جلب بيانات المدرسة");
      final schoolData = schoolRes.body.isNotEmpty ? jsonDecode(utf8.decode(schoolRes.bodyBytes)) : {};

      setState(() { _statusText = "جاري تحميل سجلات الطلاب وتوزيعاتهم..."; _progressValue = 0.7; });
      final studentsRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/student/getstudents?page=1&rowsPerPage=3000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}'), headers: headers);
      if (studentsRes.statusCode != 200 && studentsRes.statusCode != 204) throw Exception("فشل جلب سجلات الطلاب");
      final studentsData = studentsRes.body.isNotEmpty ? jsonDecode(utf8.decode(studentsRes.bodyBytes))['data'] ?? [] : [];

      setState(() { _statusText = "جاري تحميل بيانات الكادر التعليمي..."; _progressValue = 0.9; });
      final teachersRes = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/employee/getemployeesbyentities?page=1&rowsPerPage=1000&sortBy=id&sortOrder=desc&entityId=${widget.schoolId}&isTeacher=true'), headers: headers);
      if (teachersRes.statusCode != 200 && teachersRes.statusCode != 204) throw Exception("فشل جلب سجلات المعلمين");
      final teachersData = teachersRes.body.isNotEmpty ? jsonDecode(utf8.decode(teachersRes.bodyBytes))['data'] ?? [] : [];

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
              schoolCensus: schoolData['sensusNumber'] ?? widget.schoolId,
              userName: realUserName,
              allStudents: studentsData,
              allTeachers: teachersData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _statusText = "حدث خطأ أثناء التحميل: يرجى التحقق من الشبكة وإعادة تسجيل الدخول"; });
      }
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
              const Text(
                'نظام الإدارة المدرسية - EMIS',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
