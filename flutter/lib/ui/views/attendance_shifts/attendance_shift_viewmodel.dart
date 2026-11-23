import 'package:stacked/stacked.dart';
import '../../../models/inventory_item.dart';
import '../../../services/attendance_shift_service.dart';
import '../../../services/inventory_service.dart';
import '../../../services/staff_service.dart';

class AttendanceShiftViewModel extends BaseViewModel {
  AttendanceShiftViewModel(this._attendance, this._inventory, this._staff);
  final AttendanceShiftService _attendance;
  final InventoryService _inventory;
  final StaffService _staff;
  List<RestaurantBranch> branches = [];
  List<Map<String, dynamic>> staff = [];
  List<Map<String, dynamic>> attendanceRows = [];
  List<Map<String, dynamic>> shifts = [];
  Map<String, dynamic>? current;
  String? branchId;
  String errorMessage = '';
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();

  String get fromDate => _date(from);
  String get toDate => _date(to);
  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> initialise() async {
    setBusy(true); errorMessage = '';
    try {
      branches = await _inventory.branches();
      staff = await _staff.getStaff(active: true);
      if (branches.length == 1) branchId = branches.first.id;
      await reload();
    } catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> reload() async {
    setBusy(true); errorMessage = '';
    try {
      final results = await Future.wait([
        _attendance.currentAttendance(),
        _attendance.attendanceHistory(branchId: branchId, from: fromDate, to: toDate),
        _attendance.shifts(branchId: branchId, from: fromDate, to: toDate),
      ]);
      current = results[0] as Map<String, dynamic>?;
      attendanceRows = results[1] as List<Map<String, dynamic>>;
      shifts = results[2] as List<Map<String, dynamic>>;
    } catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> selectBranch(String? value) async { branchId = value; await reload(); }
  Future<void> selectRange(DateTime start, DateTime end) async { from = start; to = end; await reload(); }

  Future<void> checkIn(String selectedBranch, {String? note}) async {
    setBusy(true); errorMessage = '';
    try { await _attendance.checkIn(branchId: selectedBranch, note: note); await reload(); }
    catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> checkOut({String? note}) async {
    setBusy(true); errorMessage = '';
    try { await _attendance.checkOut(note: note); await reload(); }
    catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> createShift({required String employeeId, required String selectedBranch, required DateTime date, required String startTime, required String endTime, String? notes}) async {
    setBusy(true); errorMessage = '';
    try {
      await _attendance.createShift(branchId: selectedBranch, userId: employeeId, shiftDate: _date(date), startTime: startTime, endTime: endTime, notes: notes);
      await reload();
    } catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }

  Future<void> cancelShift(String id) async {
    setBusy(true); errorMessage = '';
    try { await _attendance.cancelShift(id); await reload(); }
    catch (error) { errorMessage = error.toString(); }
    finally { setBusy(false); }
  }
}
