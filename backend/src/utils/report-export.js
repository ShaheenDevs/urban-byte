'use strict';
function csvCell(value){
 const text=value===null||value===undefined?'':String(value);
 const safe=typeof value==='string'&&/^[=+\-@\t\r]/.test(text)?("'"+text):text;
 return '"'+safe.replace(/"/g,'""')+'"';
}
function toCsv(headers,rows){
 return '\uFEFF'+[headers,...rows.map(row=>headers.map(key=>row[key]??''))].map(row=>row.map(csvCell).join(',')).join('\r
');
}
function ascii(value){
 return String(value??'').normalize('NFKD').replace(/[^\x20-\x7E]/g,'?');
}
function pdfEscape(value){return ascii(value).replace(/\\/g,'\\\\').replace(/\(/g,'\\(').replace(/\)/g,'\\)');}
function createPdf(title,lines){
 const perPage=46;
 const pages=[];
 for(let i=0;i<lines.length||i===0;i+=perPage)pages.push(lines.slice(i,i+perPage));
 const objects=[];
 const add=value=>{objects.push(value);return objects.length;};
 const catalogId=add('');
 const pagesId=add('');
 const fontId=add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
 const pageIds=[];
 for(let index=0;index<pages.length;index++){
  const pageLines=[title,'Urban Byte Restaurant | Generated report','',...pages[index]];
  const stream=['BT','/F1 10 Tf','48 790 Td','14 TL',...pageLines.flatMap((line,i)=>i===0?[`/F1 16 Tf (${pdfEscape(line)}) Tj`,'/F1 10 Tf','T*']:[`(${pdfEscape(line).slice(0,150)}) Tj`,'T*']),`(Page ${index+1} of ${pages.length}) Tj`,'ET'].join('
');
  const contentId=add(`<< /Length ${Buffer.byteLength(stream,'ascii')} >>
stream
${stream}
endstream`);
  const pageId=add(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 ${fontId} 0 R >> >> /Contents ${contentId} 0 R >>`);
  pageIds.push(pageId);
 }
 objects[catalogId-1]=`<< /Type /Catalog /Pages ${pagesId} 0 R >>`;
 objects[pagesId-1]=`<< /Type /Pages /Kids [${pageIds.map(id=>id+' 0 R').join(' ')}] /Count ${pageIds.length} >>`;
 let output='%PDF-1.4
%UBREPORT
';
 const offsets=[0];
 objects.forEach((obj,index)=>{offsets.push(Buffer.byteLength(output,'ascii'));output+=`${index+1} 0 obj
${obj}
endobj
`;});
 const xref=Buffer.byteLength(output,'ascii');
 output+=`xref
0 ${objects.length+1}
0000000000 65535 f 
`;
 for(let i=1;i<offsets.length;i++)output+=String(offsets[i]).padStart(10,'0')+' 00000 n 
';
 output+=`trailer
<< /Size ${objects.length+1} /Root ${catalogId} 0 R >>
startxref
${xref}
%%EOF`;
 return Buffer.from(output,'ascii');
}
function financialLines(data){
 const p=data.profitability||{},c=data.cashFlow||{},buy=data.purchases||{};
 return [
  `Period: ${data.period?.from||''} to ${data.period?.to||''} | Currency: PKR`,
  '', 'FINANCIAL SUMMARY',
  `Verified collections: PKR ${data.collections?.total||'0.00'}`,
  `Approved expenses: PKR ${data.approvedExpenses?.total||'0.00'}`,
  `Received purchases: PKR ${buy.receivedTotal||'0.00'}`,
  `Supplier outstanding: PKR ${buy.supplierOutstanding||'0.00'}`,
  '', 'CASH FLOW',
  `Cash collections: PKR ${c.cashCollections||'0.00'}`,
  `Cash expenses: PKR ${c.cashExpenses||'0.00'}`,
  `Cash supplier payments: PKR ${c.cashSupplierPayments||'0.00'}`,
  `Net cash movement: PKR ${c.netCashMovement||'0.00'}`,
  '', 'PROFITABILITY',
  `Completed orders: ${p.completedOrders||0}`,
  `Sales revenue: PKR ${p.salesRevenue||'0.00'}`,
  `Estimated recipe COGS: PKR ${p.estimatedCogs||'0.00'}`,
  `Gross profit: ${p.grossProfit??'Incomplete'}`,
  `Net profit: ${p.netProfit??'Incomplete'}`,
  `Costing status: ${p.status||'unknown'}`,
  '', 'PRODUCT PROFITABILITY',
  ...(data.productProfitability||[]).map(x=>`${x.productName}: Qty ${x.quantity}, Revenue PKR ${x.revenue}, COGS ${x.cogs??'Incomplete'}, Gross profit ${x.grossProfit??'Incomplete'}`),
  '', 'Note: Profit is withheld when recipe COGS is incomplete.'
 ];
}
function analyticsLines(data){
 return [
  `Period: ${data.period?.from||''} to ${data.period?.to||''} | Currency: PKR`,
  '', 'DAILY SALES',
  ...(data.dailySales||[]).map(x=>`${x.date}: ${x.orders} orders | PKR ${x.revenue}`),
  '', 'BEST SELLING PRODUCTS',
  ...(data.bestSellingProducts||[]).map(x=>`${x.productName}: Qty ${x.quantity} | Revenue PKR ${x.revenue}`),
  '', 'LOWEST MARGIN PRODUCTS',
  ...(data.lowestMarginProducts||[]).map(x=>`${x.productName}: ${x.marginPercent}% | Gross profit PKR ${x.grossProfit}`),
  '', 'WASTAGE',
  `Movements: ${data.wastage?.movementCount||0} | Quantity: ${data.wastage?.totalQuantity||0} | Cost: ${data.wastage?.estimatedCost??'Incomplete'}`,
  '', 'BRANCH COMPARISON',
  ...(data.branchComparison||[]).map(x=>`${x.branchName}: ${x.orders} orders | Revenue PKR ${x.revenue} | Gross profit ${x.grossProfit??'Incomplete'}`)
 ];
}
module.exports={toCsv,createPdf,financialLines,analyticsLines};
