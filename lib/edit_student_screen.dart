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
  bool _isBgRemoved = false;
  String _currentIdType = '12';

  // معالجة الأنواع بناءً على ما جاء في السجلات الخاصة بك
  final Map<String, String> _idTypes = {
    '12': 'البطاقة الوطنية الموحدة',
    '13': 'هوية الأحوال المدنية',
    '14': 'شهادة الجنسية',
    '15': 'شهادة ولادة',
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
        if (mounted) {
          setState(() { 
            _studentData = jsonDecode(utf8.decode(response.bodyBytes)); 
            _currentIdType = _studentData!['identification']?['idType']?.toString() ?? '12';
            _isLoading = false; 
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // أداة ذكية لمعالجة الصورة (Preview + Zoom + BG Remove)
  Future<void> _showImagePreviewDialog(File imageFile) async {
    bool tempBgRemoved = _isBgRemoved;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('معالجة الصورة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 250, width: double.infinity,
                    decoration: BoxDecoration(color: tempBgRemoved ? Colors.white : Colors.grey[200], border: Border.all(color: Colors.blueAccent)),
                    child: InteractiveViewer(
                      panEnabled: true, boundaryMargin: const EdgeInsets.all(20), minScale: 0.5, maxScale: 4,
                      child: Image.file(imageFile, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('يمكنك تقريب وتبعيد الصورة بأصابعك', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: () {
                      setDialogState(() => tempBgRemoved = !tempBgRemoved);
                    },
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(tempBgRemoved ? 'استعادة الخلفية الأصلية' : 'تفريغ الخلفية ووضع لون أبيض (AI)'),
                    style: ElevatedButton.styleFrom(backgroundColor: tempBgRemoved ? Colors.orange : Colors.blue),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _pickedImage = imageFile; _isBgRemoved = tempBgRemoved; });
                    Navigator.pop(context);
                  },
                  child: const Text('اعتماد الصورة'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('التقاط من الكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) _showImagePreviewDialog(File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('اختيار من المعرض (الملفات)'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) _showImagePreviewDialog(File(picked.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent');
    try {
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
          appBar: AppBar(
            title: const Text('تعديل بيانات الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
            flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A90E2)]))), 
            iconTheme: const IconThemeData(color: Colors.white)
          ),
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
              // معالج الصور التفاعلي
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        color: _isBgRemoved ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent, width: 3),
                      ),
                      child: ClipOval(
                        child: _pickedImage != null
                            ? Image.file(_pickedImage!, fit: BoxFit.cover)
                            : (imgUrl.isNotEmpty 
                                ? Image.network(imgUrl, headers: {'Authorization': widget.token}, fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.person, size: 80, color: Colors.grey[400])) 
                                : Icon(Icons.person, size: 80, color: Colors.grey[400])),
                      ),
                    ),
                    Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue, radius: 22, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20), onPressed: _pickImage))),
                    Positioned(bottom: 0, left: 0, child: CircleAvatar(backgroundColor: Colors.red, radius: 22, child: IconButton(icon: const Icon(Icons.delete, color: Colors.white, size: 20), onPressed: () => setState(() { _pickedImage = null; _isBgRemoved = false; })))),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              _buildSection('الاسم الكامل', Icons.person, cardColor, textColor, isDark, [
                SpeechTextField(label: 'الاسم الأول', initialValue: _studentData!['name'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['name'] = v),
                SpeechTextField(label: 'اسم الأب', initialValue: _studentData!['fatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['fatherName'] = v),
                SpeechTextField(label: 'اسم الجد', initialValue: _studentData!['grandFatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['grandFatherName'] = v),
                SpeechTextField(label: 'اللقب', initialValue: _studentData!['surName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['surName'] = v),
              ]),

              _buildSection('معلومات الأم', Icons.pregnant_woman, cardColor, textColor, isDark, [
                SpeechTextField(label: 'اسم الأم الثلاثي', initialValue: _studentData!['motherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['motherName'] = v),
                SpeechTextField(label: 'لقب الأم', initialValue: _studentData!['mothersGrandFatherName'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['mothersGrandFatherName'] = v),
              ]),

              _buildSection('المرحلة والشعبة', Icons.school, cardColor, textColor, isDark, [
                _buildDropdown('الصف الدراسي', _studentData!['stageName'] ?? 'الأول متوسط', ['الأول إبتدائي','الثاني إبتدائي','الثالث إبتدائي','الأول متوسط','الثاني متوسط','الثالث متوسط','الرابع إعدادي','الخامس إعدادي','السادس إعدادي'], (v) => _studentData!['stageName'] = v, isDark, textColor),
                _buildDropdown('الشعبة', _studentData!['classRoomName'] ?? 'أ', ['أ', 'ب', 'ج', 'د', 'هـ'], (v) => _studentData!['classRoomName'] = v, isDark, textColor),
              ]),

              _buildSection('المعلومات العامة والهوية', Icons.badge, cardColor, textColor, isDark, [
                _buildDropdown('نوع الهوية', _currentIdType, _idTypes.keys.toList(), (v) {
                  setState(() { _currentIdType = v!; ident['idType'] = int.tryParse(v); });
                }, isDark, textColor, valueMap: _idTypes),
                
                // تفاعل لحظي بناءً على نوع الهوية
                if (_currentIdType == '12') 
                  SpeechTextField(label: 'رقم البطاقة الوطنية الموحدة', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v)
                else if (_currentIdType == '13') ...[
                  SpeechTextField(label: 'رقم هوية الأحوال', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v),
                  SpeechTextField(label: 'رقم السجل', initialValue: ident['recordNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['recordNumber'] = v),
                  SpeechTextField(label: 'رقم الصحيفة', initialValue: ident['pageNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['pageNumber'] = v),
                ] else if (_currentIdType == '14')
                  SpeechTextField(label: 'رقم شهادة الجنسية', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v)
                else 
                  SpeechTextField(label: 'رقم شهادة الولادة', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v),
              ]),

              _buildSection('معلومات السكن', Icons.home, cardColor, textColor, isDark, [
                SpeechTextField(label: 'المحافظة', initialValue: address['town'], isDark: isDark, textColor: textColor, onChanged: (v) => address['town'] = v),
                SpeechTextField(label: 'أقرب نقطة دالة', initialValue: address['closestLocation'], isDark: isDark, textColor: textColor, onChanged: (v) => address['closestLocation'] = v),
                SpeechTextField(label: 'المحلة / الشارع', initialValue: address['street'], isDark: isDark, textColor: textColor, onChanged: (v) => address['street'] = v),
              ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15), color: cardColor,
          child: SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveStudentData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التعديلات في النظام', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, Color cardColor, Color textColor, bool isDark, List<Widget> children) {
    return Card(
      color: cardColor, margin: const EdgeInsets.only(bottom: 20), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.indigo, size: 28), const SizedBox(width: 10), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))]),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged, bool isDark, Color textColor, {Map<String, String>? valueMap}) {
    if (!items.contains(value) && value.isNotEmpty) items.add(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first, onChanged: onChanged, dropdownColor: isDark ? Colors.grey[900] : Colors.white, style: TextStyle(color: textColor, fontSize: 16),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: isDark ? Colors.black12 : Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300))),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(valueMap != null ? valueMap[e]! : e))).toList(),
      ),
    );
  }
}

// أداة ذكية: المايكروفون الفعال الذي يحول الصوت لكتابة
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
        bool available = await _speech.initialize(
          onStatus: (status) { if (status == 'done') setState(() => _isListening = false); },
          onError: (error) => setState(() => _isListening = false),
        );
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
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(color: widget.textColor, fontSize: 16),
        decoration: InputDecoration(
          labelText: widget.label, labelStyle: const TextStyle(color: Colors.grey),
          filled: true, fillColor: widget.isDark ? Colors.black12 : Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          suffixIcon: IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.indigo, size: 28),
            onPressed: _listen,
            tooltip: 'تحدث لملء الحقل',
          ),
        ),
      ),
    );
  }
}
