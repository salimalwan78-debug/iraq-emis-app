import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddStudentScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  const AddStudentScreen({super.key, required this.token, required this.schoolId});
  @override State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> c = {};
  final Map<String, List<Map<String, dynamic>>> opts = {};
  bool loading = true, saving = false;
  String? error;
  List<Map<String, dynamic>> stages = [], rooms = [];
  String? stageId, roomId;

  Map<String, String> get h => {
    'Authorization': widget.token,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    for (final k in [
      'name','fatherName','grandFatherName','fathersGrandFatherName','surName',
      'motherName','dateOfBirth','nationality','homeTown','nationalId',
      'gender','countryOfBirth','idType'
    ]) c[k] = TextEditingController();
    c['nationality']!.text = 'العراق';
    _load();
  }

  @override
  void dispose() {
    for (final x in c.values) x.dispose();
    super.dispose();
  }

  dynamic _unwrap(dynamic d) {
    if (d is Map && d['data'] != null) return d['data'];
    return d;
  }

  Future<List<Map<String, dynamic>>> _get(String ep) async {
    final r = await http.get(Uri.parse('https://emis.moedu.gov.iq/api$ep'), headers: h);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
    }
    final d = _unwrap(jsonDecode(utf8.decode(r.bodyBytes)));
    if (d is! List) return [];
    return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _get('/selectoption/Gender'),
        _get('/selectoption/بلد الولادة'),
        _get('/selectoption/IdentificationType'),
        _get('/selectoption/getAvailableStagesForStudent?schoolId=${widget.schoolId}'),
      ]);
      opts['gender'] = results[0];
      opts['countryOfBirth'] = results[1];
      opts['idType'] = results[2];
      stages = results[3];
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() { loading = false; error = '$e'; });
    }
  }

  Future<void> _rooms(String id) async {
    try {
      final r = await _get('/selectoption/getClassRooms?schoolId=${widget.schoolId}&stageId=$id');
      if (mounted) setState(() => rooms = r);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  List<DropdownMenuItem<String>> items(String k) => (opts[k] ?? []).map((x) {
    final v = '${x['value'] ?? x['id'] ?? x['code'] ?? ''}';
    final l = '${x['displayName'] ?? x['label'] ?? x['name'] ?? x['text'] ?? v}';
    return DropdownMenuItem(value: v, child: Text(l, textDirection: TextDirection.rtl));
  }).where((x) => x.value!.isNotEmpty).toList();

  Widget f(String k, String l, {bool req = false}) => TextFormField(
    controller: c[k], textDirection: TextDirection.rtl,
    decoration: InputDecoration(labelText: '$l${req ? ' *' : ''}', border: const OutlineInputBorder()),
    validator: req ? (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null : null,
  );

  String? n(String k) => c[k]!.text.trim().isEmpty ? null : c[k]!.text.trim();

  Future<void> save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (stageId == null || roomId == null) {
      setState(() => error = 'يجب اختيار الصف والشعبة');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      final p = <String, dynamic>{
        'id': 0,
        'name': n('name') ?? '',
        'fatherName': n('fatherName') ?? '',
        'grandFatherName': n('grandFatherName') ?? '',
        'fathersGrandFatherName': n('fathersGrandFatherName') ?? '',
        'surName': n('surName'),
        'motherName': n('motherName'),
        'dateOfBirth': n('dateOfBirth'),
        'gender': int.tryParse(c['gender']!.text),
        'nationality': n('nationality') ?? 'العراق',
        'countryOfBirth': n('countryOfBirth') ?? 'العراق',
        'homeTown': n('homeTown'),
        'identificationId': 0,
        'identification': {
          'id': 0,
          'idNumber': n('nationalId') ?? '',
          'issuingCountry': 'العراق',
          'idType': int.tryParse(c['idType']!.text),
          'jinsiyaIdNumber': null,
          'issuer': '', 'recordNumber': '', 'pageNumber': '',
          'issuingDate': null, 'nameOfDocument': '',
        },
        'fatherIdentificationId': null,
        'motherTongue': 'العربية',
        'maritalStatus': 'أعزب',
        'bloodGroup': 'غير معروف',
        'religion': 'الإسلام',
        'homePhoneNumber': '', 'notes': '', 'specialNeeds': [''],
        'studyLanguage': 'العربية', 'economicLevel': '',
        'isCoveredBySocialWelfare': false, 'isDroppedOutFromSchool': false,
        'lastYearResult': null, 'lastAcademicYearId': null,
        'lastCompletedStageId': null, 'lastSchoolId': null,
        'academicYearId': null,
        'stageId': int.tryParse(stageId!),
        'schoolId': int.tryParse(widget.schoolId),
        'classRoomId': int.tryParse(roomId!),
        'studentStatus': 0,
        'addressId': 0,
        'address': {
          'id': 0, 'town': n('homeTown') ?? '', 'area': '', 'quarter': '', 'street': '',
          'apartmentNumber': '', 'buildingNumber': '', 'address1': '', 'address2': '',
          'closestLocation': '', 'latitude': 0, 'longitude': 0,
          'schoolPhoneNumber': '', 'mobilePhoneNumber': '', 'email': '', 'website': '',
          'countryStructureId': null,
        },
      };
      final r = await http.post(
        Uri.parse('https://emis.moedu.gov.iq/api/student/addstudent'),
        headers: h, body: jsonEncode(p),
      );
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الطالب بنجاح'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة طالب جديد', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red), textDirection: TextDirection.rtl),
                    const SizedBox(height: 10),
                  ],
                  f('name', 'الإسم', req: true), const SizedBox(height: 10),
                  f('fatherName', 'إسم الأب', req: true), const SizedBox(height: 10),
                  f('grandFatherName', 'اسم والد الأب', req: true), const SizedBox(height: 10),
                  f('fathersGrandFatherName', 'اسم جد الأب'), const SizedBox(height: 10),
                  f('surName', 'اللقب'), const SizedBox(height: 10),
                  f('motherName', 'إسم الأم'), const SizedBox(height: 10),
                  f('nationalId', 'رقم الهوية'), const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: c['gender']!.text.isEmpty ? null : c['gender']!.text,
                      items: items('gender'), decoration: const InputDecoration(labelText: 'الجنس', border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => c['gender']!.text = v ?? ''),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: DropdownButtonFormField<String>(
                      value: c['idType']!.text.isEmpty ? null : c['idType']!.text,
                      items: items('idType'), decoration: const InputDecoration(labelText: 'نوع الهوية', border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => c['idType']!.text = v ?? ''),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  f('dateOfBirth', 'تاريخ التولد (YYYY-MM-DD)'), const SizedBox(height: 10),
                  f('nationality', 'الجنسية'), const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: c['countryOfBirth']!.text.isEmpty ? null : c['countryOfBirth']!.text,
                    items: items('countryOfBirth'), decoration: const InputDecoration(labelText: 'بلد الولادة', border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => c['countryOfBirth']!.text = v ?? ''),
                  ),
                  const SizedBox(height: 10),
                  f('homeTown', 'مسقط الرأس'), const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: stageId,
                    items: stages.map((x) {
                      final v = '${x['id'] ?? x['value'] ?? ''}';
                      final l = '${x['displayName'] ?? x['name'] ?? x['label'] ?? v}';
                      return DropdownMenuItem(value: v, child: Text(l));
                    }).where((x) => x.value!.isNotEmpty).toList(),
                    decoration: const InputDecoration(labelText: 'الصف *', border: OutlineInputBorder()),
                    onChanged: (v) { setState(() { stageId = v; roomId = null; rooms = []; }); if (v != null) _rooms(v); },
                    validator: (v) => v == null ? 'اختر الصف' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: roomId,
                    items: rooms.map((x) {
                      final v = '${x['id'] ?? x['value'] ?? ''}';
                      final l = '${x['displayName'] ?? x['name'] ?? x['label'] ?? v}';
                      return DropdownMenuItem(value: v, child: Text(l));
                    }).where((x) => x.value!.isNotEmpty).toList(),
                    decoration: const InputDecoration(labelText: 'الشعبة *', border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => roomId = v),
                    validator: (v) => v == null ? 'اختر الشعبة' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(height: 52, child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: const Text('حفظ الطالب'),
                  )),
                ],
              ),
            ),
    );
  }
}
