import 'package:stacked/stacked.dart';
import '../../../models/inventory_item.dart';
import '../../../services/branch_operations_service.dart';
import '../../../services/inventory_service.dart';

class BranchOperationsViewModel extends BaseViewModel {
  BranchOperationsViewModel(this._operations, this._inventory);
  final BranchOperationsService _operations;
  final InventoryService _inventory;
  List<RestaurantBranch> branches = [];
  String? branchId;
  Map<String, dynamic> purchases = {};
  List<Map<String, dynamic>> auditItems = [];
  String errorMessage = '';
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();

  String get fromDate => _date(from);
  String get toDate => _date(to);
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> initialise() async {
    setBusy(true); errorMessage = '';
    try { branches = await _inventory.branches(); await loadAll(); }
    catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> selectBranch(String? value) async { branchId = value; await loadAll(); }
  Future<void> selectRange(DateTime start, DateTime end) async { from = start; to = end; await loadAll(); }

  Future<void> loadAll() async {
    setBusy(true); errorMessage = '';
    try {
      final results = await Future.wait([
        _operations.purchaseAnalytics(from: fromDate, to: toDate, branchId: branchId),
        _operations.auditHistory(branchId: branchId, from: fromDate, to: toDate),
      ]);
      purchases = results[0];
      auditItems = (results[1]['items'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }
}
