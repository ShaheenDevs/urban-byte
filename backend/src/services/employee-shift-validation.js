'use strict';

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year
    && date.getUTCMonth() === month - 1
    && date.getUTCDate() === day;
}

function validTime(value) {
  return typeof value === 'string'
    && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value);
}

module.exports = { validDate, validTime };
