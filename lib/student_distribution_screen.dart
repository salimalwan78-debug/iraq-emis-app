import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StudentDistributionScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<dynamic> allStudents;
  const StudentDistributionScreen({super.key, required this.token, required this.schoolId, required this.allStudents});
  @override State<StudentDistributionScreen> createState() => _StudentDistributionScreenState();
}

class _StudentDistributionScreenState extends State<StudentDistributionScreen> {
  late List<Map<String, dynamic>> students;
  List<Map<String, dynamic>> stages = [], rooms = [];
  String? stageId, targetRoomId;
  final Set<int> selected = {};
  bool loading = true, saving = false;
  String? error;

  Map<String, String> get h => {'Authorization': widget.token, 'Accept': 'application/json', 'Content-Type': 'application/json'};
  dynamic unwrap(dynamic d) => d is Map && d['data'] != null ? d['data'] : d;

  @override void initState() { super.initState(); students = widget.allStudents.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); _load(); }

  Future<List<Map<String, dynamic>>> getList(String ep) async {
    final r = await http.get(Uri.parse('https://emis.moedu.gov.iq/api$ep'), headers: h);
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
    final d = unwrap(jsonDecode(utf8.decode(r.bodyBytes)));
    return d is List ? d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<void> _load() async {
    try {
      stages = await getList('/selectoption/getAvailableStagesForStudent?schoolId=${widget.schoolId}');
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() { loading = false; error = '$e'; }); }
  }

  Future<void> _loadRooms(String id) async {
    try { final r = await getList('/selectoption/getClassRooms?schoolId=${widget.schoolId}&stageId=$id'); if (mounted) setState(() { rooms = r; targetRoomId = null; }); }
    catch (e) { if (mounted) setState(() => error = '$e'); }
  }

  String stageOf(Map<String, dynamic> s) => '${s['stageId'] ?? s['studentStageId'] ?? ''}';
  String stageNameOf(Map<String, dynamic> s) => '${s['studentStage'] ?? s['stageName'] ?? s['stage'] ?? ''}';
  String selectedStageName() => stages.where((s) => '${s['id'] ?? s['value'] ?? ''}' == stageId).map((s) => '${s['displayName'] ?? s['name'] ?? s['label'] ?? ''}').firstWhere((x) => x.isNotEmpty, orElse: () => '');
  String name(Map<String, dynamic> s) {
    final f = s['fullName'] ?? s['studentName'];
    if ('$f'.trim().isNotEmpty) return '$f';
    return [s['name'], s['fatherName'], s['grandFatherName'], s['surName']].where((x) => x != null && '$x'.trim().isNotEmpty).join(' ');
  }

  List<Map<String, dynamic>> get current {
    if (stageId == null) return [];
    final label = selectedStageName();
    return students.where((s) => stageOf(s) == stageId || (label.isNotEmpty && stageNameOf(s) == label)).toList();
  }

  Future<Map<String, dynamic>> fullStudent(dynamic id) async {
    final r = await http.get(Uri.parse('https://emis.moedu.gov.iq/api/student/getstudent/$id'), headers: h);
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('قراءة الطالب $id: HTTP ${r.statusCode}');
    final d = unwrap(jsonDecode(utf8.decode(r.bodyBytes)));
    if (d is! Map) throw Exception('بيانات الطالب $id غير صالحة');
    return Map<String, dynamic>.from(d);
  }

  Future<void> _saveDistribution() async {
    if (stageId == null || targetRoomId == null || selected.isEmpty) return;
    setState(() { saving = true; error = null; });
    int ok = 0; String? last; final total = selected.length;
    try {
      for (final id in selected.toList()) {
        try {
          final dto = await fullStudent(id);
          dto['stageId'] = int.tryParse(stageId!);
          dto['classRoomId'] = int.tryParse(targetRoomId!);
          final r = await http.post(Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent'), headers: h, body: jsonEncode(dto));
          if (r.statusCode >= 200 && r.statusCode < 300) ok++; else last = 'الطالب $id: HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}';
        } catch (e) { last = '$e'; }
      }
      if (ok > 0) selected.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم توزيع $ok من $total طالب${last == null ? '' : '\nآخر خطأ: $last'}'), backgroundColor: ok > 0 ? Colors.green : Colors.red));
      if (mounted) setState(() {});
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final list = current;
    final roomName = rooms.where((r) => '${r['id'] ?? r['value']}' == targetRoomId).map((r) => '${r['displayName'] ?? r['name'] ?? r['label'] ?? ''}').isEmpty ? '' : rooms.where((r) => '${r['id'] ?? r['value']}' == targetRoomId).map((r) => '${r['displayName'] ?? r['name'] ?? r['label'] ?? ''}').first;
    return Scaffold(
      appBar: AppBar(title: const Text('توزيع الطلاب على الشُعَب', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF00695C), iconTheme: const IconThemeData(color: Colors.white)),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red), textDirection: TextDirection.rtl),
        DropdownButtonFormField<String>(value: stageId, isExpanded: true, decoration: const InputDecoration(labelText: 'الصف الدراسي', border: OutlineInputBorder()), items: stages.map((s) { final v='${s['id'] ?? s['value'] ?? ''}'; final l='${s['displayName'] ?? s['name'] ?? s['label'] ?? v}'; return DropdownMenuItem(value:v, child:Text(l)); }).where((x)=>x.value!.isNotEmpty).toList(), onChanged:(v){setState(()=>stageId=v); if(v!=null)_loadRooms(v);}),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: targetRoomId, isExpanded:true, decoration:const InputDecoration(labelText:'الشعبة المستهدفة',border:OutlineInputBorder()), items:rooms.map((r){final v='${r['id'] ?? r['value'] ?? ''}';final l='${r['displayName'] ?? r['name'] ?? r['label'] ?? v}';return DropdownMenuItem(value:v,child:Text(l));}).where((x)=>x.value!.isNotEmpty).toList(), onChanged:(v)=>setState(()=>targetRoomId=v)),
        const SizedBox(height:12),
        Card(child: ListTile(leading: const Icon(Icons.groups_outlined,color:Colors.teal), title: Text('طلاب الصف: ${list.length}'), subtitle: Text('المحددون للشعبة ${roomName.isEmpty ? 'المستهدفة' : roomName}: ${selected.length}'), trailing: TextButton(onPressed:list.isEmpty?null:()=>setState(()=>selected.length==list.length?selected.clear():selected.addAll(list.map((s)=>(s['id'] as num?)?.toInt() ?? int.tryParse('${s['id']}') ?? -1).where((id)=>id>0))), child: Text(selected.length==list.length?'إلغاء الكل':'اختيار الكل')))),
        const SizedBox(height: 8),
        ...list.map((s){final id=int.tryParse('${s['id']}') ?? -1; final checked=selected.contains(id); return CheckboxListTile(value:checked,onChanged:id<0?null:(_)=>setState(()=>checked?selected.remove(id):selected.add(id)),title:Text(name(s),textDirection:TextDirection.rtl),subtitle:Text('رقم الطالب: ${s['id'] ?? ''}'),controlAffinity:ListTileControlAffinity.leading);}),
        const SizedBox(height: 14),
        SizedBox(height:52,child:FilledButton.icon(onPressed:saving||stageId==null||targetRoomId==null||selected.isEmpty?null:_saveDistribution,icon:saving?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.swap_horiz),label:Text('تنفيذ التوزيع (${selected.length})'))),
      ]),
    );
  }
}
