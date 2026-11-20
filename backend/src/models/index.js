'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database-connection');
const models = {};
for (const file of fs.readdirSync(__dirname).filter((name) => name.endsWith('.js') && name !== 'index.js')) {
  const defineModel = require(path.join(__dirname, file));
  const model = defineModel(sequelize, DataTypes);
  models[model.name] = model;
}
Object.values(models).forEach((model) => { if (typeof model.associate === 'function') model.associate(models); });
module.exports = { sequelize, ...models };
