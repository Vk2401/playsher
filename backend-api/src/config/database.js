const { Sequelize } = require('sequelize');
// Required explicitly so bundlers that trace imports statically (Vercel) include
// it — Sequelize resolves its dialect dynamically, which they cannot follow.
const mysql2 = require('mysql2');

// Serverless hosts run many short-lived instances, each with its own pool, while
// shared-hosting MySQL caps total connections low — keep DB_POOL_MAX at 2 there.
const poolMax = parseInt(process.env.DB_POOL_MAX) || 10;

// Managed/remote MySQL usually requires TLS. Opt in with DB_SSL=true.
const dialectOptions = process.env.DB_SSL === 'true'
  ? { ssl: { rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false' } }
  : {};

const sequelize = new Sequelize(
  process.env.DB_NAME || 'playsher_db',
  process.env.DB_USER || 'root',
  process.env.DB_PASSWORD || '',
  {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 3306,
    dialect: 'mysql',
    dialectModule: mysql2,
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    dialectOptions,
    pool: {
      max: poolMax,
      min: 0,
      acquire: 30000,
      idle: parseInt(process.env.DB_POOL_IDLE) || 10000,
    },
    define: {
      timestamps: true,
      underscored: true,
    },
    timezone: '+00:00',
  }
);

module.exports = sequelize;
