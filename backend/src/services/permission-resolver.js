'use strict';
function resolvePermissions(rolePermissionKeys = [], userOverrides = []) {
  const resolved = new Set(rolePermissionKeys);
  for (const override of userOverrides) if (override.effect === 'deny') resolved.delete(override.permissionKey);
  for (const override of userOverrides) if (override.effect === 'allow') resolved.add(override.permissionKey);
  return [...resolved].sort();
}
module.exports = { resolvePermissions };
