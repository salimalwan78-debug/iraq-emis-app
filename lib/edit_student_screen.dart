import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_core.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/getstudent/${widget.studentId}');
    try {
      final response = await http.get(url, headers: {'Authorization': widget.token, 'Accept': 'application/json'});
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _studentData = jsonDecode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': widget.token, 'Content-Type': 'application/json'},
        body: jsonEncode(_studentData),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحفظ! تأكد من المدخلات'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في الاتصال'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, currentMode, child) {
        bool isDark = currentMode == ThemeMode.dark;
        Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        Color textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: const Text('تعديل بيانات الطالب', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1A237E), iconTheme: const IconThemeData(color: Colors.white)),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : _studentData == null 
              ? const Center(child: Text('فشل جلب البيانات')) 
              : _buildForm(cardColor, textColor, isDark),
        );
      }
    );
  }

  Widget _buildForm(Color cardColor, Color textColor, bool isDark) {
    final address = _studentData!['address'] ?? {};
    final ident = _studentData!['identification'] ?? {};
    String imgUrl = _studentData!['imageUrl'] ?? '';
    if (imgUrl.isNotEmpty && !imgUrl.startsWith('http')) imgUrl = 'https://emis.moedu.gov.iq$imgUrl';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              // صورة الطالب
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 3)),
                      child: ClipOval(child: imgUrl.isNotEmpty ? Image.network(imgUrl, headers: {'Authorization': widget.token}, fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.person, size: 80, color: textColor)) : Icon(Icons.person, size: 80, color: textColor)),
                    ),
                    Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue, radius: 20, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18), onPressed: () {}))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              _buildSection('الاسم الكامل', Icons.person, cardColor, textColor, isDark, [
                _buildField('الاسم الأول', _studentData!['name'], (v) => _studentData!['name'] = v, isDark, textColor),
                _buildField('اسم الأب', _studentData!['fatherName'], (v) => _studentData!['fatherName'] = v, isDark, textColor),
                _buildField('اسم الجد', _studentData!['grandFatherName'], (v) => _studentData!['grandFatherName'] = v, isDark, textColor),
                _buildField('اسم أب الجد', _studentData!['fathersGrandFatherName'], (v) => _studentData!['fathersGrandFatherName'] = v, isDark, textColor),
                _buildField('اللقب', _studentData!['surName'], (v) => _studentData!['surName'] = v, isDark, textColor),
              ]),

              _buildSection('معلومات الأم', Icons.pregnant_woman, cardColor, textColor, isDark, [
                _buildField('اسم الأم', _studentData!['motherName'], (v) => _studentData!['motherName'] = v, isDark, textColor),
                _buildField('اسم أب الأم', _studentData!['mothersFatherName'], (v) => _studentData!['mothersFatherName'] = v, isDark, textColor),
                _buildField('اسم جد الأم', _studentData!['mothersGrandFatherName'], (v) => _studentData!['mothersGrandFatherName'] = v, isDark, textColor),
              ]),

              _buildSection('المرحلة والشعبة (الصف الدراسي)', Icons.school, cardColor, textColor, isDark, [
                _buildDropdown('الصف الدراسي', _studentData!['stageName'], ['الأول إبتدائي','الثاني إبتدائي','الثالث إبتدائي','الأول متوسط','الثاني متوسط','الثالث متوسط','الرابع إعدادي','الخامس إعدادي','السادس إعدادي'], (v) => _studentData!['stageName'] = v, isDark, textColor),
                _buildDropdown('الشعبة', _studentData!['classRoomName'] ?? 'أ', ['أ', 'ب', 'ج', 'د', 'هـ'], (v) => _studentData!['classRoomName'] = v, isDark, textColor),
              ]),

              _buildSection('المعلومات العامة والهوية', Icons.badge, cardColor, textColor, isDark, [
                _buildField('رقم الهوية', ident['idNumber'], (v) => ident['idNumber'] = v, isDark, textColor),
                _buildDropdown('نوع الهوية', ident['idType']?.toString() ?? '12', ['12', '13', '14'], (v) => ident['idType'] = int.tryParse(v!), isDark, textColor), // 12 للبطاقة الموحدة عادة
                _buildDropdown('الديانة', _studentData!['religion'] ?? 'الإسلام', ['الإسلام', 'المسيحية', 'الصابئة', 'أخرى'], (v) => _studentData!['religion'] = v, isDark, textColor),
                _buildDropdown('فصيلة الدم', _studentData!['bloodGroup'] ?? 'O+', ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'], (v) => _studentData!['bloodGroup'] = v, isDark, textColor),
                _buildField('تاريخ الميلاد', _studentData!['dateOfBirth'], (v) => _studentData!['dateOfBirth'] = v, isDark, textColor),
              ]),

              _buildSection('معلومات السكن', Icons.home, cardColor, textColor, isDark, [
                _buildField('المحافظة', address['town'], (v) => address['town'] = v, isDark, textColor),
                _buildField('أقرب نقطة دالة', address['closestLocation'], (v) => address['closestLocation'] = v, isDark, textColor),
                _buildField('المحلة', address['quarter'], (v) => address['quarter'] = v, isDark, textColor),
                _buildField('الشارع', address['street'], (v) => address['street'] = v, isDark, textColor),
                _buildField('رقم الهاتف', _studentData!['homePhoneNumber'], (v) => _studentData!['homePhoneNumber'] = v, isDark, textColor),
              ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15), color: cardColor,
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveStudentData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التعديلات', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, Color cardColor, Color textColor, bool isDark, List<Widget> children) {
    return Card(
      color: cardColor, margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.blue), const SizedBox(width: 10), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))]),
            const SizedBox(height: 15),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, dynamic value, Function(String) onChanged, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value?.toString() ?? '', onChanged: onChanged, style: TextStyle(color: textColor),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: isDark ? Colors.black12 : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged, bool isDark, Color textColor) {
    if (!items.contains(value) && value.isNotEmpty) items.add(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first, onChanged: onChanged, dropdownColor: isDark ? Colors.grey[900] : Colors.white, style: TextStyle(color: textColor),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: isDark ? Colors.black12 : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      ),
    );
  }
}
