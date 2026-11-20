'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const crypto = require('node:crypto');
const { User, Role, Permission, RefreshToken, sequelize } = require('../models');
const { resolvePermissions } = require('./permission-resolver');

function buildSession(user) {
  const roleSlugs = user.roles.map((role) => role.slug);
  const rolePermissionKeys = user.roles.flatMap((role) => role.permissions.map((permission) => permission.permissionKey));
  const overrides = user.permissionOverrides.map((entry) => ({ permissionKey: entry.permissionKey, effect: entry.UserPermission.effect }));
  const permissions = resolvePermissions([...new Set(rolePermissionKeys)], overrides);
  const accessToken = jwt.sign({ sub: String(user.id), roles: roleSlugs }, process.env.JWT_ACCESS_SECRET, {
    algorithm: 'HS256', expiresIn: process.env.JWT_ACCESS_TTL || '15m', issuer: 'urban-byte-api', audience: 'urban-byte-app',
  });
  return { accessToken, tokenType: 'Bearer', expiresIn: process.env.JWT_ACCESS_TTL || '15m',
    user: { id: String(user.id), name: user.name, email: user.email, phone: user.phone, roles: roleSlugs, permissions } };
}

async function loadUser(identifier) {
  return User.findOne({ where: { [Op.or]: [{ email: identifier.toLowerCase() }, { phone: identifier }] },
    include: [
      { model: Role, as: 'roles', through: { attributes: [] }, include: [{ model: Permission, as: 'permissions', through: { attributes: [] } }] },
      { model: Permission, as: 'permissionOverrides', through: { attributes: ['effect'] } },
    ] });
}

function hashRefreshToken(token) { return crypto.createHash('sha256').update(token).digest('hex'); }
async function issueRefreshToken(userId, transaction) {
  const rawToken = crypto.randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  await RefreshToken.create({ userId, tokenHash: hashRefreshToken(rawToken), expiresAt }, { transaction });
  return rawToken;
}

async function login(identifier, password) {
  const user = await loadUser(identifier);
  if (!user || !user.isActive || !(await bcrypt.compare(password, user.passwordHash))) {
    const error = new Error('Invalid login credentials.'); error.statusCode = 401; error.code = 'INVALID_CREDENTIALS'; throw error;
  }
  return sequelize.transaction(async (transaction) => {
    await user.update({ lastLoginAt: new Date() }, { transaction });
    const session = buildSession(user);
    session.refreshToken = await issueRefreshToken(user.id, transaction);
    session.refreshExpiresIn = '30d';
    return session;
  });
}

async function getCurrentUser(userId) {
  const user = await User.findByPk(userId, { attributes: { exclude: ['passwordHash'] }, include: [
    { model: Role, as: 'roles', through: { attributes: [] }, include: [{ model: Permission, as: 'permissions', through: { attributes: [] } }] },
    { model: Permission, as: 'permissionOverrides', through: { attributes: ['effect'] } },
  ] });
  if (!user || !user.isActive) return null;
  const rolePermissionKeys = user.roles.flatMap((role) => role.permissions.map((permission) => permission.permissionKey));
  const overrides = user.permissionOverrides.map((entry) => ({ permissionKey: entry.permissionKey, effect: entry.UserPermission.effect }));
  return { id: String(user.id), name: user.name, email: user.email, phone: user.phone,
    roles: user.roles.map((role) => role.slug), permissions: resolvePermissions([...new Set(rolePermissionKeys)], overrides) };
}

async function refresh(rawToken) {
  if (typeof rawToken !== 'string' || rawToken.length < 40) {
    const error = new Error('Invalid refresh token.'); error.statusCode = 401; error.code = 'INVALID_REFRESH_TOKEN'; throw error;
  }
  return sequelize.transaction(async (transaction) => {
    const current = await RefreshToken.findOne({ where: { tokenHash: hashRefreshToken(rawToken), revokedAt: null }, transaction, lock: transaction.LOCK.UPDATE });
    if (!current || current.expiresAt <= new Date()) {
      if (current) await current.update({ revokedAt: new Date() }, { transaction });
      const error = new Error('Refresh token is invalid or expired.'); error.statusCode = 401; error.code = 'INVALID_REFRESH_TOKEN'; throw error;
    }
    const user = await User.findByPk(current.userId, { transaction, include: [
      { model: Role, as: 'roles', through: { attributes: [] }, include: [{ model: Permission, as: 'permissions', through: { attributes: [] } }] },
      { model: Permission, as: 'permissionOverrides', through: { attributes: ['effect'] } },
    ] });
    await current.update({ revokedAt: new Date() }, { transaction });
    if (!user || !user.isActive) { const error = new Error('User account is unavailable.'); error.statusCode = 401; error.code = 'ACCOUNT_UNAVAILABLE'; throw error; }
    const session = buildSession(user);
    session.refreshToken = await issueRefreshToken(user.id, transaction);
    session.refreshExpiresIn = '30d';
    return session;
  });
}

async function logout(rawToken) {
  if (!rawToken) return;
  await RefreshToken.update({ revokedAt: new Date() }, { where: { tokenHash: hashRefreshToken(rawToken), revokedAt: null } });
}

module.exports = { login, refresh, logout, getCurrentUser };
