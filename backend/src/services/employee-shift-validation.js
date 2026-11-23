'use strict';

function validDate(value) {
  if (typeof value !== 'string' || !/^\\d{4}-\\d{2}-\\d{2}$/.test(value)) return false;
  const date = new Date(value + 'T00:00:00Z');
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}
function validTime(value) {
  return typeof value === 'string' && /^([01]\\d|2[0-3]):[0-5]\\d(:[0-5]\\d)?$/.test(value);
}
module.exports = { validDate, validTime };
