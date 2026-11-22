import 'package:flutter/material.dart';
import '../../../services/inventory_service.dart';

class SuppliersView extends StatefulWidget {
  const SuppliersView({super.key});
  @override
  State<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends State<SuppliersView> {
  final _service = InventoryService();
  List<Map<String,dynamic>> _suppliers = [];
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(()=>_loading=true);
    try{final data=await _service.suppliers();if(mounted)setState(()=>_suppliers=data);}
    catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  void _message(String v)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(v)));
  Future<void> _add() async {
    final name=TextEditingController(),phone=TextEditingController(),notes=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Add supplier'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Supplier name')),
      TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone')),
      TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    if(ok==true&&name.text.trim().isNotEmpty){setState(()=>_busy=true);try{await _service.createSupplier(name:name.text.trim(),phone:phone.text.trim(),notes:notes.text.trim());await _load();}catch(e){_message(e.toString());}finally{if(mounted)setState(()=>_busy=false);}}
    name.dispose();phone.dispose();notes.dispose();
  }
  Future<void> _ledger(Map<String,dynamic> supplier) async {
    try{
      final data=await _service.supplierLedger(supplier['id'].toString());
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('${supplier['name']} · Ledger'),
        content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          _metric('Purchase total',data['purchaseTotal']),_metric('Paid total',data['paidTotal']),_metric('Outstanding',data['outstanding']),
          const Divider(),
          const Text('Purchases',style:TextStyle(fontWeight:FontWeight.bold)),
          ...(data['purchases'] as List? ?? []).map((p)=>ListTile(contentPadding:EdgeInsets.zero,title:Text('${p['purchaseNumber']}'),subtitle:Text('${p['date']}'),trailing:Text('Due: ${p['due']}'))),
          const Text('Payments',style:TextStyle(fontWeight:FontWeight.bold)),
          ...(data['payments'] as List? ?? []).map((p)=>ListTile(contentPadding:EdgeInsets.zero,title:Text('${p['method']} · PKR ${p['amount']}'),subtitle:Text('${p['createdAt']}'))),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))],
      ));
    }catch(e){_message(e.toString());}
  }
  Widget _metric(String label,dynamic value)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(label),Text('PKR ${value??0}',style:const TextStyle(fontWeight:FontWeight.bold))]));
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Suppliers'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    floatingActionButton:FloatingActionButton.extended(onPressed:_busy?null:_add,icon:const Icon(Icons.add),label:const Text('Add supplier')),
    body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Text(_error!)):_suppliers.isEmpty?const Center(child:Text('No suppliers yet. Add your first supplier.')):ListView.separated(padding:const EdgeInsets.all(12),itemCount:_suppliers.length,separatorBuilder:(_,__)=>const SizedBox(height:6),itemBuilder:(ctx,i){final s=_suppliers[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.local_shipping_outlined)),title:Text(s['name']?.toString()??'Supplier'),subtitle:Text(s['phone']?.toString()??'No phone'),trailing:const Icon(Icons.chevron_right),onTap:()=>_ledger(s)));}),
  );
}
