import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../services/staff_service.dart';
import '../../../app/app.locator.dart';

class StaffView extends StackedView<StaffViewModel> {
  const StaffView({super.key});
  @override
  StaffViewModel viewModelBuilder(BuildContext context) =>
      StaffViewModel(locator<StaffService>());

  @override
  Widget builder(BuildContext context, StaffViewModel model, Widget? child) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management'), actions: [
        IconButton(onPressed: model.load, icon: const Icon(Icons.refresh))
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAdd(context, model),
          icon: const Icon(Icons.person_add),
          label: const Text('Add staff')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                onChanged: model.search,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name, email or phone',
                    border: OutlineInputBorder()))),
        Expanded(
            child: model.isBusy
                ? const Center(child: CircularProgressIndicator())
                : model.errorMessage != null
                    ? Center(child: Text(model.errorMessage!))
                    : model.staff.isEmpty
                        ? const Center(child: Text('No staff members found.'))
                        : RefreshIndicator(
                            onRefresh: model.load,
                            child: ListView.separated(
                                itemCount: model.staff.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final user = model.staff[index];
                                  final roles = (user['roles'] as List? ?? [])
                                      .map((r) => (r as Map)['name'] ?? '')
                                      .join(', ');
                                  return ListTile(
                                      leading: CircleAvatar(
                                          child: Text((user['name'] ?? '?')
                                              .toString()
                                              .characters
                                              .first
                                              .toUpperCase())),
                                      title: Text(user['name'] ?? 'Unnamed'),
                                      subtitle: Text(
                                          '${user['email'] ?? user['phone'] ?? ''}\n$roles'),
                                      isThreeLine: true,
                                      trailing: PopupMenuButton<String>(
                                        tooltip: 'Staff actions',
                                        onSelected: (action) async {
                                          if (action == 'edit') {
                                            await _showEdit(context, model, user);
                                          } else if (action == 'permissions') {
                                            await _showPermissions(context, model, user);
                                          } else if (action == 'history') {
                                            await _showHistory(context, model, user);
                                          } else if (action == 'toggle') {
                                            await model.setActive(user, user['isActive'] != true);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(value: 'permissions', child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined), title: Text('Permissions'), dense: true)),
                                          const PopupMenuItem(value: 'history', child: ListTile(leading: Icon(Icons.history), title: Text('Audit history'), dense: true)),
                                          const PopupMenuItem(value: 'edit', child: ListTile(
                                            leading: Icon(Icons.edit_outlined), title: Text('Edit staff'), dense: true)),
                                          PopupMenuItem(value: 'toggle', child: ListTile(
                                            leading: Icon(user['isActive'] == true ? Icons.block : Icons.check_circle_outline),
                                            title: Text(user['isActive'] == true ? 'Deactivate' : 'Activate'), dense: true)),
                                        ],
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            user['isActive'] == true ? Icons.check_circle : Icons.block,
                                            color: user['isActive'] == true ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                      ));
                                }))),
      ]),
    );
  }

  Future<void> _showEdit(
      BuildContext context, StaffViewModel model, Map<String, dynamic> user) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: user['name']?.toString() ?? '');
    final contact = TextEditingController(
      text: (user['email'] ?? user['phone'] ?? '').toString(),
    );
    final password = TextEditingController();
    final roles = await model.loadRoles();
    final branches = await model.loadBranches();
    if (!context.mounted) return;
    final selected = <int>{};
    for (final role in (user['roles'] as List? ?? const [])) {
      final roleId = int.tryParse((role as Map)['id'].toString());
      if (roleId != null) selected.add(roleId);
    }
    final selectedBranches = <int>{};
    for (final branch in (user['branches'] as List? ?? const [])) {
      final branchId = int.tryParse((branch as Map)['id'].toString());
      if (branchId != null) selectedBranches.add(branchId);
    }
    bool active = user['isActive'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${user['name'] ?? 'staff member'}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => v == null || v.trim().length < 2 ? 'Enter a valid name' : null,
                  ),
                  TextFormField(
                    controller: contact,
                    decoration: const InputDecoration(labelText: 'Email or phone'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Email or phone required' : null,
                  ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password (leave blank to keep current)'),
                    validator: (v) => v != null && v.isNotEmpty && v.length < 12 ? 'Minimum 12 characters' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account active'),
                    value: active,
                    onChanged: (value) => setState(() => active = value),
                  ),
                  const Align(alignment: Alignment.centerLeft, child: Text('Roles')),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text('Assigned branches')),
                  ...branches.map((branch) {
                    final id = int.tryParse(branch['id'].toString());
                    if (id == null) return const SizedBox.shrink();
                    return CheckboxListTile(
                      value: selectedBranches.contains(id),
                      title: Text(branch['name'] ?? branch['code'] ?? 'Branch'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() {
                        if (value == true) { selectedBranches.add(id); } else { selectedBranches.remove(id); }
                      }),
                    );
                  }),
                  ...roles.map((role) {
                    final id = int.tryParse(role['id'].toString());
                    if (id == null) return const SizedBox.shrink();
                    return CheckboxListTile(
                      value: selected.contains(id),
                      title: Text(role['name'] ?? role['slug'] ?? 'Role'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(id);
                        } else {
                          selected.remove(id);
                        }
                      }),
                    );
                  }),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate() && selected.isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      await model.update(
        user,
        name.text,
        contact.text,
        selected.toList(),
        selectedBranches.toList(),
        active,
        password.text,
      );
    }
    name.dispose();
    contact.dispose();
    password.dispose();
  }

  Future<void> _showPermissions(BuildContext context, StaffViewModel model, Map<String, dynamic> user) async {
    final permissions = await model.loadPermissions();
    if (!context.mounted) return;
    final existing = <int, String>{};
    for (final item in (user['permissionOverrides'] as List? ?? const [])) {
      final key = (item as Map)['key']?.toString();
      final match = permissions.where((p) => p['permissionKey'] == key);
      if (match.isNotEmpty) existing[int.parse(match.first['id'].toString())] = item['effect'].toString();
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Permissions — ${user['name']}'),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: permissions.map((permission) {
                final id = int.tryParse(permission['id'].toString());
                if (id == null) return const SizedBox.shrink();
                final effect = existing[id];
                return ListTile(
                  title: Text(permission['name'] ?? permission['permissionKey'] ?? ''),
                  subtitle: Text('${permission['module'] ?? ''} • ${permission['permissionKey'] ?? ''}'),
                  trailing: PopupMenuButton<String>(
                    initialValue: effect ?? 'inherit',
                    onSelected: (value) async {
                      try {
                        if (value == 'inherit') {
                          await model.removeOverride(user['id'].toString(), id);
                          existing.remove(id);
                        } else {
                          await model.setOverride(user['id'].toString(), id, value);
                          existing[id] = value;
                        }
                        setState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'inherit', child: Text('Use role default')),
                      PopupMenuItem(value: 'allow', child: Text('Allow')),
                      PopupMenuItem(value: 'deny', child: Text('Deny')),
                    ],
                    child: Chip(label: Text(effect ?? 'Inherit')),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      ),
    );
  }

  Future<void> _showHistory(BuildContext context, StaffViewModel model, Map<String, dynamic> user) async {
    final rows = await model.loadHistory(user['id'].toString());
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Audit history — ${user['name']}'),
        content: SizedBox(
          width: 480,
          child: rows.isEmpty
              ? const Text('No audit events recorded yet.')
              : ListView(
                  shrinkWrap: true,
                  children: rows.map((row) => ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(row['action']?.toString() ?? 'Updated'),
                    subtitle: Text('${row['createdAt'] ?? ''}\\n${row['metadata'] ?? {}}'),
                  )).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _showAdd(BuildContext context, StaffViewModel model) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(),
        contact = TextEditingController(),
        password = TextEditingController();
    final roles = await model.loadRoles();
    final branches = await model.loadBranches();
    if (!context.mounted) return;
    final selected = <int>{};
    final selectedBranches = <int>{};
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                    title: const Text('Add staff member'),
                    content: SizedBox(
                        width: 420,
                        child: SingleChildScrollView(
                            child: Form(
                                key: form,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                          controller: name,
                                          decoration: const InputDecoration(
                                              labelText: 'Full name'),
                                          validator: (v) =>
                                              v == null || v.trim().length < 2
                                                  ? 'Enter a valid name'
                                                  : null),
                                      TextFormField(
                                          controller: contact,
                                          decoration: const InputDecoration(
                                              labelText: 'Email or phone'),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Email or phone required'
                                                  : null),
                                      TextFormField(
                                          controller: password,
                                          obscureText: true,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Temporary password (12+ characters)'),
                                          validator: (v) =>
                                              v == null || v.length < 12
                                                  ? 'Minimum 12 characters'
                                                  : null),
                                      const SizedBox(height: 12),
                                      const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('Roles')),
                                      const SizedBox(height: 12),
                                      const Align(alignment: Alignment.centerLeft, child: Text('Assigned branches')),
                                      ...branches.map((branch) {
                                        final id = int.tryParse(branch['id'].toString());
                                        if (id == null) return const SizedBox.shrink();
                                        return CheckboxListTile(
                                          value: selectedBranches.contains(id),
                                          title: Text(branch['name'] ?? branch['code'] ?? 'Branch'),
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          onChanged: (v) => setState(() {
                                            if (v == true) { selectedBranches.add(id); } else { selectedBranches.remove(id); }
                                          }),
                                        );
                                      }),
                                      ...roles.map((r) {
                                        final id =
                                            int.tryParse(r['id'].toString());
                                        if (id == null)
                                          return const SizedBox.shrink();
                                        return CheckboxListTile(
                                            value: selected.contains(id),
                                            title: Text(r['name'] ??
                                                r['slug'] ??
                                                'Role'),
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            onChanged: (v) => setState(() {
                                                  if (v == true) {
                                                    selected.add(id);
                                                  } else {
                                                    selected.remove(id);
                                                  }
                                                }));
                                      })
                                    ])))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => form.currentState!.validate() &&
                                  selected.isNotEmpty
                              ? Navigator.pop(dialogContext, true)
                              : null,
                          child: const Text('Create'))
                    ])));
    if (!context.mounted) return;
    // Creation is submitted only after explicit confirmation in the dialog.
    if (confirmed == true && selected.isNotEmpty &&
        name.text.trim().isNotEmpty &&
        contact.text.trim().isNotEmpty &&
        password.text.length >= 12) {
      await model.create(
          name.text, contact.text, password.text, selected.toList(), selectedBranches.toList());
    }
    name.dispose();
    contact.dispose();
    password.dispose();
  }
}

