'use strict';
const bcrypt = require('bcryptjs'), jwt = require('jsonwebtoken'), { Op } = require('sequelize'), crypto = require('node:crypto');
const { User, Role, Permission, RefreshToken, sequelize } = require('../models');
const { resolvePermissions } = require('./permission-resolver');
function buildSession(user) {
    const roles = user.roles.map(r => r.slug), roleKeys = user.roles.flatMap(r => r.permissions.map(p => p.permissionKey));
    const overrides = user.permissionOverrides.map(e => ({ permissionKey: e.permissionKey, effect: e.UserPermission.effect }));
    const permissions = resolvePermissions([...new Set(roleKeys)], overrides);
    const accessToken = jwt.sign({ sub: String(user.id), restaurantId: String(user.restaurantId), roles }, process.env.JWT_ACCESS_SECRET, { algorithm: 'HS256', expiresIn: process.env.JWT_ACCESS_TTL || '15m', issuer: 'urban-byte-api', audience: 'urban-byte-app' });
    return { accessToken, tokenType: 'Bearer', expiresIn: process.env.JWT_ACCESS_TTL || '15m', user: { id: String(user.id), restaurantId: String(user.restaurantId), name: user.name, email: user.email, phone: user.phone, roles, permissions } };
}
const includes = [{ model: Role, as: 'roles', through: { attributes: [] }, include: [{ model: Permission, as: 'permissions', through: { attributes: [] } }] }, { model: Permission, as: 'permissionOverrides', through: { attributes: ['effect'] } }];
async function loadUser(identifier) { return User.findOne({ where: { [Op.or]: [{ email: identifier.toLowerCase() }, { phone: identifier }] }, include: includes }); }
const hash = t => crypto.createHash('sha256').update(t).digest('hex');
async function issueRefreshToken(userId, transaction) { const token = crypto.randomBytes(48).toString('base64url'); await RefreshToken.create({ userId, tokenHash: hash(token), expiresAt: new Date(Date.now() + 30 * 86400000) }, { transaction }); return token; }
async function login(identifier, password) {
    const user = await loadUser(identifier);
    if (!user || !user.isActive || !user.restaurantId || !(await bcrypt.compare(password, user.passwordHash))) { const e = new Error('Invalid login credentials.'); e.statusCode = 401; e.code = 'INVALID_CREDENTIALS'; throw e; }
    return sequelize.transaction(async transaction => { await user.update({ lastLoginAt: new Date() }, { transaction }); const s = buildSession(user); s.refreshToken = await issueRefreshToken(user.id, transaction); s.refreshExpiresIn = '30d'; return s; });
}
async function getCurrentUser(userId) {
    const user = await User.findByPk(userId, { attributes: { exclude: ['passwordHash'] }, include: includes });
    if (!user || !user.isActive) return null;
    const keys = user.roles.flatMap(r => r.permissions.map(p => p.permissionKey));
    const overrides = user.permissionOverrides.map(e => ({ permissionKey: e.permissionKey, effect: e.UserPermission.effect }));
    return { id: String(user.id), restaurantId: String(user.restaurantId), name: user.name, email: user.email, phone: user.phone, roles: user.roles.map(r => r.slug), permissions: resolvePermissions([...new Set(keys)], overrides) };
}
async function refresh(raw) {
    if (typeof raw !== 'string' || raw.length < 40) { const e = new Error('Invalid refresh token.'); e.statusCode = 401; e.code = 'INVALID_REFRESH_TOKEN'; throw e; }
    return sequelize.transaction(async transaction => {
        const current = await RefreshToken.findOne({ where: { tokenHash: hash(raw), revokedAt: null }, transaction, lock: transaction.LOCK.UPDATE });
        if (!current || current.expiresAt <= new Date()) { if (current) await current.update({ revokedAt: new Date() }, { transaction }); const e = new Error('Refresh token is invalid or expired.'); e.statusCode = 401; e.code = 'INVALID_REFRESH_TOKEN'; throw e; }
        const user = await User.findByPk(current.userId, { transaction, include: includes }); await current.update({ revokedAt: new Date() }, { transaction });
        if (!user || !user.isActive || !user.restaurantId) { const e = new Error('User account is unavailable.'); e.statusCode = 401; e.code = 'ACCOUNT_UNAVAILABLE'; throw e; }
        const s = buildSession(user); s.refreshToken = await issueRefreshToken(user.id, transaction); s.refreshExpiresIn = '30d'; return s;
    });
}
async function logout(raw) { if (raw) await RefreshToken.update({ revokedAt: new Date() }, { where: { tokenHash: hash(raw), revokedAt: null } }); }
module.exports = { login, refresh, logout, getCurrentUser };