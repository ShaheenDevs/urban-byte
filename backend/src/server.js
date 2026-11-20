const { validateEnv, port, nodeEnv } = require('./config/env');
const app = require('./app');
const { connectDatabase } = require('./config/database-connection');
async function start() {
  validateEnv();
  await connectDatabase();
  const server = app.listen(port, () => console.log(`Urban Byte API listening on port ${port} (${nodeEnv})`));
  const shutdown = (signal) => { console.log(`${signal} received; shutting down`); server.close(() => process.exit(0)); };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}
start().catch((error) => { console.error('Failed to start Urban Byte API:', error.message); process.exit(1); });