class StaffViewModel extends BaseViewModel {
  StaffViewModel(this._service) {
    load();
  }
  final StaffService _service;
  List<Map<String, dynamic>> staff = [];
  String? errorMessage;
  Future<void> load() async {
    setBusy(true);
    errorMessage = null;
    try {
      staff = await _service.getStaff();
    } catch (e) {
      errorMessage = e.toString();
    }
    setBusy(false);
    notifyListeners();
  }

  Future<void> search(String value) async {
    try {
      staff = await _service.getStaff(search: value);
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> loadRoles() async {
    try {
      return await _service.getRoles();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadBranches() async => _service.getBranches();
  Future<List<Map<String, dynamic>>> loadPermissions() async => _service.getPermissions();
  Future<List<Map<String, dynamic>>> loadHistory(String userId) async => _service.getAuditHistory(userId: userId);
  Future<void> setOverride(String userId, int permissionId, String effect) async {
    await _service.setPermissionOverride(userId: userId, permissionId: permissionId, effect: effect);
    await load();
  }
  Future<void> removeOverride(String userId, int permissionId) async {
    await _service.removePermissionOverride(userId: userId, permissionId: permissionId);
    await load();
  }

  Future<void> update(
    Map<String, dynamic> user,
    String name,
    String contact,
    List<int> roles,
    List<int> branches,
    bool active,
    String password,
  ) async {
    setBusy(true);
    errorMessage = null;
    try {
      await _service.updateStaff(
        id: user['id'].toString(),
        name: name,
        contact: contact,
        roleIds: roles,
        branchIds: branches,
        isActive: active,
        password: password.trim().isEmpty ? null : password,
      );
      await load();
    } catch (e) {
      errorMessage = e.toString();
    }
    setBusy(false);
    notifyListeners();
  }

  Future<void> setActive(Map<String, dynamic> user, bool active) async {
    await update(
      user,
      user['name']?.toString() ?? '',
      (user['email'] ?? user['phone'] ?? '').toString(),
      (user['roles'] as List? ?? const [])
          .map((role) => int.tryParse((role as Map)['id'].toString()))
          .whereType<int>()
          .toList(),
      (user['branches'] as List? ?? const []).map((b) => int.tryParse((b as Map)['id'].toString())).whereType<int>().toList(),
      active,
      '',
    );
  }

  Future<void> create(
      String name, String contact, String password, List<int> roles, List<int> branches) async {
    setBusy(true);
    try {
      await _service.createStaff(
          name: name, contact: contact, password: password, roleIds: roles, branchIds: branches);
      await load();
    } catch (e) {
      errorMessage = e.toString();
    }
    setBusy(false);
    notifyListeners();
  }
}
