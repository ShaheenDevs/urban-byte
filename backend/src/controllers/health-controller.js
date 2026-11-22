'use strict';
const { success } = require('../utils/api-response');
const { sequelize, Restaurant, Branch, User, Role, Permission, MenuCategory, Product, InventoryItem, Supplier } = require('../models');

async function health(req, res, next) {
  try {
    await sequelize.authenticate();
    return success(res, { status: 'ok', database: 'connected', service: 'urban-byte-api' }, 'Service healthy');
  } catch (error) { return next(error); }
}

async function setupStatus(req, res, next) {
  try {
    await sequelize.authenticate();
    const [restaurants, branches, owners, roles, permissions, categories, products, ingredients, suppliers] = await Promise.all([
      Restaurant.count(), Branch.count(), User.count({ where: { isActive: true, restaurantId: { [require('sequelize').Op.ne]: null } } }),
      Role.count(), Permission.count(), MenuCategory.count(), Product.count(), InventoryItem.count(), Supplier.count()
    ]);
    const checks = {
      restaurant: restaurants > 0,
      branch: branches > 0,
      ownerAccount: owners > 0,
      roles: roles > 0,
      permissions: permissions > 0,
      menuCategories: categories > 0,
      menuProducts: products > 0,
      inventoryIngredients: ingredients > 0,
      suppliers: suppliers > 0
    };
    const ready = Object.values(checks).every(Boolean);
    return success(res, {
      status: ready ? 'ready' : 'setup_required',
      ready,
      checks,
      counts: { restaurants, branches, activeRestaurantUsers: owners, roles, permissions, menuCategories: categories, products, inventoryItems: ingredients, suppliers }
    }, ready ? 'Initial restaurant setup is ready.' : 'Initial restaurant setup is incomplete.');
  } catch (error) { return next(error); }
}
module.exports = { health, setupStatus };
