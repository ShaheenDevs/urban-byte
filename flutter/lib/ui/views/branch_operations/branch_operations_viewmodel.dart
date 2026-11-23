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
  String auditAction = '';
  String auditEntityType = '';
  int auditPage = 1;
  int auditTotal = 0;
  bool auditHasMore = false;
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();

  String get fromDate => _date(from);
  String get toDate => _date(to);
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> initialise() async {
    setBusy(true);
    errorMessage = '';
    try {
      branches = await _inventory.branches();
      await loadAll();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      setBusy(false);
    }
  }

  Future<void> selectBranch(String? value) async {
    branchId = value;
    await loadAll();
  }

  Future<void> selectRange(DateTime start, DateTime end) async {
    from = start;
    to = end;
    await loadAll();
  }

  Future<void> applyAuditFilters({String? action, String? entityType}) async {
    if (action != null) auditAction = action.trim();
    if (entityType != null) auditEntityType = entityType.trim();
    await loadAll();
  }

  Future<void> loadMoreAudit() async {
    if (isBusy || !auditHasMore) return;
    setBusy(true);
    try {
      final result = await _operations.auditHistory(
        branchId: branchId,
        action: auditAction,
        entityType: auditEntityType,
        from: fromDate,
        to: toDate,
        page: auditPage + 1,
      );
      final nextItems = (result['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      auditItems = [...auditItems, ...nextItems];
      auditPage = (result['pagination'] is Map
          ? int.tryParse((result['pagination'] as Map)['page']?.toString() ?? '')
          : null) ?? auditPage + 1;
      auditTotal = (result['pagination'] is Map
          ? int.tryParse((result['pagination'] as Map)['total']?.toString() ?? '')
          : null) ?? auditTotal;
      auditHasMore = auditItems.length < auditTotal && nextItems.isNotEmpty;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      setBusy(false);
    }
  }

  Future<void> loadAll() async {
    setBusy(true);
    errorMessage = '';
    try {
      final results = await Future.wait([
        _operations.purchaseAnalytics(from: fromDate, to: toDate, branchId: branchId),
        _operations.auditHistory(
          branchId: branchId,
          action: auditAction,
          entityType: auditEntityType,
          from: fromDate,
          to: toDate,
          page: 1,
        ),
      ]);
      purchases = results[0];
      final auditResult = results[1];
      auditItems = (auditResult['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final pagination = auditResult['pagination'] is Map
          ? auditResult['pagination'] as Map
          : const {};
      auditPage = int.tryParse(pagination['page']?.toString() ?? '') ?? 1;
      auditTotal = int.tryParse(pagination['total']?.toString() ?? '') ?? auditItems.length;
      auditHasMore = auditItems.length < auditTotal;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      setBusy(false);
    }
  }
}
