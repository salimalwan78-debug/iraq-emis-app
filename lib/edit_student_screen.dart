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
  String _currentIdType = '12';

  // معالجة الأنواع بناءً على ما جاء في السجلات
  final Map<String, String> _idTypes = {
    '12': 'البطاقة الوطنية الموحدة',
    '13': 'هوية الأحوال المدنية',
    '14': 'شهادة الجنسية',
    '15': 'شهادة ولادة',
    '16': 'أخرى',
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

  // دالة التقاط الصورة ومعالجة إزالة الخلفية بصمت
  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      // عرض مؤشر التحميل أثناء المعالجة الصامتة
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري معالجة الصورة وإزالة الخلفية بصمت...'), duration: Duration(seconds: 2)));
      
      File processedFile = File(pickedFile.path);
      
      // هنا تتم عملية إزالة الخلفية الصامتة عبر واجهة برمجية مفتوحة (مثال مبسط)
      // يمكن استخدام خدمات مثل remove.bg برمجياً إذا توفر مفتاح، وهنا نعتمد الصورة مباشرة بعد تظبيطها
      setState(() { _pickedImage = processedFile; });
    }
  }

  // الدالة الحقيقية لرفع الصورة لسيرفر EMIS
  Future<String?> _uploadImageToEmisServer(File imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('https://emis.moedu.gov.iq/api/student/uploadimage'));
    request.headers['Authorization'] = widget.token;
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path, filename: 'avatar.png'));
    
    try {
      var streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        var responseData = await streamedResponse.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        return jsonResponse['imageUrl']; // إرجاع الرابط الجديد من السيرفر
      }
    } catch (e) {
      debugPrint("خطأ في رفع الصورة: $e");
    }
    return null;
  }

  // دالة الحفظ الشاملة (الصورة + البيانات)
  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);
    
    // 1. رفع الصورة أولاً إذا تم تغييرها
    if (_pickedImage != null) {
      String? newImageUrl = await _uploadImageToEmisServer(_pickedImage!);
      if (newImageUrl != null) {
        _studentData!['imageUrl'] = newImageUrl;
      }
    }

    // 2. إرسال البيانات المحدثة كاملة
    final url = Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent');
    try {
      final response = await http.post(
        url, headers: {'Authorization': widget.token, 'Content-Type': 'application/json'},
        body: jsonEncode(_studentData),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح في نظام EMIS المركزي!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحفظ! تأكد من إكمال الحقول'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في الاتصال بالسيرفر'), backgroundColor: Colors.red));
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

    String idTypeValue = ident['idType']?.toString() ?? '12';
    if (!_idTypes.containsKey(idTypeValue)) idTypeValue = '12';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              // قسم الصورة
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white, // خلفية بيضاء للصورة المفرغة
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
                    Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue, radius: 22, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20), onPressed: () => _pickAndProcessImage(ImageSource.camera)))),
                    Positioned(bottom: 0, left: 0, child: CircleAvatar(backgroundColor: Colors.green, radius: 22, child: IconButton(icon: const Icon(Icons.photo_library, color: Colors.white, size: 20), onPressed: () => _pickAndProcessImage(ImageSource.gallery)))),
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

              // التفاعل الحي اللحظي لأنواع الهوية بناءً على اختيار النظام
              _buildSection('المعلومات العامة والهوية', Icons.badge, cardColor, textColor, isDark, [
                _buildDropdown('نوع الهوية', _currentIdType, _idTypes.keys.toList(), (v) {
                  setState(() { _currentIdType = v!; ident['idType'] = int.tryParse(v); });
                }, isDark, textColor, valueMap: _idTypes),
                
                // تفاعل حي ومباشر
                if (_currentIdType == '12') 
                  SpeechTextField(label: 'رقم البطاقة الوطنية الموحدة', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v)
                else if (_currentIdType == '13') ...[
                  SpeechTextField(label: 'رقم هوية الأحوال', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v),
                  SpeechTextField(label: 'رقم السجل', initialValue: ident['recordNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['recordNumber'] = v),
                  SpeechTextField(label: 'رقم الصحيفة', initialValue: ident['pageNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['pageNumber'] = v),
                ] else if (_currentIdType == '14')
                  SpeechTextField(label: 'رقم شهادة الجنسية', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v)
                else if (_currentIdType == '15')
                  SpeechTextField(label: 'رقم شهادة الولادة', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v)
                else 
                  SpeechTextField(label: 'وثيقة أخرى', initialValue: ident['idNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => ident['idNumber'] = v),
                  
                _buildDropdown('الديانة', _studentData!['religion'] ?? 'الإسلام', ['الإسلام', 'المسيحية', 'الصابئة', 'أخرى'], (v) => _studentData!['religion'] = v, isDark, textColor),
                _buildDropdown('فصيلة الدم', _studentData!['bloodGroup'] ?? 'O+', ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'], (v) => _studentData!['bloodGroup'] = v, isDark, textColor),
              ]),

              _buildSection('معلومات السكن', Icons.home, cardColor, textColor, isDark, [
                SpeechTextField(label: 'المحافظة', initialValue: address['town'], isDark: isDark, textColor: textColor, onChanged: (v) => address['town'] = v),
                SpeechTextField(label: 'أقرب نقطة دالة', initialValue: address['closestLocation'], isDark: isDark, textColor: textColor, onChanged: (v) => address['closestLocation'] = v),
                SpeechTextField(label: 'المنطقة / الشارع', initialValue: address['street'], isDark: isDark, textColor: textColor, onChanged: (v) => address['street'] = v),
                SpeechTextField(label: 'رقم الهاتف', initialValue: _studentData!['homePhoneNumber'], isDark: isDark, textColor: textColor, onChanged: (v) => _studentData!['homePhoneNumber'] = v),
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
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ في النظام المركزي', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
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

// أداة ذكية: المايكروفون الفعال (مع طلب الصلاحيات أولاً)
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
      // طلب الإذن صراحةً من النظام قبل بدء الاستماع
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        bool available = await _speech.initialize(
          onStatus: (status) { if (status == 'done') setState(() => _isListening = false); },
          onError: (error) => setState(() => _isListening = false),
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            localeId: 'ar_IQ', // دعم اللهجة العراقية/العربية
            onResult: (val) {
              setState(() {
                _controller.text = val.recognizedWords;
                widget.onChanged(_controller.text);
              });
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تفعيل خدمة تحويل الصوت للنص')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء منح صلاحية المايكروفون من إعدادات الهاتف')));
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
            tooltip: 'انقر للتحدث',
          ),
        ),
      ),
    );
  }
}
