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
    // Still start server even if DB connection fails in local dev without PostgreSQL running
    app.listen(env.port, () => {
      console.log(`Server is running on port ${env.port} (Database not connected yet)`);
      console.log(`Health check: http://localhost:${env.port}/health`);
    });
  }
};

startServer();
