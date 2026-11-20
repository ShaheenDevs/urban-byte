import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/inventory_service.dart';
import 'stock_operations_view.dart';
import 'inventory_viewmodel.dart';
class InventoryView extends StackedView<InventoryViewModel> {
  const InventoryView({super.key});
  @override InventoryViewModel viewModelBuilder(BuildContext context)=>InventoryViewModel(locator<InventoryService>())..load();
  @override Widget builder(BuildContext context,InventoryViewModel vm,Widget? child)=>Scaffold(
    appBar:AppBar(title:const Text('Inventory')),
    floatingActionButton:FloatingActionButton.extended(onPressed:vm.isBusy?null:()=>_addItem(context,vm),icon:const Icon(Icons.add),label:const Text('Add item')),
    body:RefreshIndicator(onRefresh:vm.load,child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:Text('Branch stock overview',style:Theme.of(context).textTheme.titleLarge)),TextButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const StockOperationsView())),icon:const Icon(Icons.tune),label:const Text('Operations'))]),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        value: vm.branchId.isEmpty ? null : vm.branchId,
        decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
        items: vm.branches.map((branch) => DropdownMenuItem(value: branch.id, child: Text(branch.name))).toList(),
        onChanged: vm.isBusy ? null : (value) { if (value != null) vm.setBranch(value); },
      ),
      const SizedBox(height:16),
      if(vm.isBusy)const LinearProgressIndicator(),
      if(vm.errorMessage!=null) ...[const SizedBox(height:12),Text(vm.errorMessage!,style:TextStyle(color:Theme.of(context).colorScheme.error)),TextButton(onPressed:vm.load,child:const Text('Retry'))],
      Row(children:[
        Expanded(child:_MetricCard(label:'Catalog items',value:'${vm.catalog.length}',icon:Icons.inventory_2_outlined)),
        const SizedBox(width:10),
        Expanded(child:_MetricCard(label:'Low stock',value:'${vm.lowStockEntries.length}',icon:Icons.warning_amber_rounded)),
      ]),
      const SizedBox(height:20),
      Text('Branch stock',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:8),
      if(!vm.isBusy&&vm.stockEntries.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('No stock records found for this branch. Add inventory items and receive purchases to build stock.'))),
      ...vm.stockEntries.map((entry)=>Card(child:ListTile(
        leading:CircleAvatar(child:Icon(entry.lowStock?Icons.warning_amber:Icons.inventory_2_outlined)),
        title:Text(entry.item.name),
        subtitle:Text('${entry.item.itemType} • Reorder at ${entry.reorderLevel.toStringAsFixed(3)} ${entry.item.unit}'),
        trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text(entry.quantity.toStringAsFixed(3),style:Theme.of(context).textTheme.titleMedium),
          if(entry.lowStock)const Text('LOW',style:TextStyle(color:Colors.red,fontWeight:FontWeight.bold)),
        ]),
      ))),
      const SizedBox(height:80),
    ])),
  );
  Future<void> _addItem(BuildContext context,InventoryViewModel vm) async {
    final name=TextEditingController(),unit=TextEditingController(text:'piece'),sku=TextEditingController();
    String type='ingredient';
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
      title:const Text('New inventory item'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Item name')),
        TextField(controller:unit,decoration:const InputDecoration(labelText:'Base unit (g, kg, ml, piece)')),
        TextField(controller:sku,decoration:const InputDecoration(labelText:'SKU (optional)')),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Item type'),items:const [
          DropdownMenuItem(value:'ingredient',child:Text('Ingredient')),
          DropdownMenuItem(value:'finished_good',child:Text('Finished good')),
          DropdownMenuItem(value:'packaging',child:Text('Packaging')),
          DropdownMenuItem(value:'other',child:Text('Other')),
        ],onChanged:(value){if(value!=null)setState(()=>type=value);}),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),
        FilledButton(onPressed:(){if(name.text.trim().isEmpty||unit.text.trim().isEmpty)return;Navigator.pop(dialogContext);vm.addItem(name:name.text.trim(),itemType:type,unit:unit.text.trim(),sku:sku.text.trim());},child:const Text('Save')),
      ],
    )));
    name.dispose();unit.dispose();sku.dispose();
  }
}
class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label,required this.value,required this.icon});
  final String label,value;final IconData icon;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
    Icon(icon,size:28),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,style:Theme.of(context).textTheme.headlineSmall),Text(label,style:Theme.of(context).textTheme.bodySmall),
    ])),
  ])));
}
