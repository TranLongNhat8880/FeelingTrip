const app = require('./app');
const env = require('./config/env');
const db = require('./config/database');

const startServer = async () => {
  try {
    // Check database connection
    console.log('Connecting to PostgreSQL database...');
    await db.query('SELECT NOW()');
    console.log('PostgreSQL database connected successfully!');

    app.listen(env.port, () => {
      console.log(`Server is running on port ${env.port} in [${env.nodeEnv}] mode`);
      console.log(`Health check: http://localhost:${env.port}/health`);
    });
  } catch (error) {
    console.error('Failed to start server:', error.message);
    await db.pool.end();
    process.exitCode = 1;
  }
};

startServer();
