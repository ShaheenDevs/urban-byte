import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../services/staff_service.dart';
import '../../../app/app.locator.dart';

class StaffView extends StackedView<StaffViewModel> {
  const StaffView({super.key});
  @override
  StaffViewModel viewModelBuilder(BuildContext context)=>StaffViewModel(locator<StaffService>());

  @override
  Widget builder(BuildContext context,StaffViewModel model,Widget? child){
    return Scaffold(
      appBar:AppBar(title:const Text('Staff Management'),actions:[IconButton(onPressed:model.load,icon:const Icon(Icons.refresh))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>_showAdd(context,model),icon:const Icon(Icons.person_add),label:const Text('Add staff')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(16),child:TextField(onChanged:model.search,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search name, email or phone',border:OutlineInputBorder()))),
        Expanded(child:model.isBusy?const Center(child:CircularProgressIndicator()):model.errorMessage!=null?Center(child:Text(model.errorMessage!)):model.staff.isEmpty?const Center(child:Text('No staff members found.')):RefreshIndicator(onRefresh:model.load,child:ListView.separated(itemCount:model.staff.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,index){final user=model.staff[index];final roles=(user['roles'] as List? ?? []).map((r)=>(r as Map)['name']??'').join(', ');return ListTile(leading:CircleAvatar(child:Text((user['name']??'?').toString().characters.first.toUpperCase())),title:Text(user['name']??'Unnamed'),subtitle:Text('${user['email']??user['phone']??''}\n$roles'),isThreeLine:true,trailing:Icon(user['isActive']==true?Icons.check_circle:Icons.block,color:user['isActive']==true?Colors.green:Colors.grey));}))),
      ]),
    );
  }

  Future<void> _showAdd(BuildContext context,StaffViewModel model) async {
    final form=GlobalKey<FormState>();final name=TextEditingController(),contact=TextEditingController(),password=TextEditingController();final roles=await model.loadRoles();
    if(!context.mounted)return;
    final selected=<int>{};
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(title:const Text('Add staff member'),content:SizedBox(width:420,child:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'Full name'),validator:(v)=>v==null||v.trim().length<2?'Enter a valid name':null),
      TextFormField(controller:contact,decoration:const InputDecoration(labelText:'Email or phone'),validator:(v)=>v==null||v.trim().isEmpty?'Email or phone required':null),
      TextFormField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Temporary password (12+ characters)'),validator:(v)=>v==null||v.length<12?'Minimum 12 characters':null),
      const SizedBox(height:12),const Align(alignment:Alignment.centerLeft,child:Text('Roles')),
      ...roles.map((r){final id=int.tryParse(r['id'].toString());if(id==null)return const SizedBox.shrink();return CheckboxListTile(value:selected.contains(id),title:Text(r['name']??r['slug']??'Role'),dense:true,contentPadding:EdgeInsets.zero,onChanged:(v)=>setState((){if(v==true){selected.add(id);}else{selected.remove(id);}}));})
    ])))),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:()=>form.currentState!.validate()&&selected.isNotEmpty?Navigator.pop(dialogContext,true):null,child:const Text('Create'))])));
    if(!context.mounted)return;
    // Creation is submitted only after explicit confirmation in the dialog.
    if(selected.isNotEmpty&&name.text.trim().isNotEmpty&&contact.text.trim().isNotEmpty&&password.text.length>=12){await model.create(name.text,contact.text,password.text,selected.toList());}
    name.dispose();contact.dispose();password.dispose();
  }
}

class StaffViewModel extends BaseViewModel {
  StaffViewModel(this._service){load();}
  final StaffService _service;
  List<Map<String,dynamic>> staff=[];
  String? errorMessage;
  Future<void> load() async {setBusy(true);errorMessage=null;try{staff=await _service.getStaff();}catch(e){errorMessage=e.toString();}setBusy(false);notifyListeners();}
  Future<void> search(String value) async {try{staff=await _service.getStaff(search:value);notifyListeners();}catch(e){errorMessage=e.toString();notifyListeners();}}
  Future<List<Map<String,dynamic>>> loadRoles() async {try{return await _service.getRoles();}catch(e){errorMessage=e.toString();notifyListeners();return [];}}
  Future<void> create(String name,String contact,String password,List<int> roles) async {setBusy(true);try{await _service.createStaff(name:name,contact:contact,password:password,roleIds:roles);await load();}catch(e){errorMessage=e.toString();}setBusy(false);notifyListeners();}
}