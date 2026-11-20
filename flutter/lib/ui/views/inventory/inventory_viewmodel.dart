import 'package:stacked/stacked.dart';
import '../../../models/inventory_item.dart';
import '../../../services/inventory_service.dart';
class InventoryViewModel extends BaseViewModel {
  InventoryViewModel(this._service);
  final InventoryService _service;
  String branchId='';
  List<RestaurantBranch> branches=[];
  List<BranchStockEntry> stockEntries=[];
  List<InventoryItem> catalog=[];
  List<BranchStockEntry> lowStockEntries=[];
  String? errorMessage;
  Future<void> load() async {
    setBusy(true);errorMessage=null;notifyListeners();
    try {
      branches=await _service.branches();
      if(branches.isEmpty){branchId='';stockEntries=[];lowStockEntries=[];catalog=await _service.items();return;}
      if(!branches.any((b)=>b.id==branchId))branchId=branches.first.id;
      final results=await Future.wait([_service.items(),_service.stock(branchId),_service.lowStock(branchId)]);
      catalog=results[0] as List<InventoryItem>;
      stockEntries=results[1] as List<BranchStockEntry>;
      lowStockEntries=results[2] as List<BranchStockEntry>;
    }catch(e){errorMessage=e.toString();}
    finally{setBusy(false);notifyListeners();}
  }

  Future<void> setBranch(String value) async {branchId=value;await load();}
  Future<void> addItem({required String name,required String itemType,required String unit,String? sku}) async {
    setBusy(true);errorMessage=null;notifyListeners();
    try{await _service.createItem(name:name,itemType:itemType,unit:unit,sku:sku);await load();}
    catch(e){errorMessage=e.toString();}
    finally{setBusy(false);notifyListeners();}
  }
}
