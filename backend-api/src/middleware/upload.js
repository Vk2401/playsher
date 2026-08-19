const multer = require('multer');
const path = require('path');
const fs = require('fs');
const storage = require('../utils/storage.utils');

const imageFilter = (_req, file, cb) => {
  if (/^image\//i.test(file.mimetype)) cb(null, true);
  else cb(new Error('Only image files are allowed.'), false);
};

const limits = { fileSize: 5 * 1024 * 1024 }; // 5 MB

function diskStorage(subdir) {
  const dest = path.join(process.cwd(), 'uploads', subdir);
  return multer.diskStorage({
    // Created on first upload, not at import: the module also loads on hosts with
    // a read-only filesystem, where an import-time mkdir crashes the whole app.
    destination: (_req, _file, cb) => {
      try {
        if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
        cb(null, dest);
      } catch (err) {
        cb(err);
      }
    },
    filename: (_req, file, cb) => cb(null, storage.randomFilename(file.originalname)),
  });
}

/**
 * Runs after multer and puts the stored file's public URL on `req.file.publicUrl`,
 * which is what controllers persist. With the ftp driver this is where the bytes
 * actually leave the process.
 */
function persist(subdir) {
  return async (req, _res, next) => {
    if (!req.file) return next();
    try {
      if (storage.driver === 'ftp') {
        req.file.filename = storage.randomFilename(req.file.originalname);
        await storage.uploadToFtp(req.file.buffer, subdir, req.file.filename);
      }
      req.file.publicUrl = storage.publicUrlFor(subdir, req.file.filename);
      next();
    } catch (err) {
      next(new Error(`Image upload failed: ${err.message}`));
    }
  };
}

function uploader(subdir, field) {
  const engine = storage.driver === 'ftp' ? multer.memoryStorage() : diskStorage(subdir);
  return [multer({ storage: engine, fileFilter: imageFilter, limits }).single(field), persist(subdir)];
}

exports.uploadSport     = uploader('sports',    'image');
exports.uploadAmenity   = uploader('amenities', 'icon');
exports.uploadCoach     = uploader('coaches',   'profile_image');
exports.uploadGround    = uploader('grounds',   'main_image');
exports.uploadGroundImg = uploader('grounds',   'image');
