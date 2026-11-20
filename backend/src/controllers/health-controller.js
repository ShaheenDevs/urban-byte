const { success } = require('../utils/api-response');
const { sequelize } = require('../config/database-connection');
async function health(req, res) {
  await sequelize.authenticate();
  return success(res, { status: 'ok', database: 'connected', service: 'urban-byte-api' }, 'Service healthy');
}
module.exports = { health };
