import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StudentStageTransferScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  final List<dynamic> allStudents;
  const StudentStageTransferScreen({super.key, required this.token, required this.schoolId, required this.allStudents});
  @override State<StudentStageTransferScreen> createState() => _StudentStageTransferScreenState();
}

class _StudentStageTransferScreenState extends State<StudentStageTransferScreen> {
  late List<Map<String,dynamic>> students;
  List<Map<String,dynamic>> stages=[];
  String? fromStage, toStage;
  final Set<int> selected={};
  bool loading=true,saving=false;
  String? error;
  Map<String,String> get h=>{'Authorization':widget.token,'Accept':'application/json','Content-Type':'application/json'};
  dynamic unwrap(dynamic d)=>d is Map&&d['data']!=null?d['data']:d;
  @override void initState(){super.initState();students=widget.allStudents.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();_load();}
  Future<List<Map<String,dynamic>>> getList(String ep)async{final r=await http.get(Uri.parse('https://emis.moedu.gov.iq/api$ep'),headers:h);if(r.statusCode<200||r.statusCode>=300)throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');final d=unwrap(jsonDecode(utf8.decode(r.bodyBytes)));return d is List?d.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];}
  Future<void> _load()async{try{stages=await getList('/selectoption/getAvailableStagesForStudent?schoolId=${widget.schoolId}');if(mounted)setState(()=>loading=false);}catch(e){if(mounted)setState(() { loading=false; error='$e'; });}}
  String stageOf(Map<String,dynamic>s)=>'${s['stageId']??s['studentStageId']??''}';
  String stageNameOf(Map<String,dynamic>s)=>'${s['studentStage']??s['stageName']??s['stage']??''}';
  String stageLabel(String? id)=>stages.where((s)=>'${s['id']??s['value']??''}'==id).map((s)=>'${s['displayName']??s['name']??s['label']??''}').firstWhere((x)=>x.isNotEmpty,orElse:()=> '');
  String name(Map<String,dynamic>s){final f=s['fullName']??s['studentName'];if('$f'.trim().isNotEmpty)return '$f';return [s['name'],s['fatherName'],s['grandFatherName'],s['surName']].where((x)=>x!=null&&'$x'.trim().isNotEmpty).join(' ');}
  List<Map<String,dynamic>> get current { if(fromStage==null)return []; final label=stageLabel(fromStage); return students.where((s)=>stageOf(s)==fromStage || (label.isNotEmpty && stageNameOf(s)==label)).toList(); }
  Future<Map<String,dynamic>> full(dynamic id)async{final r=await http.get(Uri.parse('https://emis.moedu.gov.iq/api/student/getstudent/$id'),headers:h);if(r.statusCode<200||r.statusCode>=300)throw Exception('قراءة الطالب $id: HTTP ${r.statusCode}');final d=unwrap(jsonDecode(utf8.decode(r.bodyBytes)));if(d is! Map)throw Exception('بيانات الطالب غير صالحة');return Map<String,dynamic>.from(d);}
  Future<void> _run()async{if(fromStage==null||toStage==null||fromStage==toStage||selected.isEmpty)return;setState(()=>saving=true);int ok=0;String? last;final total=selected.length;try{for(final id in selected.toList()){try{final dto=await full(id);dto['stageId']=int.tryParse(toStage!);dto['classRoomId']=null;final r=await http.post(Uri.parse('https://emis.moedu.gov.iq/api/student/updatestudent'),headers:h,body:jsonEncode(dto));if(r.statusCode>=200&&r.statusCode<300)ok++;else last='الطالب $id: HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}';}catch(e){last='$e';}}if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم ترحيل $ok من $total طالب${last==null?'':'\nآخر خطأ: $last'}'),backgroundColor:ok>0?Colors.green:Colors.red));selected.clear();setState((){});}}finally{if(mounted)setState(()=>saving=false);}}
  @override
  Widget build(BuildContext context) {
    final list = current;
    return Scaffold(
      appBar: AppBar(title: const Text('ترحيل الطلاب بين الصفوف', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF00695C), iconTheme: const IconThemeData(color: Colors.white)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red), textDirection: TextDirection.rtl),
                DropdownButtonFormField<String>(
                  value: fromStage,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصف الحالي', border: OutlineInputBorder()),
                  items: stages.map((s) {
                    final v = '${s['id'] ?? s['value'] ?? ''}';
                    final l = '${s['displayName'] ?? s['name'] ?? s['label'] ?? v}';
                    return DropdownMenuItem(value: v, child: Text(l));
                  }).where((x) => x.value!.isNotEmpty).toList(),
                  onChanged: (v) => setState(() { fromStage = v; selected.clear(); }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: toStage,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصف الدراسي المستهدف', border: OutlineInputBorder()),
                  items: stages.map((s) {
                    final v = '${s['id'] ?? s['value'] ?? ''}';
                    final l = '${s['displayName'] ?? s['name'] ?? s['label'] ?? v}';
                    return DropdownMenuItem(value: v, child: Text(l));
                  }).where((x) => x.value!.isNotEmpty && x.value != fromStage).toList(),
                  onChanged: (v) => setState(() => toStage = v),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_outlined, color: Colors.teal),
                    title: Text('طلاب الصف الحالي: ${list.length}'),
                    trailing: TextButton(
                      onPressed: list.isEmpty ? null : () => setState(() {
                        if (selected.length == list.length) {
                          selected.clear();
                        } else {
                          selected.addAll(list.map((s) => int.tryParse('${s['id']}') ?? -1).where((id) => id > 0));
                        }
                      }),
                      child: Text(selected.length == list.length ? 'إلغاء الكل' : 'اختيار الكل'),
                    ),
                  ),
                ),
                ...list.map((s) {
                  final id = int.tryParse('${s['id']}') ?? -1;
                  final checked = selected.contains(id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: id < 0 ? null : (_) => setState(() => checked ? selected.remove(id) : selected.add(id)),
                    title: Text(name(s), textDirection: TextDirection.rtl),
                    subtitle: Text('رقم الطالب: ${s['id'] ?? ''}'),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: saving || fromStage == null || toStage == null || fromStage == toStage || selected.isEmpty ? null : _run,
                    icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.move_up),
                    label: Text('تنفيذ الترحيل (${selected.length})'),
                  ),
                ),
              ],
            ),
    );
  }
}
