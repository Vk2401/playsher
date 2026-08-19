/**
 * Create an admin user in the database.
 * Run from playsher-api directory: node scripts/createAdmin.js
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Sequelize } = require('sequelize');

const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASSWORD,
  {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    dialect: 'mysql',
    logging: false,
  }
);

async function createAdmin() {
  await sequelize.authenticate();
  console.log('DB connected.');

  const NAME     = 'sabarish';
  const EMAIL    = 'sabarish@playsher.com';
  const MOBILE   = '0000000001';
  const PASSWORD = 'sabarish';

  // Check if already exists
  const [existing] = await sequelize.query(
    'SELECT id, email FROM admins WHERE email = ? OR name = ?',
    { replacements: [EMAIL, NAME], type: Sequelize.QueryTypes.SELECT }
  );

  if (existing) {
    console.log(`Admin already exists: id=${existing.id} email=${existing.email}`);
    await sequelize.close();
    return;
  }

  const password_hash = await bcrypt.hash(PASSWORD, 12);
  const [result] = await sequelize.query(
    `INSERT INTO admins (name, email, mobile, password_hash, is_active, created_at, updated_at)
     VALUES (?, ?, ?, ?, 1, NOW(), NOW())`,
    { replacements: [NAME, EMAIL, MOBILE, password_hash] }
  );

  console.log('✓ Admin created successfully!');
  console.log(`  Name    : ${NAME}`);
  console.log(`  Email   : ${EMAIL}`);
  console.log(`  Password: ${PASSWORD}`);
  console.log(`  ID      : ${result}`);

  await sequelize.close();
}

createAdmin().catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
