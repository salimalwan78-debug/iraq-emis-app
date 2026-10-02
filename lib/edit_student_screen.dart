import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditStudentScreen extends StatefulWidget {
  final String token;
  const EditStudentScreen({super.key, required this.token});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _studentData;
  final TextEditingController _studentIdController = TextEditingController(text: '951625');

  // دالة جلب بيانات الطالب بناءً على تحليل ملف الـ HAR
  Future<void> fetchStudentData(String studentId) async {
    setState(() => _isLoading = true);

    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/getstudent/$studentId');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': widget.token, // التوكن الذي تم اصطياده
          'Accept': 'application/json, text/plain, */*',
        },
      );

      if (response.statusCode == 200) {
        // فك تشفير الحروف العربية بشكل صحيح
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _studentData = decodedData;
          _isLoading = false;
        });
      } else {
        _showError('حدث خطأ في جلب البيانات: ${response.statusCode}');
      }
    } catch (e) {
      _showError('فشل الاتصال بالخادم: $e');
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل بيانات طالب'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // حقل البحث عن الطالب برقم المعرف
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentIdController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الطالب (ID)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => fetchStudentData(_studentIdController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text('جلب البيانات', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            // عرض حالة التحميل أو البيانات
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_studentData != null)
              Expanded(
                child: ListView(
                  children: [
                    _buildDataField('الاسم الأول', _studentData!['name']),
                    _buildDataField('اسم الأب', _studentData!['fatherName']),
                    _buildDataField('اسم الجد', _studentData!['grandFatherName']),
                    _buildDataField('اللقب', _studentData!['surName']),
                    _buildDataField('رقم الهوية', _studentData!['identification']?['idNumber'] ?? 'غير متوفر'),
                    _buildDataField('رقم الهاتف', _studentData!['homePhoneNumber'] ?? 'غير متوفر'),
                    const SizedBox(height: 20),
