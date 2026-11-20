const { Sequelize } = require('sequelize');
const config = require('./database')[process.env.NODE_ENV || 'development'];
const sequelize = new Sequelize(config.database, config.username, config.password, config);
async function connectDatabase() { await sequelize.authenticate(); return sequelize; }
module.exports = { sequelize, connectDatabase };
