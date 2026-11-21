import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/financial_report_service.dart';

class FinancialReportView extends StackedView<FinancialReportViewModel> {
  const FinancialReportView({super.key});
  @override
  FinancialReportViewModel viewModelBuilder(BuildContext context)=>FinancialReportViewModel(locator<FinancialReportService>());
  @override
  Widget builder(BuildContext context,FinancialReportViewModel vm,Widget? child)=>Scaffold(
    appBar:AppBar(title:const Text('Financial Dashboard'),actions:[IconButton(onPressed:vm.load,icon:const Icon(Icons.refresh))]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[
        Expanded(child:TextFormField(initialValue:vm.from,decoration:const InputDecoration(labelText:'From (YYYY-MM-DD)',border:OutlineInputBorder()),onChanged:vm.setFrom)),
        const SizedBox(width:10),
        Expanded(child:TextFormField(initialValue:vm.to,decoration:const InputDecoration(labelText:'To (YYYY-MM-DD)',border:OutlineInputBorder()),onChanged:vm.setTo))
      ]),
      const SizedBox(height:10),
      TextField(decoration:const InputDecoration(labelText:'Branch ID (optional)',border:OutlineInputBorder()),keyboardType:TextInputType.number,onChanged:vm.setBranch),
      const SizedBox(height:10),
      FilledButton.icon(onPressed:vm.load,icon:const Icon(Icons.assessment),label:const Text('Generate report')),
      if(vm.error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(vm.error!,style:const TextStyle(color:Colors.red))),
      if(vm.isBusy)const LinearProgressIndicator(),
      if(vm.data!=null)...[
        const SizedBox(height:18),
        Text('Collections',style:Theme.of(context).textTheme.titleLarge),
        _MetricCard('Verified collections','PKR ${_money(vm.data!['collections']?['total'])}',Icons.payments),
        _MetricCard('Approved expenses','PKR ${_money(vm.data!['approvedExpenses']?['total'])}',Icons.receipt_long),
        _MetricCard('Received purchases','PKR ${_money(vm.data!['purchases']?['receivedTotal'])}',Icons.inventory_2),
        _MetricCard('Supplier payments','PKR ${_money(vm.data!['supplierPayments']?['total'])}',Icons.account_balance_wallet),
        _MetricCard('Supplier outstanding','PKR ${_money(vm.data!['purchases']?['supplierOutstanding'])}',Icons.pending_actions),
        const SizedBox(height:12),
        Text('Cash Flow',style:Theme.of(context).textTheme.titleLarge),
        _MetricCard('Cash collections','PKR ${_money(vm.data!['cashFlow']?['cashCollections'])}',Icons.south_west),
        _MetricCard('Cash expenses','PKR ${_money(vm.data!['cashFlow']?['cashExpenses'])}',Icons.north_east),
        _MetricCard('Cash supplier payments','PKR ${_money(vm.data!['cashFlow']?['cashSupplierPayments'])}',Icons.store),
        _MetricCard('Net cash movement','PKR ${_money(vm.data!['cashFlow']?['netCashMovement'])}',Icons.account_balance),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Text(vm.data!['accountingNotes']?['reason']??'Financial report totals are based on verified collections and approved expenses.'))),
      ]
    ]),
  );
  static String _money(dynamic value)=>(double.tryParse(value?.toString()??'')??0).toStringAsFixed(2);
}
class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label,this.value,this.icon);
  final String label,value;final IconData icon;
  @override Widget build(BuildContext context)=>Card(child:ListTile(leading:Icon(icon),title:Text(label),trailing:Text(value,style:const TextStyle(fontWeight:FontWeight.bold))));
}
class FinancialReportViewModel extends BaseViewModel {
  FinancialReportViewModel(this._service){final now=DateTime.now();from=_date(now);to=from;load();}
  final FinancialReportService _service;late String from,to;String? branchId,error;Map<String,dynamic>? data;
  static String _date(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  void setFrom(String v){from=v;}void setTo(String v){to=v;}void setBranch(String v){branchId=v;}
  Future<void> load()async{setBusy(true);error=null;try{data=await _service.load(from:from,to:to,branchId:branchId);}catch(e){error=e.toString();}setBusy(false);notifyListeners();}
}