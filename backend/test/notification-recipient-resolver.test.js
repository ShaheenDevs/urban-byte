'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {resolveNotificationRecipients}=require('../src/services/notification-recipient-resolver');
const users=[{id:1},{id:2},{id:3},{id:4}];
const permissions=[{id:10},{id:11}];
test('combines grants from multiple roles for each user',()=>{
 const result=resolveNotificationRecipients(users,permissions,[{userId:1,roleId:2},{userId:1,roleId:3},{userId:2,roleId:3}],[{roleId:2,permissionId:10},{roleId:3,permissionId:11}],[]);
 assert.deepEqual(result,[1,2]);
});
test('explicit deny overrides a role grant',()=>{
 const result=resolveNotificationRecipients(users,permissions,[{userId:1,roleId:2},{userId:2,roleId:2}],[{roleId:2,permissionId:10}],[{userId:1,permissionId:10,effect:'deny'}]);
 assert.deepEqual(result,[2]);
});
test('explicit allow can target a user without a role grant',()=>{
 const result=resolveNotificationRecipients(users,permissions,[],[],[{userId:3,permissionId:11,effect:'allow'}]);
 assert.deepEqual(result,[3]);
});
test('users without any matching permission are not notified',()=>{
 assert.deepEqual(resolveNotificationRecipients(users,permissions,[{userId:4,roleId:99}],[{roleId:99,permissionId:99}],[]),[]);
});
