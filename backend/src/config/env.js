'use strict';
const dotenv = require('dotenv');
dotenv.config();
const required = ['DB_HOST', 'DB_NAME', 'DB_USER', 'JWT_ACCESS_SECRET'];
function validateEnv() {
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length) throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  if (!process.env.DB_PASSWORD && process.env.NODE_ENV === 'production') throw new Error('DB_PASSWORD is required in production.');
  if (process.env.JWT_ACCESS_SECRET.length < 32 || process.env.JWT_ACCESS_SECRET.startsWith('replace_')) throw new Error('JWT_ACCESS_SECRET must be a unique secret of at least 32 characters.');
}
module.exports = { validateEnv, nodeEnv: process.env.NODE_ENV || 'development', port: Number(process.env.PORT || 4000), appOrigin: process.env.APP_ORIGIN || 'http://localhost:3000' };
