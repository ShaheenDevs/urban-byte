'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {renderOrder}=require('../src/services/print-renderer');
const order={orderNumber:'UB-20261121-ABC123',orderType:'takeaway',placedAt:'2026-11-21T10:00:00.000Z',customerName:'Test Customer',customerPhone:'03001234567',items:[{productName:'Zinger Burger',variantName:'Regular',quantity:'2.000',unitPrice:'480.00',lineTotal:'960.00'}],subtotal:'960.00',discountAmount:'0.00',taxAmount:'0.00',deliveryFee:'0.00',grandTotal:'960.00',paymentStatus:'unpaid'};
test('receipt contains order identity, item and total',()=>{const text=renderOrder(order,'receipt','80mm');assert.match(text,/URBAN BYTE/);assert.match(text,/UB-20261121-ABC123/);assert.match(text,/Zinger Burger Regular/);assert.match(text,/TOTAL: Rs 960.00/);});
test('kitchen ticket omits payment details and includes preparation heading',()=>{const text=renderOrder(order,'kitchen_ticket','58mm');assert.match(text,/KITCHEN ORDER/);assert.match(text,/PREPARATION TICKET/);assert.doesNotMatch(text,/TOTAL: Rs/);});
test('58mm layout uses a narrower separator than 80mm',()=>{const small=renderOrder(order,'receipt','58mm');const wide=renderOrder(order,'receipt','80mm');assert.ok(small.split('\n')[1].length<wide.split('\n')[1].length);});
