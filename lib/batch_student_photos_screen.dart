import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'app_core.dart';

class BatchStudentPhotosScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<dynamic> allStudents;

  const BatchStudentPhotosScreen({
    super.key,
    required this.token,
    required this.schoolId,
    required this.allStudents,
  });

  @override
  State<BatchStudentPhotosScreen> createState() => _BatchStudentPhotosScreenState();
}

class _BatchStudentPhotosScreenState extends State<BatchStudentPhotosScreen> {
  String? _selectedStage;
  String? _selectedClassRoom;
  List<Map<String, dynamic>> _students = <Map<String, dynamic>>[];
  int _currentIndex = 0;
  final Set<String> _photographed = <String>{};
  final Set<String> _notPhotographed = <String>{};
  File? _currentImage;
  bool _processing = false;
  bool _saving = false;
  SelfieSegmenter? _segmenter;

  List<String> get _stages => widget.allStudents
      .whereType<Map>()
      .map((s) => s['studentStage']?.toString() ?? '')
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  List<String> get _classRooms {
    if (_selectedStage == null) return <String>[];
    return widget.allStudents
        .whereType<Map>()
        .where((s) => s['studentStage']?.toString() == _selectedStage)
        .map((s) => (s['classRoomName'] ?? s['classRoom'])?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  String _studentId(Map<String, dynamic> s) => s['id']?.toString() ?? '';

  String _studentName(Map<String, dynamic> s) {
    final direct = s['fullName'] ?? s['studentName'];
    if (direct != null && direct.toString().trim().isNotEmpty) return direct.toString().trim();
    final parts = [s['name'], s['firstName'], s['fatherName'], s['grandFatherName'], s['surName']]
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'بدون اسم' : parts.join(' ');
  }

  void _selectStage(String? value) {
    setState(() {
      _selectedStage = value;
      _selectedClassRoom = null;
      _students = <Map<String, dynamic>>[];
      _currentIndex = 0;
      _photographed.clear();
      _notPhotographed.clear();
      _currentImage = null;
    });
  }

  void _selectClassRoom(String? value) {
    final filtered = widget.allStudents.whereType<Map>().where((s) {
      return s['studentStage']?.toString() == _selectedStage &&
          (s['classRoomName'] ?? s['classRoom'])?.toString() == value;
    }).map((s) => Map<String, dynamic>.from(s)).toList();

    setState(() {
      _selectedClassRoom = value;
      _students = filtered;
      _currentIndex = _firstPendingIndex(filtered);
      _photographed.clear();
      _notPhotographed.clear();
      _currentImage = null;
    });
  }

  int _firstPendingIndex(List<Map<String, dynamic>> list) {
    for (var i = 0; i < list.length; i++) {
      final id = _studentId(list[i]);
      if (!_photographed.contains(id)) return i;
    }
    return 0;
  }

  Future<void> _initializeSegmenter() async {
    _segmenter ??= SelfieSegmenter(mode: SegmenterMode.single, enableRawSizeMask: false);
  }

  Future<File> _removeBackground(File imageFile) async {
    await _initializeSegmenter();
    final segmenter = _segmenter;
    if (segmenter == null) throw Exception('تعذر تهيئة أداة إزالة الخلفية');

    final bytes = await imageFile.readAsBytes();
    var source = img.decodeImage(bytes);
    if (source == null) throw Exception('تعذر قراءة الصورة');
    source = img.bakeOrientation(source);

    const maxDimension = 512;
    if (source.width > maxDimension || source.height > maxDimension) {
      source = img.copyResize(
        source,
        width: source.width >= source.height ? maxDimension : null,
        height: source.height > source.width ? maxDimension : null,
        interpolation: img.Interpolation.linear,
      );
    }

    final inputPath = '${imageFile.path}_seg_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final inputFile = File(inputPath);
    await inputFile.writeAsBytes(img.encodeJpg(source, quality: 90), flush: true);

    try {
      final mask = await segmenter.processImage(InputImage.fromFilePath(inputFile.path));
      if (mask == null || mask.width <= 0 || mask.height <= 0 || mask.confidences.isEmpty) {
        throw Exception('لم يتم الحصول على قناع صالح للشخص');
      }
      if (mask.width != source.width || mask.height != source.height) {
        throw Exception('أبعاد قناع إزالة الخلفية غير متطابقة');
      }

      final result = img.Image(width: source.width, height: source.height, numChannels: 4);
      final count = source.width * source.height;
      if (mask.confidences.length < count) throw Exception('بيانات القناع غير مكتملة');

      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final i = y * source.width + x;
          final confidence = mask.confidences[i].clamp(0.0, 1.0);
          final alpha = ((confidence - 0.35) / 0.40 * 255.0).round().clamp(0, 255);
          final pixel = source.getPixel(x, y);
          result.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, alpha);
        }
      }

      final output = File('${imageFile.path}_nobg_${DateTime.now().millisecondsSinceEpoch}.png');
      await output.writeAsBytes(img.encodePng(result, level: 6), flush: true);
      return output;
    } finally {
      try {
        if (await inputFile.exists()) await inputFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _takePhoto() async {
    if (_students.isEmpty || _currentIndex >= _students.length || _processing || _saving) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2500,
        maxHeight: 2500,
      );
      if (picked == null || !mounted) return;

      setState(() => _processing = true);
      final processed = await _removeBackground(File(picked.path));
      if (!mounted) return;
      setState(() {
        _currentImage = processed;
        _processing = false;
      });
    } catch (e) {
      debugPrint('Batch photo processing error: $e');
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر معالجة الصورة: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://emis.moedu.gov.iq/api/student/uploadimage'),
    );
    request.headers['Authorization'] = widget.token;
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path, filename: 'avatar.png'));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      debugPrint('Image upload failed ${response.statusCode}: $body');
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded['imageUrl']?.toString();
    } catch (_) {}
    return null;
  }

  Future<bool> _saveCurrentStudent() async {
    if (_students.isEmpty || _currentIndex >= _students.length || _currentImage == null) return false;
    final student = _students[_currentIndex];
    final id = _studentId(student);
    if (id.isEmpty) return false;

    setState(() => _saving = true);
    try {
      final imageUrl = await _uploadImage(_currentImage!);
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('تعذر رفع الصورة إلى EMIS');
      }

      student['imageUrl'] = imageUrl;
      final original = widget.allStudents.firstWhere(
        (s) => s is Map && s['id']?.toString() == id,
        orElse: () => student,
      );
      if (original is Map) original['imageUrl'] = imageUrl;

      final response = await http.post(
        Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent'),
        headers: {
          'Authorization': widget.token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(student),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('فشل حفظ بيانات الطالب (${response.statusCode})');
      }

      _photographed.add(id);
      _notPhotographed.remove(id);
      return true;
    } catch (e) {
      debugPrint('Batch save error: $e');
      _notPhotographed.add(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ الطالب: $e'), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _nextStudent() async {
    if (_currentImage == null || _saving || _processing) return;
    final saved = await _saveCurrentStudent();
    if (!saved || !mounted) return;

    setState(() {
      _currentImage = null;
      if (_currentIndex < _students.length - 1) {
        _currentIndex++;
      }
    });
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _photographed.clear();
      _notPhotographed.clear();
      _currentImage = null;
    });
  }

  void _resume() {
    setState(() {
      _currentIndex = _firstPendingIndex(_students);
      _currentImage = null;
    });
  }

  @override
  void dispose() {
    _segmenter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppCore.themeNotifier,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;
        final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
        final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final text = isDark ? Colors.white : Colors.black87;
        final selectedStudent = _students.isNotEmpty && _currentIndex < _students.length ? _students[_currentIndex] : null;
        final photographedCount = _photographed.length;
        final remaining = _students.length - photographedCount;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: const Text('إضافة صور الطلاب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A90E2)]))),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (_students.isNotEmpty) IconButton(onPressed: _showReport, icon: const Icon(Icons.assessment_outlined)),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(value: _selectedStage, decoration: _inputDecoration('اختر الصف', isDark), dropdownColor: card, style: TextStyle(color: text), items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: _selectStage)),
                    const SizedBox(width: 10),
                    Expanded(child: DropdownButtonFormField<String>(value: _selectedClassRoom, decoration: _inputDecoration('اختر الشعبة', isDark), dropdownColor: card, style: TextStyle(color: text), items: _classRooms.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: _selectedStage == null ? null : _selectClassRoom)),
                  ],
                ),
              ),
              if (_students.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      Expanded(child: _counter('المجموع', '${_students.length}', Colors.indigo)),
                      Expanded(child: _counter('تم التصوير', '$photographedCount', Colors.green)),
                      Expanded(child: _counter('متبقٍ', '$remaining', Colors.orange)),
                    ]),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: selectedStudent == null
                    ? Center(child: Text('اختر الصف والشعبة لبدء تصوير الطلاب', style: TextStyle(color: text, fontSize: 16)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 5))]),
                            child: Column(
                              children: [
                                Text('الطالب ${_currentIndex + 1} من ${_students.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(_studentName(selectedStudent), textAlign: TextAlign.center, style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 18),
                                Container(
                                  height: 300,
                                  width: double.infinity,
                                  decoration: BoxDecoration(color: isDark ? Colors.black26 : const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade300)),
                                  child: _processing
                                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('جاري إزالة الخلفية محليًا...')]))
                                      : _currentImage == null
                                          ? const Center(child: Icon(Icons.person_outline, size: 100, color: Colors.grey))
                                          : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(_currentImage!, fit: BoxFit.contain)),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: _processing || _saving ? null : _takePhoto, icon: const Icon(Icons.camera_alt, color: Colors.white), label: Text(_currentImage == null ? 'التقاط صورة الطالب' : 'إعادة التصوير', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                                if (_currentImage != null) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: _saving || _processing ? null : _nextStudent, icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded, color: Colors.white), label: Text(_saving ? 'جاري الحفظ...' : (_currentIndex == _students.length - 1 ? 'حفظ الطالب وإنهاء' : 'حفظ الطالب والانتقال للتالي'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(onPressed: photographedCount == 0 ? null : _resume, icon: const Icon(Icons.play_arrow), label: const Text('استكمال من آخر طالب'))),
                            const SizedBox(width: 10),
                            Expanded(child: OutlinedButton.icon(onPressed: photographedCount == 0 ? null : _restart, icon: const Icon(Icons.restart_alt), label: const Text('إعادة من جديد'))),
                          ]),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) => InputDecoration(labelText: label, filled: true, fillColor: isDark ? Colors.black12 : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  Widget _counter(String title, String value, Color color) => Column(children: [Text(value, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))]);

  Future<void> _showReport() async {
    final photographed = _students.where((s) => _photographed.contains(_studentId(s))).toList();
    final notPhotographed = _students.where((s) => !_photographed.contains(_studentId(s))).toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تقرير التصوير'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تم تصويرهم: ${photographed.length}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...photographed.map((s) => Text('✓ ${_studentName(s)}')),
              const Divider(height: 25),
              Text('لم يتم تصويرهم: ${notPhotographed.length}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...notPhotographed.map((s) => Text('• ${_studentName(s)}')),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }
}
