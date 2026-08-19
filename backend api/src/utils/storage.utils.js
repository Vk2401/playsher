/**
 * Upload storage drivers.
 *
 *   UPLOAD_DRIVER=local  (default)  — write to ./uploads, served by app.js
 *   UPLOAD_DRIVER=ftp               — push to a remote FTP host (Hostinger
 *                                     public_html) and serve from UPLOAD_PUBLIC_URL
 *
 * The FTP driver exists because serverless hosts have a read-only, ephemeral
 * filesystem: anything written locally disappears on the next cold start.
 */
const path = require('path');
const { Readable } = require('stream');
const { Client } = require('basic-ftp');

const DRIVER = process.env.UPLOAD_DRIVER === 'ftp' ? 'ftp' : 'local';

exports.driver = DRIVER;

/** Public URL for a stored file, e.g. https://cdn.example.com/uploads/sports/x.jpg */
exports.publicUrlFor = (subdir, filename) => {
  const base = (process.env.UPLOAD_PUBLIC_URL || '').replace(/\/+$/, '');
  const relative = `/uploads/${subdir}/${filename}`;
  return base ? `${base}${relative}` : relative;
};

exports.randomFilename = (originalname) => {
  const ext = path.extname(originalname || '').toLowerCase() || '.jpg';
  return `${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`;
};

/**
 * Pushes a buffer to <UPLOAD_FTP_BASE_DIR>/uploads/<subdir>/<filename>.
 * Creates the directory tree on first use.
 */
exports.uploadToFtp = async (buffer, subdir, filename) => {
  const client = new Client(parseInt(process.env.UPLOAD_FTP_TIMEOUT) || 20000);
  try {
    // Tolerate a scheme prefix (ftp://host) — basic-ftp wants a bare hostname.
    const host = String(process.env.UPLOAD_FTP_HOST || '')
      .replace(/^[a-z]+:\/\//i, '')
      .replace(/\/+$/, '');

    await client.access({
      host,
      user:     process.env.UPLOAD_FTP_USER,
      password: process.env.UPLOAD_FTP_PASSWORD,
      port:     parseInt(process.env.UPLOAD_FTP_PORT) || 21,
      secure:   process.env.UPLOAD_FTP_SECURE === 'true',
      secureOptions: { rejectUnauthorized: false },
    });

    const baseDir = (process.env.UPLOAD_FTP_BASE_DIR || '/public_html').replace(/\/+$/, '');
    await client.ensureDir(`${baseDir}/uploads/${subdir}`);
    await client.uploadFrom(Readable.from(buffer), filename);
  } finally {
    client.close();
  }
};
