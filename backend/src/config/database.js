'use strict';
const common = {
  dialect: 'mysql', host: process.env.DB_HOST || '127.0.0.1', port: Number(process.env.DB_PORT || 3306),
  logging: process.env.NODE_ENV === 'development' ? console.log : false,
  define: { underscored: true, freezeTableName: true, timestamps: true },
  pool: { max: 10, min: 0, acquire: 30000, idle: 10000 }, timezone: '+00:00',
};
module.exports = {
  development: { ...common, database: process.env.DB_NAME || 'urban_byte_db', username: process.env.DB_USER || 'root', password: process.env.DB_PASSWORD || '' },
  test: { ...common, logging: false, database: process.env.DB_NAME || 'urban_byte_test', username: process.env.DB_USER || 'root', password: process.env.DB_PASSWORD || '' },
  production: { ...common, logging: false, database: process.env.DB_NAME, username: process.env.DB_USER, password: process.env.DB_PASSWORD, dialectOptions: { ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: true } : undefined } },
};
