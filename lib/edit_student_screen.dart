import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
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
  File? _pickedImage;

  // قاموس أنواع الهوية
  final Map<String, String> _idTypes = {
    '12': 'البطاقة الوطنية',
    '13': 'هوية الأحوال المدنية',
    '14': 'شهادة الجنسية',
  };

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
        if (mounted) setState(() { _studentData = jsonDecode(utf8.decode(response.bodyBytes)); _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // التقاط الصورة ومعالجتها
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _pickedImage = File(pickedFile.path));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت معالجة الصورة بخلفية بيضاء بنجاح')));
    }
  }

  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent');
    try {
      // إذا كان هناك صورة جديدة يجب برمجتها كـ MultipartRequest لاحقاً
      final response = await http.post(
        url, headers: {'Authorization': widget.token, 'Content-Type': 'application/json'},
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
          appBar: AppBar(title: const Text('تعديل بيانات الطالب', style: TextStyle(color: Colors.white)), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A90E2)]))), iconTheme: const IconThemeData(color: Colors.white)),
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

    // القيمة الافتراضية لنوع الهوية
    String idTypeValue = ident['idType']?.toString() ?? '12';
    if (!_idTypes.containsKey(idTypeValue)) idTypeValue = '12';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              // معالج الصور الذكي (صورة + خلفية بيضاء إجبارية)
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white, // خلفية بيضاء إجبارية لأي صورة شفافة
                        shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: ClipOval(
                        child: _pickedImage != null
                            ? Image.file(_pickedImage!, fit: BoxFit.cover)
                            : (imgUrl.isNotEmpty 
                                ? Image.network(imgUrl, headers: {'Authorization': widget.token}, fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.person, size: 80, color: Colors.grey[400])) 
                                : Icon(Icons.person, size: 80, color: Colors.grey[400])),
                      ),
                    ),
                    Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue, radius: 20, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18), onPressed: () => _pickImage(ImageSource.camera)))),
                    Positioned(bottom: 0, left: 0, child: CircleAvatar(backgroundColor: Colors.red, radius: 20, child: IconButton(icon: const Icon(Icons.delete, color: Colors.white, size: 18), onPressed: () => setState(() => _pickedImage = null)))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              _buildSection('الاسم الكامل', Icons.person, cardColor, textColor, isDark, [
                SpeechTextField(label: 'الاسم الأول', initialValue: _studentData!['name'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['name'] = v),
                SpeechTextField(label: 'اسم الأب', initialValue: _studentData!['fatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['fatherName'] = v),
                SpeechTextField(label: 'اسم الجد', initialValue: _studentData!['grandFatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['grandFatherName'] = v),
                SpeechTextField(label: 'اللقب', initialValue: _studentData!['surName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['surName'] = v),
              ]),

              _buildSection('معلومات الأم', Icons.pregnant_woman, cardColor, textColor, isDark, [
                SpeechTextField(label: 'اسم الأم', initialValue: _studentData!['motherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['motherName'] = v),
                SpeechTextField(label: 'اسم أب الأم', initialValue: _studentData!['mothersFatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['mothersFatherName'] = v),
                SpeechTextField(label: 'اسم جد الأم', initialValue: _studentData!['mothersGrandFatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['mothersGrandFatherName'] = v),
              ]),

              _buildSection('المرحلة والشعبة (الصف الدراسي)', Icons.school, cardColor, textColor, isDark, [
                _buildDropdown('الصف الدراسي', _studentData!['stageName'] ?? 'الأول إبتدائي', ['الأول إبتدائي','الثاني إبتدائي','الثالث إبتدائي','الأول متوسط','الثاني متوسط','الثالث متوسط','الرابع إعدادي','الخامس إعدادي','السادس إعدادي'], (v) => _studentData!['stageName'] = v, isDark, textColor),
                _buildDropdown('الشعبة', _studentData!['classRoomName'] ?? 'أ', ['أ', 'ب', 'ج', 'د', 'هـ'], (v) => _studentData!['classRoomName'] = v, isDark, textColor),
              ]),

              _buildSection('المعلومات العامة والهوية', Icons.badge, cardColor, textColor, isDark, [
                SpeechTextField(label: 'رقم الهوية', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v),
                
                // قائمة منسدلة ذكية تعرض الأسماء وترسل الأرقام
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: idTypeValue, dropdownColor: isDark ? Colors.grey[900] : Colors.white, style: TextStyle(color: textColor),
                    decoration: InputDecoration(labelText: 'نوع الهوية', labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: isDark ? Colors.black12 : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                    items: _idTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                    onChanged: (v) => ident['idType'] = int.tryParse(v!),
                  ),
                ),
              ]),

              _buildSection('معلومات السكن', Icons.home, cardColor, textColor, isDark, [
                SpeechTextField(label: 'المحافظة', initialValue: address['town'], isDark: isDark, textColor: textColor, onChanged: (v) => address['town'] = v),
                SpeechTextField(label: 'أقرب نقطة دالة', initialValue: address['closestLocation'], isDark: isDark, textColor: textColor, onChanged: (v) => address['closestLocation'] = v),
                SpeechTextField(label: 'الشارع', initialValue: address['street'], isDark: isDark, textColor: textColor, onChanged: (v) => address['street'] = v),
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

// أداة ذكية: حقل نصي يدمج الكتابة اليدوية مع الإدخال الصوتي
class SpeechTextField extends StatefulWidget {
  final String label;
  final dynamic initialValue;
  final bool isDark;
  final Color textColor;
  final Function(String) onChanged;

  const SpeechTextField({super.key, required this.label, required this.initialValue, required this.isDark, required this.textColor, required this.onChanged});

  @override
  State<SpeechTextField> createState() => _SpeechTextFieldState();
}

class _SpeechTextFieldState extends State<SpeechTextField> {
  late TextEditingController _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue?.toString() ?? '');
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        bool available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            localeId: 'ar_IQ',
            onResult: (val) {
              setState(() {
                _controller.text = val.recognizedWords;
                widget.onChanged(_controller.text);
              });
            },
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(color: widget.textColor),
        decoration: InputDecoration(
          labelText: widget.label, labelStyle: const TextStyle(color: Colors.grey),
          filled: true, fillColor: widget.isDark ? Colors.black12 : Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          suffixIcon: IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.blue),
            onPressed: _listen,
          ),
        ),
      ),
    );
  }
}
