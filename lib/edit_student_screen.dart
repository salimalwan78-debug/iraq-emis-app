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
  Map<String, dynamic>? _studentData;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/getstudent/${widget.studentId}');
    
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
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _studentData = decodedData;
            _isLoading = false;
          });
        }
      } else {
        _showError('حدث خطأ في جلب بيانات الطالب: ${response.statusCode}');
      }
    } catch (e) {
      _showError('فشل الاتصال بخادم الوزارة.');
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSectionCard(
                title: 'المعلومات الشخصية',
                icon: Icons.person,
                children: [
                  _buildTextField('الاسم الأول', _studentData!['name']),
                  _buildTextField('اسم الأب', _studentData!['fatherName']),
                  _buildTextField('اسم الجد', _studentData!['grandFatherName']),
                  _buildTextField('اسم أب الجد', _studentData!['fathersGrandFatherName']),
                  _buildTextField('اللقب', _studentData!['surName']),
                  const Divider(),
                  _buildTextField('اسم الأم', _studentData!['motherName']),
                  _buildTextField('اسم أب الأم', _studentData!['mothersFatherName']),
                  _buildTextField('اسم جد الأم', _studentData!['mothersGrandFatherName']),
                ],
              ),
              _buildSectionCard(
                title: 'المعلومات العامة',
                icon: Icons.info_outline,
                children: [
                  _buildTextField('تاريخ الميلاد', _studentData!['dateOfBirth']),
                  _buildTextField('الجنسية', _studentData!['nationality']),
                  _buildTextField('بلد الميلاد', _studentData!['countryOfBirth']),
                  _buildTextField('محل الولادة', _studentData!['homeTown']),
                  _buildTextField('الديانة', _studentData!['religion']),
                  _buildTextField('فصيلة الدم', _studentData!['bloodGroup']),
                  _buildTextField('اللغة الأم', _studentData!['motherTongue']),
                  _buildTextField('لغة الدراسة', _studentData!['studyLanguage']),
                  _buildTextField('الحالة الاجتماعية', _studentData!['maritalStatus']),
                  _buildTextField('المستوى الاقتصادي', _studentData!['economicLevel']),
                ],
              ),
              _buildSectionCard(
                title: 'معلومات الهوية',
                icon: Icons.badge,
                children: [
                  _buildTextField('رقم الهوية', identification['idNumber']),
                  _buildTextField('بلد الإصدار', identification['issuingCountry']),
                ],
              ),
              _buildSectionCard(
                title: 'معلومات الاتصال والسكن',
                icon: Icons.location_on,
                children: [
                  _buildTextField('رقم الهاتف المنزلي', _studentData!['homePhoneNumber']),
                  _buildTextField('رقم الموبايل', address['mobilePhoneNumber']),
                  _buildTextField('المحافظة / المدينة', address['town']),
                  _buildTextField('المنطقة', address['area']),
                  _buildTextField('المحلة / الحي', address['quarter']),
                  _buildTextField('الشارع', address['street']),
                  _buildTextField('أقرب نقطة دالة', address['closestLocation']),
                ],
              ),
              _buildSectionCard(
                title: 'ملاحظات وحالة الطالب',
                icon: Icons.note_alt,
                children: [
                  _buildTextField('حالة الطالب', _studentData!['studentStatusName']),
                  _buildTextField('ملاحظات', _studentData!['notes']),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم برمجة دالة الحفظ قريباً بناءً على طلبك')),
                );
              },
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0F172A)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 15),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
    );
  }
}
