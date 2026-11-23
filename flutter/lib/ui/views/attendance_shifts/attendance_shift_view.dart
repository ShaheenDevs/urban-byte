import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/attendance_shift_service.dart';
import '../../../services/inventory_service.dart';
import '../../../services/staff_service.dart';
import 'attendance_shift_viewmodel.dart';

class AttendanceShiftView extends StackedView<AttendanceShiftViewModel> {
  const AttendanceShiftView({super.key});

  @override
  AttendanceShiftViewModel viewModelBuilder(BuildContext context) =>
      AttendanceShiftViewModel(locator<AttendanceShiftService>(), locator<InventoryService>(), locator<StaffService>());

  @override
  void onViewModelReady(AttendanceShiftViewModel model) => model.initialise();

  @override
  Widget builder(BuildContext context, AttendanceShiftViewModel model, Widget? child) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance & Shifts'),
          actions: [IconButton(onPressed: model.isBusy ? null : model.reload, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.fingerprint), text: 'My Attendance'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Attendance'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Shifts'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: model.isBusy || model.branches.isEmpty ? null : () => _createShift(context, model),
          icon: const Icon(Icons.add),
          label: const Text('Schedule shift'),
        ),
        body: Column(children: [
          if (model.errorMessage.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(leading: const Icon(Icons.error_outline), title: Text(model.errorMessage)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<String?>(
              value: model.branchId,
              decoration: const InputDecoration(labelText: 'Branch filter', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All assigned branches')),
                ...model.branches.map((branch) => DropdownMenuItem<String?>(value: branch.id, child: Text(branch.name))),
              ],
              onChanged: model.isBusy ? null : model.selectBranch,
            ),
          ),
          Expanded(
            child: model.isBusy && model.branches.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _myAttendance(context, model),
                    _attendanceHistory(context, model),
                    _shiftList(context, model),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _myAttendance(BuildContext context, AttendanceShiftViewModel model) {
    final current = model.current;
    final branch = current?['branch'] is Map ? (current!['branch'] as Map)['name'] : null;
    final checkedIn = current != null;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(checkedIn ? Icons.timer : Icons.timer_off, color: checkedIn ? Colors.green : Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            Text(checkedIn ? 'Currently checked in' : 'Not checked in', style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 12),
          if (checkedIn) ...[
            Text('Branch: ${branch ?? current['branchId'] ?? '—'}'),
            Text('Check-in: ${current['checkInAt'] ?? '—'}'),
          ] else
            const Text('Select your assigned branch and record your attendance.'),
          const SizedBox(height: 16),
          if (checkedIn)
            FilledButton.icon(
              onPressed: model.isBusy ? null : () => model.checkOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Check out'),
            )
          else
            FilledButton.icon(
              onPressed: model.isBusy || model.branchId == null
                  ? null
                  : () => model.checkIn(model.branchId!),
              icon: const Icon(Icons.login),
              label: const Text('Check in'),
            ),
        ]),
      )),
      const SizedBox(height: 16),
      Text('Attendance tips', style: Theme.of(context).textTheme.titleMedium),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('You can only check in to a branch assigned to your account.')),
      const ListTile(leading: Icon(Icons.lock_outline), title: Text('Only one open attendance session is allowed at a time.')),
    ]);
  }

  Widget _attendanceHistory(BuildContext context, AttendanceShiftViewModel model) {
    return RefreshIndicator(
      onRefresh: model.reload,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: DateTimeRange(start: model.from, end: model.to),
            );
            if (range != null) await model.selectRange(range.start, range.end);
          },
          icon: const Icon(Icons.date_range),
          label: Text('${model.fromDate} – ${model.toDate}'),
        ),
        const SizedBox(height: 8),
        if (model.attendanceRows.isEmpty)
          const ListTile(title: Text('No attendance records in this period.'))
        else
          ...model.attendanceRows.map((row) {
            final staff = row['staff'] is Map ? (row['staff'] as Map)['name'] : 'Employee';
            final branch = row['branch'] is Map ? (row['branch'] as Map)['name'] : 'Branch';
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(staff?.toString() ?? 'Employee'),
              subtitle: Text('${branch ?? 'Branch'} · In: ${row['checkInAt'] ?? '—'}\nOut: ${row['checkOutAt'] ?? 'Still working'}'),
              isThreeLine: true,
            ));
          }),
      ]),
    );
  }

  Widget _shiftList(BuildContext context, AttendanceShiftViewModel model) {
    return RefreshIndicator(
      onRefresh: model.reload,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (model.shifts.isEmpty)
          const ListTile(title: Text('No shifts scheduled in this period.'))
        else
          ...model.shifts.map((shift) {
            final staff = shift['staff'] is Map ? (shift['staff'] as Map)['name'] : 'Employee';
            final branch = shift['branch'] is Map ? (shift['branch'] as Map)['name'] : 'Branch';
            final cancelled = shift['status'] == 'cancelled';
            return Card(child: ListTile(
              leading: CircleAvatar(child: Icon(cancelled ? Icons.event_busy : Icons.event_available)),
              title: Text(staff?.toString() ?? 'Employee'),
              subtitle: Text('${shift['shiftDate']} · ${shift['startTime']} – ${shift['endTime']}\n${branch ?? 'Branch'} · ${shift['status'] ?? 'scheduled'}'),
              isThreeLine: true,
              trailing: cancelled ? null : PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'cancel') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Cancel shift?'),
                        content: const Text('This will mark the scheduled shift as cancelled.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
                          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancel shift')),
                        ],
                      ),
                    );
                    if (confirm == true) await model.cancelShift('${shift['id']}');
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('Cancel shift'))],
              ),
            ));
          }),
      ]),
    );
  }

  Future<void> _createShift(BuildContext context, AttendanceShiftViewModel model) async {
    final formKey = GlobalKey<FormState>();
    final notes = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);
    String? employeeId;
    String? branchId = model.branchId ?? (model.branches.length == 1 ? model.branches.first.id : null);
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Schedule employee shift'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: model.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                onChanged: (value) => setState(() => branchId = value),
                validator: (value) => value == null ? 'Select a branch' : null,
              ),
              DropdownButtonFormField<String>(
                value: employeeId,
                decoration: const InputDecoration(labelText: 'Employee'),
                items: model.staff.map((s) => DropdownMenuItem(value: '${s['id']}', child: Text(s['name']?.toString() ?? 'Employee'))).toList(),
                onChanged: (value) => setState(() => employeeId = value),
                validator: (value) => value == null ? 'Select an employee' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shift date'),
                subtitle: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: date);
                  if (picked != null) setState(() => date = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start time'),
                subtitle: Text(start.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: start);
                  if (picked != null) setState(() => start = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End time'),
                subtitle: Text(end.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: end);
                  if (picked != null) setState(() => end = picked);
                },
              ),
              TextFormField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            ]),
          )),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Close')),
          FilledButton(onPressed: () {
            if (formKey.currentState?.validate() == true) Navigator.pop(dialogContext, true);
          }, child: const Text('Schedule')),
        ],
      )),
    );
    if (created == true && branchId != null && employeeId != null) {
      String timeText(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      await model.createShift(
        employeeId: employeeId!,
        selectedBranch: branchId!,
        date: date,
        startTime: timeText(start),
        endTime: timeText(end),
        notes: notes.text,
      );
    }
    notes.dispose();
  }
}
