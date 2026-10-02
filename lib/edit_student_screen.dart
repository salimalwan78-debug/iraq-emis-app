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

  // قاموس تعريب الحقول البرمجية لتظهر باللغة العربية الرسمية لنظام EMIS
  final Map<String, String> _arabicFieldNames = {
    'name': 'الاسم الأول',
    'fatherName': 'اسم الأب',
    'grandFatherName': 'اسم الجد',
    'surName': 'اللقب',
    'motherName': 'اسم الأم الثلاثي',
    'mothersFatherName': 'اسم أب الأم',
    'mothersGrandFatherName': 'اسم جد الأم',
    'birthDate': 'تاريخ الميلاد',
    'nationality': 'الجنسية',
    'religion': 'الديانة',
    'bloodGroup': 'فصيلة الدم',
    'censusNumber': 'رقم التعداد العام',
    'town': 'المحافظة',
    'closestLocation': 'أقرب نقطة دالة',
    'street': 'المنطقة / الشارع',
    'homePhoneNumber': 'رقم الهاتف',
    'idNumber': 'رقم الهوية',
    'recordNumber': 'رقم السجل',
    'pageNumber': 'رقم الصحيفة',
    'issuer': 'جهة الإصدار',
  };

  // تعريب خيارات القوائم المنسدلة للقيم العددية
  final Map<String, Map<String, String>> _dropdownOptions = {
    'religion': {'الإسلام': 'الإسلام', 'المسيحية': 'المسيحية', 'الصابئة': 'الصابئة المندائية', 'أخرى': 'أخرى'},
    'bloodGroup': {'O+': 'O+', 'O-': 'O-', 'A+': 'A+', 'A-': 'A-', 'B+': 'B+', 'B-': 'B-', 'AB+': 'AB+', 'AB-': 'AB-'},
    'idType': {'12': 'البطاقة الوطنية الموحدة', '13': 'هوية الأحوال المدنية', '14': 'شهادة الجنسية', '15': 'شهادة ولادة'}
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
            _isLoading = false; 
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // معاينة الصورة وإزالة الخلفية ديناميكياً
  Future<void> _showImagePreviewDialog(File imageFile) async {
    File currentImage = imageFile;
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('معاينة الصورة وتعديلها', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 220, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                    child: InteractiveViewer(
                      panEnabled: true, boundaryMargin: const EdgeInsets.all(20), minScale: 0.5, maxScale: 4,
                      child: Image.file(currentImage, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('يمكنك تقريب الصورة أو تحريكها لضبطها', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 15),
                  isProcessing 
                    ? const Padding(padding: EdgeInsets.all(8.0), child: Text('جاري معالجة الصورة وإزالة الخلفية...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))
                    : ElevatedButton.icon(
                        onPressed: () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            var request = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'));
                            request.files.add(await http.MultipartFile.fromPath('image_file', currentImage.path));
                            var response = await request.send();
                            if (response.statusCode == 200) {
                              var bytes = await response.stream.toBytes();
                              File tempFile = File('${currentImage.path}_nobg.png');
                              await tempFile.writeAsBytes(bytes);
                              setDialogState(() => currentImage = tempFile);
                            }
                          } catch (e) {
                            debugPrint('خطأ في إزالة الخلفية: $e');
                          }
                          setDialogState(() => isProcessing = false);
                        },
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('إزالة الخلفية (تلقائي)'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                      )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: isProcessing ? null : () {
                    setState(() { _pickedImage = currentImage; });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('اعتماد', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      _showImagePreviewDialog(File(picked.path));
    }
  }

  // حذف الصورة الحالية للطالب
  void _deleteCurrentPhoto() {
    setState(() {
      _pickedImage = null;
      if (_studentData != null) {
        _studentData!['imageUrl'] = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف صورة الطالب')));
  }

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
        return jsonResponse['imageUrl'];
      }
    } catch (e) {
      debugPrint("خطأ في رفع الصورة: $e");
    }
    return null;
  }

  Future<void> _saveStudentData() async {
    setState(() => _isSaving = true);
    if (_pickedImage != null) {
      String? newImageUrl = await _uploadImageToEmisServer(_pickedImage!);
      if (newImageUrl != null) {
        _studentData!['imageUrl'] = newImageUrl;
      }
    }

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

  // بناء الحقول ديناميكياً مع التعريب التام للأسماء
  List<Widget> _buildDynamicFields(Map<String, dynamic> dataMap, bool isDark, Color textColor) {
    List<Widget> widgets = [];
    dataMap.forEach((key, value) {
      if (key == 'imageUrl' || key == 'id' || key == 'createdAt' || key == 'updatedAt' || key == 'schoolId') return;

      String fieldTitle = _arabicFieldNames[key] ?? key;

      if (value is Map<String, dynamic>) {
        widgets.add(
          Card(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            margin: const EdgeInsets.only(bottom: 15, top: 10),
            elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fieldTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade400)),
                  const SizedBox(height: 15),
                  ..._buildDynamicFields(value, isDark, textColor),
                ],
              ),
            ),
          )
        );
      } else if (value is List) {
        // تجاهل القوائم المعقدة
      } else {
        // إذا كان الحقل يمتلك خيارات معرّفة (مثل idType أو religion)
        if (_dropdownOptions.containsKey(key)) {
          Map<String, String> options = _dropdownOptions[key]!;
          String currentValue = value?.toString() ?? options.keys.first;
          if (!options.containsKey(currentValue)) currentValue = options.keys.first;

          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: DropdownButtonFormField<String>(
                value: currentValue,
                dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: fieldTitle,
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? Colors.black12 : Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300))
                ),
                items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) {
                  setState(() {
                    dataMap[key] = (key == 'idType') ? int.tryParse(v!) : v;
                  });
                },
              ),
            ),
          );
        } else {
          widgets.add(SpeechTextField(
            label: fieldTitle,
            initialValue: value,
            isDark: isDark,
            textColor: textColor,
            onChanged: (v) => dataMap[key] = v,
          ));
        }
      }
    });
    return widgets;
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

        String imgUrl = _studentData?['imageUrl'] ?? '';
        if (imgUrl.isNotEmpty && !imgUrl.startsWith('http')) imgUrl = 'https://emis.moedu.gov.iq$imgUrl';

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
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(15),
                        children: [
                          // قسم الصورة وزر الحذف الجديد
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 140, height: 140,
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent, width: 3)),
                                  child: ClipOval(
                                    child: _pickedImage != null
                                        ? Image.file(_pickedImage!, fit: BoxFit.cover)
                                        : (imgUrl.isNotEmpty 
                                            ? Image.network(imgUrl, headers: {'Authorization': widget.token}, fit: BoxFit.cover, errorBuilder: (c, o, s) => Icon(Icons.person, size: 80, color: Colors.grey[400])) 
                                            : Icon(Icons.person, size: 80, color: Colors.grey[400])),
                                  ),
                                ),
                                Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue, radius: 20, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18), onPressed: () => _pickImage(ImageSource.camera)))),
                                Positioned(bottom: 0, left: 0, child: CircleAvatar(backgroundColor: Colors.green, radius: 20, child: IconButton(icon: const Icon(Icons.photo_library, color: Colors.white, size: 18), onPressed: () => _pickImage(ImageSource.gallery)))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // زر حذف الصورة الحالية
                          Center(
                            child: TextButton.icon(
                              onPressed: _deleteCurrentPhoto,
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: const Text('حذف الصورة الحالية', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 15),
                          ..._buildDynamicFields(_studentData!, isDark, textColor),
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
                          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      }
    );
  }
}

// أداة ذكية: المايكروفون الفعال (عربي حصرياً)
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
          onStatus: (status) { if (status == 'done' || status == 'notListening') setState(() => _isListening = false); },
          onError: (error) => setState(() => _isListening = false),
        );
        if (available) {
          var locales = await _speech.locales();
          var arabicLocale = locales.firstWhere((l) => l.localeId.toLowerCase().contains('ar'), orElse: () => locales.first);
          
          setState(() => _isListening = true);
          _speech.listen(
            localeId: arabicLocale.localeId,
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
            tooltip: 'تحدث بالعربية',
          ),
        ),
      ),
    );
  }
}
