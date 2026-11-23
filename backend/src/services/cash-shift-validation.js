'use strict';

function fail(message) { return Object.assign(new Error(message), { statusCode: 400, code: 'CASH_SHIFT_ERROR' }); }
function amount(value, allowZero = true) {
  const n = Number(value);
  if (!Number.isFinite(n) || (allowZero ? n < 0 : n <= 0) || n > 9999999999.99) throw fail('Amount must be a valid ' + (allowZero ? 'non-negative' : 'positive') + ' value.');
  return n.toFixed(2);
}
function dateRange(query = {}) {
  const from = query.from || new Date().toISOString().slice(0, 10);
  const to = query.to || from;
  const valid = (v) => /^\\d{4}-\\d{2}-\\d{2}$/.test(v) && !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0, 10) === v;
  if (!valid(from) || !valid(to) || from > to) throw fail('Use valid from/to dates in YYYY-MM-DD format.');
  return { from: new Date(from + 'T00:00:00+05:00'), to: new Date(new Date(to + 'T00:00:00+05:00').getTime() + 86400000) };
}
module.exports = { amount, dateRange };
