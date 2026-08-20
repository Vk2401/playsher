const router = require('express').Router();

// Public / cross-role routes
router.use('/auth',          require('./auth.routes'));
router.use('/grounds',       require('./ground.routes'));
router.use('/sports',        require('./sport.routes'));
router.use('/amenities',     require('./amenity.routes'));
router.use('/users',         require('./user.routes'));
router.use('/profile',       require('./profile.routes'));
router.use('/ground-owners', require('./groundOwner.routes'));
router.use('/ground-sports', require('./groundSport.routes'));
router.use('/bookings',      require('./booking.routes'));
router.use('/payments',      require('./payment.routes'));
router.use('/games',         require('./game.routes'));
router.use('/coaches',       require('./coach.routes'));
router.use('/reviews',       require('./review.routes'));
router.use('/favorites',     require('./favorite.routes'));
router.use('/app-version',   require('./appVersion.routes'));

// Bank details (authenticated — any role with bank account)
const bankDetailsCtrl = require('../controllers/bankDetails.controller');
const { verifyToken } = require('../middleware/auth');
router.get ('/bank-details',     verifyToken, bankDetailsCtrl.get);
router.post('/add-bank-details', verifyToken, bankDetailsCtrl.save);

// Admin panel (role-protected, all routes require admin)
router.use('/admin',         require('./adminPanel.routes'));

// Ground owner panel (role-protected, all routes require ground_owner)
router.use('/ground-owner',  require('./ownerPanel.routes'));

module.exports = router;
