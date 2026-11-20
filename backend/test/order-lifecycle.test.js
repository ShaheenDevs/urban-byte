'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validateTransition,transitions}=require('../src/services/order-service');
test('allows normal kitchen and delivery status transitions',()=>{
 assert.doesNotThrow(()=>validateTransition('placed','confirmed'));
 assert.doesNotThrow(()=>validateTransition('confirmed','preparing'));
 assert.doesNotThrow(()=>validateTransition('preparing','ready'));
 assert.doesNotThrow(()=>validateTransition('ready','out_for_delivery'));
 assert.doesNotThrow(()=>validateTransition('out_for_delivery','completed'));
});
test('allows cancellation only before preparation',()=>{
 assert.doesNotThrow(()=>validateTransition('placed','cancelled'));
 assert.doesNotThrow(()=>validateTransition('confirmed','cancelled'));
 assert.throws(()=>validateTransition('preparing','cancelled'),{code:'INVALID_ORDER_TRANSITION'});
});
test('prevents reopening terminal orders',()=>{
 assert.deepEqual(transitions.completed,[]);
 assert.deepEqual(transitions.cancelled,[]);
 assert.throws(()=>validateTransition('completed','preparing'),{code:'INVALID_ORDER_TRANSITION'});
});
