'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {transitions,validateTransition}=require('../src/services/order-lifecycle');
test('order lifecycle permits the restaurant kitchen flow',()=>{
 assert.deepEqual(transitions.placed,['confirmed','cancelled']);
 assert.deepEqual(transitions.confirmed,['preparing','cancelled']);
 assert.deepEqual(transitions.preparing,['ready']);
 assert.deepEqual(transitions.ready,['out_for_delivery','completed']);
});
test('order lifecycle rejects skipping kitchen stages',()=>{
 assert.throws(()=>validateTransition('placed','preparing'),{code:'INVALID_ORDER_TRANSITION'});
 assert.throws(()=>validateTransition('confirmed','completed'),{code:'INVALID_ORDER_TRANSITION'});
 assert.throws(()=>validateTransition('cancelled','confirmed'),{code:'INVALID_ORDER_TRANSITION'});
});
test('order lifecycle rejects terminal state changes',()=>{
 assert.throws(()=>validateTransition('completed','cancelled'),{code:'INVALID_ORDER_TRANSITION'});
 assert.throws(()=>validateTransition('cancelled','preparing'),{code:'INVALID_ORDER_TRANSITION'});
});
test('delivery can complete only after ready or out for delivery',()=>{
 assert.doesNotThrow(()=>validateTransition('ready','completed'));
 assert.doesNotThrow(()=>validateTransition('ready','out_for_delivery'));
 assert.doesNotThrow(()=>validateTransition('out_for_delivery','completed'));
 assert.throws(()=>validateTransition('preparing','out_for_delivery'),{code:'INVALID_ORDER_TRANSITION'});
});
