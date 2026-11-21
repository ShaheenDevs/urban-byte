'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {toCsv,createPdf,financialLines,analyticsLines}=require('../src/utils/report-export');

test('CSV escapes delimiters, quotes and spreadsheet formula prefixes',()=>{
 const csv=toCsv(['name','amount'],[{name:'Urban, Byte "Special"',amount:125.5},{name:'=HYPERLINK("https://bad")',amount:-20}]);
 assert.match(csv,/\uFEFF/);
 assert.match(csv,/"Urban, Byte ""Special"""/);
 assert.match(csv,/"'=HYPERLINK/);
 assert.match(csv,/"-20"/);
});

test('PDF output has a valid PDF signature and supports multiple pages',()=>{
 const pdf=createPdf('Sales Report',Array.from({length:100},(_,i)=>'Line '+i));
 const content=pdf.toString('ascii');
 assert.ok(content.startsWith('%PDF-1.4'));
 assert.match(content,/\/Count 3/);
 assert.ok(content.endsWith('%%EOF'));
});

test('financial and analytics report renderers include incomplete costing clearly',()=>{
 const financial=financialLines({period:{from:'2026-11-01',to:'2026-11-21'},profitability:{grossProfit:null,netProfit:null,status:'incomplete'},productProfitability:[{productName:'Pizza',quantity:2,revenue:'1000.00',cogs:null,grossProfit:null}]});
 assert.ok(financial.some(x=>x.includes('Gross profit: Incomplete')));
 assert.ok(financial.some(x=>x.includes('Pizza')));
 const analytics=analyticsLines({period:{from:'2026-11-01',to:'2026-11-21'},wastage:{movementCount:1,totalQuantity:2,estimatedCost:null},branchComparison:[{branchName:'Shahkot',orders:3,revenue:'1200.00',grossProfit:null}]});
 assert.ok(analytics.some(x=>x.includes('Cost: Incomplete')));
 assert.ok(analytics.some(x=>x.includes('Shahkot')));
});
