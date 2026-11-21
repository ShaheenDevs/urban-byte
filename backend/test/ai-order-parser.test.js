'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {normalize,words,parseQuantity,variantSize}=require('../src/services/ai-order-parser');
test('normalizes Roman Urdu and strips punctuation',()=>assert.equal(normalize('  2 LARGE Pizza, please! '),'2 large pizza please'));
test('extracts numeric and Roman Urdu quantities',()=>{assert.equal(parseQuantity('2 zinger burgers'),2);assert.equal(parseQuantity('do burgers'),2);assert.equal(parseQuantity('teen pizza'),3);assert.equal(parseQuantity('one pizza'),1);});
test('caps quantity at ten',()=>assert.equal(parseQuantity('20 burgers'),10));
test('filters order filler and size words from menu search',()=>assert.deepEqual(words('mujhe 1 large zinger burger chahiye'),'zinger burger'.split(' ')));
test('selects requested variant size or default',()=>{const variants=[{id:1,name:'Regular',isDefault:true},{id:2,name:'Large',isDefault:false}];assert.equal(variantSize('large pizza',variants).id,2);assert.equal(variantSize('pizza',variants).id,1);});

test('supports Pakistani Urdu size aliases',()=>{const variants=[{id:1,name:'Regular',isDefault:true},{id:2,name:'Large',isDefault:false},{id:3,name:'Small',isDefault:false}];assert.equal(variantSize('bari pizza',variants).id,2);assert.equal(variantSize('choti pizza',variants).id,3);});
test('supports Pakistani quantity words',()=>{assert.equal(parseQuantity('aik pizza'),1);assert.equal(parseQuantity('chaar burger'),4);assert.equal(parseQuantity('paanch fries'),5);});
test('keeps menu search tokens useful after Roman Urdu filler removal',()=>{assert.deepEqual(words('mujhe do zinger burger chahiye'),'zinger burger'.split(' '));});

test('requires explicit order confirmation phrase',()=>{const {isExplicitConfirmation}=require('../src/services/ai-order-parser');assert.equal(isExplicitConfirmation('CONFIRM'),true);assert.equal(isExplicitConfirmation('yes confirm'),true);assert.equal(isExplicitConfirmation('haan'),false);assert.equal(isExplicitConfirmation('yes'),false);assert.equal(isExplicitConfirmation('ji'),false);});
