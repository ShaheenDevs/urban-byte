import 'package:stacked/stacked.dart';
import '../../../models/inventory_item.dart';
import '../../../services/inventory_service.dart';
import '../../../services/stock_transfer_service.dart';

class StockTransferViewModel extends BaseViewModel {
  StockTransferViewModel(this._transfers, this._inventory);
  final StockTransferService _transfers;
  final InventoryService _inventory;
  List<RestaurantBranch> branches = [];
  List<InventoryItem> catalog = [];
  List<Map<String, dynamic>> transfers = [];
  String? branchId;
  String? status;
  String errorMessage = '';

  Future<void> initialise() async {
    setBusy(true); errorMessage = '';
    try {
      final results = await Future.wait([_inventory.branches(), _inventory.items()]);
      branches = results[0] as List<RestaurantBranch>;
      catalog = results[1] as List<InventoryItem>;
      if (branches.length == 1) branchId = branches.first.id;
      await reload();
    } catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> reload() async {
    setBusy(true); errorMessage = '';
    try { transfers = await _transfers.list(branchId: branchId, status: status); }
    catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> filter({String? branch, String? newStatus}) async {
    branchId = branch;
    status = newStatus;
    await reload();
  }

  Future<void> create({
    required String sourceBranchId,
    required String destinationBranchId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    setBusy(true); errorMessage = '';
    try {
      await _transfers.create(sourceBranchId: sourceBranchId, destinationBranchId: destinationBranchId, items: items, note: note);
      await reload();
    } catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> approve(String id) async => _mutate(() => _transfers.approve(id));
  Future<void> reject(String id, {String? note}) async => _mutate(() => _transfers.reject(id, note: note));
  Future<void> receive(String id, List<Map<String, dynamic>> items) async => _mutate(() => _transfers.receive(id, items));

  Future<void> _mutate(Future<Map<String, dynamic>> Function() action) async {
    setBusy(true); errorMessage = '';
    try { await action(); await reload(); }
    catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }
}
