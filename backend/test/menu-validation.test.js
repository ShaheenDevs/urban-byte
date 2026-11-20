'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {resolvePermissions}=require('../src/services/permission-resolver');
test('menu permission policy grants management only to Admin by default',()=>{assert.deepEqual(resolvePermissions(['menu.view','menu.manage','deals.manage']),['deals.manage','menu.manage','menu.view']);assert.equal(resolvePermissions(['menu.view','deals.manage']).includes('menu.manage'),false);assert.equal(resolvePermissions(['menu.view']).includes('menu.manage'),false);});
test('explicit user deny removes inherited menu management',()=>{assert.deepEqual(resolvePermissions(['menu.view','menu.manage'],[{permissionKey:'menu.manage',effect:'deny'}]),['menu.view']);});