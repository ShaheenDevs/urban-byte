'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {calculateRecipeConsumption,calculateBalance}=require('../src/services/inventory-math');
test('scales ingredient quantities by sold units and recipe yield',()=>{assert.equal(calculateRecipeConsumption(120,2,1),240);assert.equal(calculateRecipeConsumption(120,3,2),180);});
test('rounds ingredient usage upward to the stock precision',()=>{assert.equal(calculateRecipeConsumption(1,1,3),0.334);assert.equal(calculateRecipeConsumption(0.1,1,3),0.034);});
test('rejects invalid recipe quantities',()=>{assert.throws(()=>calculateRecipeConsumption(1,1,0));assert.throws(()=>calculateRecipeConsumption(-1,1,1));assert.throws(()=>calculateRecipeConsumption(1,0,1));});
test('calculates stock balance to three decimal places',()=>{assert.equal(calculateBalance(5.125,0.125),5.25);assert.equal(calculateBalance(5.125,-0.125),5);});
test('prevents negative stock balances',()=>{assert.throws(()=>calculateBalance(1,-1.001),{code:'INSUFFICIENT_STOCK'});});
