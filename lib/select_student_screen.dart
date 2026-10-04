import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_core.dart';
import 'edit_student_screen.dart';
import 'add_student_screen.dart';

class SelectStudentScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<dynamic> preLoadedStudents;

  const SelectStudentScreen({
    super.key,
    required this.token,
    required this.schoolId,
    required this.preLoadedStudents,
  });

  @override
  State<SelectStudentScreen> createState() => _SelectStudentScreenState();
}

class _SelectStudentScreenState extends State<SelectStudentScreen> {
  late List<Map<String, dynamic>> _allStudents;
  String _query = '';
  String? _selectedStage;
  String? _selectedClassRoom;

  @override
  void initState() {
    super.initState();
    _allStudents = widget.preLoadedStudents
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> get _stages => _allStudents
      .map((s) => (s['studentStage'] ?? s['stageName'] ?? '').toString())
      .where((s) => s.trim().isNotEmpty)
      .toSet()
      .toList();

  List<String> get _classRooms {
    if (_selectedStage == null) return <String>[];
    return _allStudents
        .where((s) => (s['studentStage'] ?? s['stageName'])?.toString() == _selectedStage)
        .map((s) => (s['classRoomName'] ?? s['classRoom'])?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  String _studentName(Map<String, dynamic> student) {
    final direct = student['fullName'] ?? student['studentName'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final parts = [
      student['name'],
      student['fatherName'],
      student['grandFatherName'],
      student['surName'],
    ]
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'بدون اسم' : parts.join(' ');
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _query.trim().toLowerCase();
    return _allStudents.where((student) {
      final stage = (student['studentStage'] ?? student['stageName'])?.toString();
      final classroom = (student['classRoomName'] ?? student['classRoom'])?.toString();
      final stageMatches = _selectedStage == null || stage == _selectedStage;
      final classMatches = _selectedClassRoom == null || classroom == _selectedClassRoom;
      if (!stageMatches || !classMatches) return false;
      if (query.isEmpty) return true;
      final values = [
        _studentName(student),
        student['id'],
        student['nationalIdNumber'],
        student['idNumber'],
      ];
      return values.any((value) => '$value'.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _openStudent(Map<String, dynamic> student) async {
    final id = student['id']?.toString();
    if (id == null || id.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditStudentScreen(
          token: widget.token,
          studentId: id,
        ),
      ),
    );
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

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: const Text('تعديل الطلاب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A90E2)]),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: 'إضافة طالب جديد',
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => AddStudentScreen(token: widget.token, schoolId: widget.schoolId)),
                  );
                  if (changed == true && mounted) setState(() {});
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _allStudents = widget.preLoadedStudents
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
              });
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStage,
                        decoration: InputDecoration(
                          labelText: 'اختر الصف',
                          filled: true,
                          fillColor: card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        dropdownColor: card,
                        style: TextStyle(color: text),
                        items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (value) => setState(() {
                          _selectedStage = value;
                          _selectedClassRoom = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedClassRoom,
                        decoration: InputDecoration(
                          labelText: 'اختر الشعبة',
                          filled: true,
                          fillColor: card,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        dropdownColor: card,
                        style: TextStyle(color: text),
                        items: _classRooms.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: _selectedStage == null ? null : (value) => setState(() => _selectedClassRoom = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  textDirection: TextDirection.rtl,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: card,
                    hintText: 'ابحث باسم الطالب أو الرقم',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.clear)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, color: Colors.indigo),
                      const SizedBox(width: 10),
                      Text('${_filteredStudents.length} طالب', style: TextStyle(fontWeight: FontWeight.bold, color: text)),
                      const Spacer(),
                      if (_query.isNotEmpty) Text('نتائج البحث', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_filteredStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(35),
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        const Icon(Icons.person_search_outlined, size: 55, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty ? 'لا توجد نتائج مطابقة للبحث' : 'اختر الصف والشعبة أو استخدم البحث لعرض الطلاب',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: text, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  ..._filteredStudents.map((student) => _studentCard(student, card, text)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _studentCard(Map<String, dynamic> student, Color card, Color text) {
    final name = _studentName(student);
    final id = '${student['id'] ?? ''}';
    final stage = '${student['studentStage'] ?? student['stageName'] ?? ''}';
    final classroom = '${student['classRoomName'] ?? student['classRoom'] ?? ''}';

    return Card(
      color: card,
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openStudent(student),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Colors.indigo.withOpacity(0.12),
                child: const Icon(Icons.person, color: Colors.indigo, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: text), textAlign: TextAlign.right),
                    const SizedBox(height: 7),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (stage.isNotEmpty) _chip(stage, Colors.indigo),
                        if (classroom.isNotEmpty) _chip('شعبة $classroom', Colors.blue),
                      ],
                    ),
                    if (id.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('رقم الطالب: $id', style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.right),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'تعطيل الطالب',
                onPressed: () => _deactivateStudent(student),
                icon: const Icon(Icons.person_off_outlined, color: Colors.redAccent),
              ),
              IconButton(
                tooltip: 'تعديل بيانات الطالب',
                onPressed: () => _openStudent(student),
                icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deactivateStudent(Map<String, dynamic> student) async {
    final id = student['id'];
    if (id == null) return;
    final name = _studentName(student);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعطيل الطالب', textDirection: TextDirection.rtl),
        content: Text('هل أنت متأكد من تعطيل الطالب $name؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.person_off),
            label: const Text('تعطيل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final candidates = [
      Uri.parse('https://emis.moedu.gov.iq/api/student/deactivate/$id'),
      Uri.parse('https://emis.moedu.gov.iq/api/student/deactivatestudent/$id'),
    ];
    String? error;
    for (final uri in candidates) {
      try {
        final response = await http.post(uri, headers: {'Authorization': widget.token, 'Accept': 'application/json'});
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          setState(() => _allStudents.removeWhere((x) => '${x['id']}' == '$id'));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعطيل الطالب بنجاح'), backgroundColor: Colors.green));
          return;
        }
        error = 'HTTP ${response.statusCode}: ${response.body}';
        if (response.statusCode != 404 && response.statusCode != 405) break;
      } catch (e) {
        error = '$e';
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تعطيل الطالب${error == null ? '' : ': $error'}'), backgroundColor: Colors.red));
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
