import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/expense_service.dart';

class ExpenseView extends StackedView<ExpenseViewModel> {
  const ExpenseView({super.key});
  @override
  ExpenseViewModel viewModelBuilder(BuildContext context)=>ExpenseViewModel(locator<ExpenseService>());
  @override
  Widget builder(BuildContext context,ExpenseViewModel model,Widget? child){
    return Scaffold(
      appBar:AppBar(title:const Text('Expense Management'),actions:[IconButton(onPressed:model.load,icon:const Icon(Icons.refresh))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>_addExpense(context,model),icon:const Icon(Icons.add),label:const Text('Add expense')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,12,16,4),child:Row(children:[
          Expanded(child:DropdownButtonFormField<String>(value:model.status,decoration:const InputDecoration(labelText:'Status',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'all',child:Text('All expenses')),DropdownMenuItem(value:'pending',child:Text('Pending')),DropdownMenuItem(value:'approved',child:Text('Approved')),DropdownMenuItem(value:'rejected',child:Text('Rejected'))],onChanged:(v){if(v!=null)model.setStatus(v);})),
          const SizedBox(width:12),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Approved total',style:TextStyle(fontSize:12)),Text('Rs. ${model.approvedTotal.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))]))))
        ])),
        if(model.errorMessage!=null)Padding(padding:const EdgeInsets.all(12),child:Text(model.errorMessage!,style:const TextStyle(color:Colors.red))),
        Expanded(child:model.isBusy?const Center(child:CircularProgressIndicator()):model.expenses.isEmpty?const Center(child:Text('No expenses found.')):RefreshIndicator(onRefresh:model.load,child:ListView.separated(padding:const EdgeInsets.all(12),itemCount:model.expenses.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,index){
          final e=model.expenses[index];final id=int.tryParse(e['id'].toString())??0;final status=(e['status']??'pending').toString();
          return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(e['category']??'Expense',style:Theme.of(context).textTheme.titleMedium)),_StatusChip(status)]),
            const SizedBox(height:4),Text(e['description']??''),const SizedBox(height:8),
            Row(children:[Expanded(child:Text('Rs. ${e['amount']??'0'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),Text((e['expenseDate']??'').toString())]),
            Text('Payment: ${e['paymentMethod']??'-'}',style:Theme.of(context).textTheme.bodySmall),
            if(status=='pending')Align(alignment:Alignment.centerRight,child:Wrap(spacing:8,children:[
              TextButton.icon(onPressed:()=>_reject(context,model,id),icon:const Icon(Icons.close),label:const Text('Reject')),
              FilledButton.icon(onPressed:()=>model.approve(id),icon:const Icon(Icons.check),label:const Text('Approve'))
            ]))
          ])));
        })))
      ]),
    );
  }
  Future<void> _addExpense(BuildContext context,ExpenseViewModel model) async {
    final form=GlobalKey<FormState>();final branch=TextEditingController();final category=TextEditingController();final description=TextEditingController();final amount=TextEditingController();final reference=TextEditingController();
    var method='cash';var date=DateTime.now();
    final saved=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>AlertDialog(title:const Text('New expense'),content:SizedBox(width:440,child:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:branch,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Branch ID'),validator:(v)=>int.tryParse(v??'')==null?'Enter branch ID':null),
      TextFormField(controller:category,decoration:const InputDecoration(labelText:'Category (e.g. Rent, Electricity)'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null),
      TextFormField(controller:description,decoration:const InputDecoration(labelText:'Description'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null),
      TextFormField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount (Rs.)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<=0?'Enter valid amount':null),
      DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Payment method'),items:const ['cash','card','bank_transfer','easypaisa','jazzcash'].map((v)=>DropdownMenuItem(value:v,child:Text(v.replaceAll('_',' ')))).toList(),onChanged:(v)=>setState(()=>method=v??'cash')),
      TextFormField(controller:reference,decoration:const InputDecoration(labelText:'Reference (optional)')),
      TextButton.icon(onPressed:()async{final picked=await showDatePicker(context:ctx,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(picked!=null)setState(()=>date=picked);},icon:const Icon(Icons.calendar_today),label:Text('Date: ${date.toIso8601String().substring(0,10)}'))
    ])))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>form.currentState!.validate()?Navigator.pop(ctx,true):null,child:const Text('Submit for approval'))])));
    if(saved==true){await model.create(branchId:int.parse(branch.text),category:category.text,description:description.text,amount:double.parse(amount.text),paymentMethod:method,expenseDate:date.toIso8601String().substring(0,10),reference:reference.text);}
    branch.dispose();category.dispose();description.dispose();amount.dispose();reference.dispose();
  }
  Future<void> _reject(BuildContext context,ExpenseViewModel model,int id) async {
    final controller=TextEditingController();final reason=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Reject expense'),content:TextField(controller:controller,decoration:const InputDecoration(labelText:'Reason'),maxLines:3),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>controller.text.trim().isEmpty?null:Navigator.pop(ctx,controller.text.trim()),child:const Text('Reject'))]));
    if(reason!=null)await model.reject(id,reason);controller.dispose();
  }
}
class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);final String status;
  @override Widget build(BuildContext context)=>Chip(label:Text(status.toUpperCase()),visualDensity:VisualDensity.compact);
}
class ExpenseViewModel extends BaseViewModel {
  ExpenseViewModel(this._service){load();}
  final ExpenseService _service;List<Map<String,dynamic>> expenses=[];String status='all';String? errorMessage;double approvedTotal=0;
  Future<void> load() async {setBusy(true);errorMessage=null;try{expenses=await _service.getExpenses(status:status);final approved=await _service.getExpenses(status:'approved');approvedTotal=approved.fold<double>(0,(sum,e)=>sum+(double.tryParse(e['amount'].toString())??0));}catch(e){errorMessage=e.toString();}setBusy(false);notifyListeners();}
  Future<void> setStatus(String value) async {status=value;await load();}
  Future<void> create({required int branchId,required String category,required String description,required double amount,required String paymentMethod,required String expenseDate,String? reference}) async {setBusy(true);try{await _service.create(branchId:branchId,category:category,description:description,amount:amount,paymentMethod:paymentMethod,expenseDate:expenseDate,reference:reference);await load();}catch(e){errorMessage=e.toString();}setBusy(false);notifyListeners();}
  Future<void> approve(int id) async {setBusy(true);try{await _service.approve(id);await load();}catch(e){errorMessage=e.toString();}setBusy(false);notifyListeners();}
  Future<void> reject(int id,String reason) async {setBusy(true);try{await _service.reject(id,reason);await load();}catch(e){errorMessage=e.toString();}setBusy(false);notifyListeners();}
}