'use strict';

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { validateEnv } = require('../src/config/env');
const { sequelize, User, Role } = require('../src/models');

async function main() {
  validateEnv();
  const { ADMIN_NAME, ADMIN_EMAIL, ADMIN_PHONE, ADMIN_PASSWORD } = process.env;
  if (!ADMIN_NAME || (!ADMIN_EMAIL && !ADMIN_PHONE) || !ADMIN_PASSWORD || ADMIN_PASSWORD.length < 12) {
    throw new Error('Set ADMIN_NAME, ADMIN_EMAIL or ADMIN_PHONE, and ADMIN_PASSWORD (minimum 12 characters) in backend/.env.');
  }
  await sequelize.authenticate();
  const existing = await User.findOne({ where: ADMIN_EMAIL ? { email: ADMIN_EMAIL.toLowerCase() } : { phone: ADMIN_PHONE } });
  if (existing) throw new Error('An account with this admin email/phone already exists.');
  const adminRole = await Role.findOne({ where: { slug: 'admin' } });
  if (!adminRole) throw new Error('System roles are missing. Run npm run db:seed first.');
  const user = await sequelize.transaction(async (transaction) => {
    const created = await User.create({ name: ADMIN_NAME, email: ADMIN_EMAIL ? ADMIN_EMAIL.toLowerCase() : null, phone: ADMIN_PHONE || null, passwordHash: await bcrypt.hash(ADMIN_PASSWORD, 12) }, { transaction });
    await created.addRole(adminRole, { transaction });
    return created;
  });
  process.stdout.write(`Admin account created (user id: ${user.id}).\n`);
}

main().catch((error) => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }).finally(async () => { await sequelize.close(); });
