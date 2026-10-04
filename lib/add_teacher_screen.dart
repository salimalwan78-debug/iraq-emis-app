import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddTeacherScreen extends StatefulWidget {
  final String token;
  final String schoolId;
  const AddTeacherScreen({super.key, required this.token, required this.schoolId});
  @override State<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;
  String? _error;
  final Map<String, List<Map<String,dynamic>>> _options = {};
  static const _endpoints = {
    'gender':'/selectoption/Gender','countryOfBirth':'/selectoption/بلد الولادة',
    'issuingCountry':'/selectoption/بلد الإصدار','idType':'/selectoption/IdentificationType',
    'motherTongue':'/selectoption/لغة','bloodGroup':'/selectoption/فصيلة الدم','religion':'/selectoption/الديانة',
  };
  @override void initState(){super.initState(); for(final k in ['name','fatherName','grandFatherName','fathersGrandFatherName','surName','motherName','mothersFatherName','mothersGrandFatherName','dateOfBirth','nationalId','employeeIdNumber','nationality','homeTown','employmentType','employeeCategory','classification','dateOfStartWorking','educationLevel','universityName','graduationYear','specialization']){_c[k]=TextEditingController();} _loadOptions();}
  @override void dispose(){for(final c in _c.values)c.dispose();super.dispose();}
  Map<String,String> get _headers=>{'Authorization':widget.token,'Accept':'application/json','Content-Type':'application/json'};
  Future<void> _loadOptions() async{for(final e in _endpoints.entries){try{final r=await http.get(Uri.parse('https://emis.moedu.gov.iq/api${e.value}'),headers:_headers);if(r.statusCode==200){final d=jsonDecode(utf8.decode(r.bodyBytes));final list=d is Map&&d['data'] is List?d['data']:d is List?d:[];_options[e.key]=list.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();}}catch(_){}}if(mounted)setState((){});}
  List<DropdownMenuItem<String>> _items(String key){return (_options[key]??[]).map((x){final value=(x['value']??x['id']??x['code']??'').toString();final label=(x['label']??x['name']??x['text']??x['description']??value).toString();return DropdownMenuItem(value:value,child:Text(label));}).where((x)=>x.value!=null&&x.value!.isNotEmpty).toList();}
  Widget _field(String key,String label,{bool required=false})=>TextFormField(controller:_c[key],textDirection:TextDirection.rtl,decoration:InputDecoration(labelText:'$label${required?' *':''}',border:const OutlineInputBorder()),validator:required?(v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null:null);
  Widget _drop(String key,String label,{bool required=false})=>DropdownButtonFormField<String>(value:_c[key]!.text.isEmpty?null:_c[key]!.text,decoration:InputDecoration(labelText:'$label${required?' *':''}',border:const OutlineInputBorder()),items:_items(key),onChanged:(v){if(v!=null)_c[key]!.text=v;},validator:required?(v)=>v==null||v.isEmpty?'هذا الحقل مطلوب':null:null);
  String? _n(String key)=>_c[key]!.text.trim().isEmpty?null:_c[key]!.text.trim();
  Future<void> _save() async{
    if(!(_formKey.currentState?.validate()??false))return;setState(()=>_saving=true);
    try{
      final payload={'Id':0,'EmployeeIdNumber':_n('employeeIdNumber'),'IsTeacher':true,'EmploymentType':_n('employmentType')??'','EmployeeCategory':_n('employeeCategory')??'','Classification':_n('classification')??'','DateOfStartWorking':_n('dateOfStartWorking'),'EducationLevel':_n('educationLevel'),'GraduationYear':_n('graduationYear'),'UniversityName':_n('universityName'),'Specialization':_n('specialization'),'Name':_n('name')??'','FatherName':_n('fatherName')??'','GrandFatherName':_n('grandFatherName')??'','FathersGrandFatherName':_n('fathersGrandFatherName')??'','SurName':_n('surName'),'MotherName':_n('motherName'),'MothersFatherName':_n('mothersFatherName'),'MothersGrandFatherName':_n('mothersGrandFatherName'),'DateOfBirth':_n('dateOfBirth'),'Gender':int.tryParse(_c['gender']!.text),'Nationality':_n('nationality')??'','CountryOfBirth':_n('countryOfBirth'),'HomeTown':_n('homeTown'),'IdentificationId':0,'Identification':{'IdNumber':_n('nationalId')??'','IssuingCountry':_n('issuingCountry'),'IdType':int.tryParse(_c['idType']!.text)},'ImageUrl':'','MotherTongue':_n('motherTongue'),'BloodGroup':_n('bloodGroup'),'Religion':_n('religion'),'EmploymentRecord':{'EmploymentStatuses':[{'StatusType':'مستمر','DisEngagementDate':null,'MinistryOfficialDocumentNumber':null,'Reason':null,'CurrentBelongToEntityId':int.tryParse(widget.schoolId)}],'EmploymentPositions':[]},'Address':{'AddressType':1,'Town':'','Area':'','Quarter':'','Street':'','ClosestLocation':'','countryStructureId':null,'Latitude':'0','Longitude':'0','ApartmentNumber':'','BuildingNumber':'','Address1':'','Address2':'','SchoolPhoneNumber':'','MobilePhoneNumber':'','Email':'','Fax':'','Website':''}};
      final r=await http.post(Uri.parse('https://emis.moedu.gov.iq/api/employee/addemployee'),headers:_headers,body:jsonEncode(payload));
      if(r.statusCode<200||r.statusCode>=300)throw Exception('HTTP ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تمت إضافة المعلم بنجاح'),backgroundColor:Colors.green));Navigator.pop(context,true);}
    }catch(e){if(mounted)setState(()=>_error='$e');}finally{if(mounted)setState(()=>_saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('إضافة معلم جديد',style:TextStyle(color:Colors.white)),backgroundColor:const Color(0xFF4527A0),iconTheme:const IconThemeData(color:Colors.white)),body:Form(key:_formKey,child:ListView(padding:const EdgeInsets.all(16),children:[if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red),textDirection:TextDirection.rtl),_field('name','الإسم',required:true),const SizedBox(height:10),_field('fatherName','إسم الأب',required:true),const SizedBox(height:10),_field('grandFatherName','اسم والد الأب',required:true),const SizedBox(height:10),_field('fathersGrandFatherName','اسم جد الأب'),const SizedBox(height:10),_field('surName','اللقب'),const SizedBox(height:10),_field('motherName','إسم الأم'),const SizedBox(height:10),_field('nationalId','رقم البطاقة الوطنية',required:true),const SizedBox(height:10),_field('employeeIdNumber','الرقم الوظيفي'),const SizedBox(height:10),Row(children:[Expanded(child:_drop('gender','الجنس',required:true)),const SizedBox(width:10),Expanded(child:_drop('idType','نوع الهوية',required:true))]),const SizedBox(height:10),Row(children:[Expanded(child:_drop('countryOfBirth','بلد الولادة')),const SizedBox(width:10),Expanded(child:_drop('issuingCountry','بلد الإصدار'))]),const SizedBox(height:10),Row(children:[Expanded(child:_drop('motherTongue','اللغة الأم')),const SizedBox(width:10),Expanded(child:_drop('religion','الديانة'))]),const SizedBox(height:10),_field('dateOfBirth','تاريخ التولد (YYYY-MM-DD)'),const SizedBox(height:10),_field('nationality','الجنسية'),const SizedBox(height:10),_field('homeTown','مسقط الرأس'),const SizedBox(height:10),Row(children:[Expanded(child:_field('employmentType','نوع التوظيف',required:true)),const SizedBox(width:10),Expanded(child:_field('employeeCategory','فئة الموظف'))]),const SizedBox(height:10),_field('classification','التصنيف'),const SizedBox(height:20),SizedBox(height:52,child:FilledButton.icon(onPressed:_saving?null:_save,icon:_saving?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save),label:const Text('حفظ المعلم')))]));)
}
