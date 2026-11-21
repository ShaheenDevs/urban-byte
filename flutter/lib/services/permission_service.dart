class PermissionService {
  final Set<String> _permissions = <String>{};
  void replacePermissions(Iterable<String> permissions) {
    _permissions
      ..clear()
      ..addAll(permissions);
  }

  bool can(String permissionKey) => _permissions.contains(permissionKey);
  bool canAny(Iterable<String> keys) => keys.any(_permissions.contains);
  Set<String> get permissions => Set.unmodifiable(_permissions);
}
