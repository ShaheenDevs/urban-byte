'use strict';
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { sequelize, User, Role, Restaurant, Branch } = require('../src/models');

async function main() {
  const { ADMIN_NAME, ADMIN_EMAIL, ADMIN_PHONE, ADMIN_PASSWORD } = process.env;
  if (!ADMIN_NAME || (!ADMIN_EMAIL && !ADMIN_PHONE) || !ADMIN_PASSWORD || ADMIN_PASSWORD.length < 12) {
    throw new Error('Set ADMIN_NAME, ADMIN_EMAIL or ADMIN_PHONE, and ADMIN_PASSWORD (minimum 12 characters) in backend/.env.');
  }
  await sequelize.authenticate();
  await sequelize.transaction(async transaction => {
    let restaurant = await Restaurant.findOne({ where: { slug: 'urban-byte' }, transaction });
    if (!restaurant) restaurant = await Restaurant.create({
      name: process.env.SEED_RESTAURANT_NAME || 'Urban Byte',
      slug: 'urban-byte', currency: 'PKR', timezone: 'Asia/Karachi'
    }, { transaction });
    const [branch] = await Branch.findOrCreate({
      where: { restaurantId: restaurant.id, code: 'SHK' },
      defaults: { restaurantId: restaurant.id, name: 'Shahkot Main Branch', code: 'SHK', address: 'Shahkot, Punjab, Pakistan', isActive: true },
      transaction
    });
    const adminRole = await Role.findOne({ where: { slug: 'admin' }, transaction });
    if (!adminRole) throw new Error('Admin role is missing. Run npm run db:seed after pulling latest main.');
    const ownerRole = await Role.findOne({ where: { slug: 'owner' }, transaction });
    const where = ADMIN_EMAIL
      ? { email: ADMIN_EMAIL.trim().toLowerCase() }
      : { phone: ADMIN_PHONE.trim() };
    let user = await User.findOne({ where, transaction });
    const passwordHash = await bcrypt.hash(ADMIN_PASSWORD, 12);
    if (user) {
      await user.update({
        restaurantId: restaurant.id,
        name: ADMIN_NAME,
        passwordHash,
        isActive: true,
        ...(ADMIN_EMAIL ? { email: ADMIN_EMAIL.trim().toLowerCase() } : {}),
        ...(ADMIN_PHONE ? { phone: ADMIN_PHONE.trim() } : {})
      }, { transaction });
    } else {
      user = await User.create({
        restaurantId: restaurant.id, name: ADMIN_NAME,
        email: ADMIN_EMAIL ? ADMIN_EMAIL.trim().toLowerCase() : null,
        phone: ADMIN_PHONE ? ADMIN_PHONE.trim() : null,
        passwordHash, isActive: true
      }, { transaction });
    }
    await user.addRole(adminRole, { transaction });
    if (ownerRole) await user.addRole(ownerRole, { transaction });
    process.stdout.write('Admin account repaired and linked to Urban Byte.\n');
    process.stdout.write('Login identifier: ' + (ADMIN_EMAIL || ADMIN_PHONE) + '\n');
    process.stdout.write('Restaurant ID: ' + restaurant.id + ' | Branch ID: ' + branch.id + '\n');
    process.stdout.write('Password was set from ADMIN_PASSWORD in your local .env.\n');
  });
}
main().catch(error => { process.stderr.write(error.stack + '\n'); process.exitCode = 1; })
  .finally(async () => sequelize.close());
