const multer = require('multer');
const path = require('path');
const fs = require('fs');

function makeStorage(subdir) {
  const dest = path.join(process.cwd(), 'uploads', subdir);
  if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
  return multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, dest),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
      cb(null, `${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`);
    },
  });
}

const imageFilter = (_req, file, cb) => {
  if (/^image\//i.test(file.mimetype)) cb(null, true);
  else cb(new Error('Only image files are allowed.'), false);
};

const limits = { fileSize: 5 * 1024 * 1024 }; // 5 MB

exports.uploadSport    = multer({ storage: makeStorage('sports'),    fileFilter: imageFilter, limits }).single('image');
exports.uploadAmenity  = multer({ storage: makeStorage('amenities'), fileFilter: imageFilter, limits }).single('icon');
exports.uploadCoach    = multer({ storage: makeStorage('coaches'),   fileFilter: imageFilter, limits }).single('profile_image');
exports.uploadGround   = multer({ storage: makeStorage('grounds'),   fileFilter: imageFilter, limits }).single('main_image');
exports.uploadGroundImg = multer({ storage: makeStorage('grounds'),  fileFilter: imageFilter, limits }).single('image');
