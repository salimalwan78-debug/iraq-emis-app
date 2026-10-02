import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditStudentScreen extends StatefulWidget {
  final String token;
  final String studentId;

  const EditStudentScreen({super.key, required this.token, required this.studentId});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _studentData;
  
  // الخيارات المستخرجة للقوائم
  List<dynamic> _stagesOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  String get authHeader => widget.token.toLowerCase().startsWith('bearer ') ? widget.token : 'Bearer ${widget.token}';

  Future<void> _fetchStudentData() async {
    final studentUrl = Uri.parse('https://emis.moedu.gov.iq/api/student/getstudent/${widget.studentId}');
    final optionsUrl = Uri.parse('https://emis.moedu.gov.iq/api/selectoption/getAvailableStagesForStudent?schoolId='); // يحتاج دمج رقم المدرسة للعمل بالكامل

    try {
      final response = await http.get(studentUrl, headers: {'Authorization': authHeader, 'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _studentData = decodedData;
            _isLoading = false;
          });
        }
      } else {
        _showError('خطأ في الجلب: ${response.statusCode}');
      }
    } catch (e) {
      _showError('فشل الاتصال بخادم الوزارة.');
    }
  }

  // دالة الحفظ وإرسال التحديثات للسيرفر
  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);
    
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*',
        },
        body: jsonEncode(_studentData), // إرسال نفس الكائن بعد تعديله محلياً
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح!'), backgroundColor: Colors.green));
          Navigator.pop(context); // العودة بعد الحفظ
        }
      } else {
        _showError('فشل الحفظ. تأكد من صحة البيانات.');
      }
    } catch (e) {
      _showError('فشل الاتصال بخادم الوزارة أثناء الحفظ.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() { _isLoading = false; _isSaving = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('تعديل بيانات الطالب', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentData == null
              ? const Center(child: Text('تعذر تحميل بيانات الطالب'))
              : _buildStudentForm(),
    );
  }

  Widget _buildStudentForm() {
    final address = _studentData!['address'] ?? {};
    final identification = _studentData!['identification'] ?? {};
    
    // معالجة رابط الصورة
    String imageUrl = _studentData!['imageUrl'] ?? '';
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = 'https://emis.moedu.gov.iq$imageUrl';
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // عرض صورة الطالب
              if (imageUrl.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        imageUrl,
                        headers: {'Authorization': authHeader},
                        fit: BoxFit.cover,
                        errorBuilder: (c, o, s) => const Icon(Icons.person, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

              _buildSectionCard(
                title: 'المعلومات الشخصية', icon: Icons.person,
                children: [
                  _buildTextField('الاسم الأول', _studentData!['name'], (val) => _studentData!['name'] = val),
                  _buildTextField('اسم الأب', _studentData!['fatherName'], (val) => _studentData!['fatherName'] = val),
                  _buildTextField('اسم الجد', _studentData!['grandFatherName'], (val) => _studentData!['grandFatherName'] = val),
                  _buildTextField('اللقب', _studentData!['surName'], (val) => _studentData!['surName'] = val),
                  _buildTextField('اسم الأم', _studentData!['motherName'], (val) => _studentData!['motherName'] = val),
                ],
              ),
              _buildSectionCard(
                title: 'المعلومات العامة والأكاديمية', icon: Icons.school,
                children: [
                  _buildTextField('المرحلة (الصف)', _studentData!['stageName'], (val) => _studentData!['stageName'] = val),
                  _buildTextField('الشعبة', _studentData!['classRoomName'], (val) => _studentData!['classRoomName'] = val),
                  _buildTextField('الديانة', _studentData!['religion'], (val) => _studentData!['religion'] = val),
                  _buildTextField('فصيلة الدم', _studentData!['bloodGroup'], (val) => _studentData!['bloodGroup'] = val),
                  _buildTextField('اللغة الأم', _studentData!['motherTongue'], (val) => _studentData!['motherTongue'] = val),
                ],
              ),
              _buildSectionCard(
                title: 'معلومات السكن والهوية', icon: Icons.location_city,
                children: [
                  _buildTextField('رقم الهوية', identification['idNumber'], (val) => identification['idNumber'] = val),
                  _buildTextField('المحافظة', address['town'], (val) => address['town'] = val),
                  _buildTextField('المنطقة', address['area'], (val) => address['area'] = val),
                  _buildTextField('الشارع', address['street'], (val) => address['street'] = val),
                  _buildTextField('رقم الموبايل', address['mobilePhoneNumber'], (val) => address['mobilePhoneNumber'] = val),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))]),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveStudentData, // تنفيذ الحفظ الحقيقي
              icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save, color: Colors.white),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التعديلات', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15), elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: const Color(0xFF0F172A)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))]),
            const SizedBox(height: 15),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, dynamic value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        onChanged: onChanged, // تحديث القيمة في الخريطة محلياً عند الكتابة
        decoration: InputDecoration(
          labelText: label, labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          filled: true, fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }
}
