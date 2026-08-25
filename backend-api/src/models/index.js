const sequelize = require('../config/database');

// Import model factories
const Admin            = require('./Admin')(sequelize);
const User             = require('./User')(sequelize);
const GroundOwner      = require('./GroundOwner')(sequelize);
const Ground           = require('./Ground')(sequelize);
const GroundImage      = require('./GroundImage')(sequelize);
const Amenity          = require('./Amenity')(sequelize);
const GroundAmenity    = require('./GroundAmenity')(sequelize);
const Sport            = require('./Sport')(sequelize);
const GroundSport      = require('./GroundSport')(sequelize);
const Slot             = require('./Slot')(sequelize);
const Booking          = require('./Booking')(sequelize);
const BookedSlot       = require('./BookedSlot')(sequelize);
const Payment          = require('./Payment')(sequelize);
const Game             = require('./Game')(sequelize);
const GameParticipant  = require('./GameParticipant')(sequelize);
const Coach            = require('./Coach')(sequelize);
const CoachAvailability= require('./CoachAvailability')(sequelize);
const CoachSlot        = require('./CoachSlot')(sequelize);
const CoachGround      = require('./CoachGround')(sequelize);
const CoachBooking     = require('./CoachBooking')(sequelize);
const CoachBookingSlot = require('./CoachBookingSlot')(sequelize);
const Notification     = require('./Notification')(sequelize);
const Review           = require('./Review')(sequelize);
const Favorite         = require('./Favorite')(sequelize);
const UserSportPreference = require('./UserSportPreference')(sequelize);
const RefreshToken     = require('./RefreshToken')(sequelize);
const Otp              = require('./Otp')(sequelize);
const BankDetails      = require('./BankDetails')(sequelize);
const ScheduleTemplate = require('./ScheduleTemplate')(sequelize);
const AppVersion       = require('./AppVersion')(sequelize);

// ── Associations ──────────────────────────────────────────────────────────────

// GroundOwner → Ground
GroundOwner.hasMany(Ground, { foreignKey: 'owner_id', as: 'grounds' });
Ground.belongsTo(GroundOwner, { foreignKey: 'owner_id', as: 'owner' });

// Ground → GroundImage
Ground.hasMany(GroundImage, { foreignKey: 'ground_id', as: 'images' });
GroundImage.belongsTo(Ground, { foreignKey: 'ground_id', as: 'ground' });

// Ground ↔ Amenity (via GroundAmenity pivot)
Ground.belongsToMany(Amenity, { through: GroundAmenity, foreignKey: 'ground_id', otherKey: 'amenity_id', as: 'amenities' });
Amenity.belongsToMany(Ground, { through: GroundAmenity, foreignKey: 'amenity_id', otherKey: 'ground_id', as: 'grounds' });
Ground.hasMany(GroundAmenity, { foreignKey: 'ground_id' });
GroundAmenity.belongsTo(Ground,  { foreignKey: 'ground_id' });
GroundAmenity.belongsTo(Amenity, { foreignKey: 'amenity_id' });

// Ground ↔ Sport (via GroundSport)
Ground.hasMany(GroundSport, { foreignKey: 'ground_id', as: 'groundSports' });
GroundSport.belongsTo(Ground, { foreignKey: 'ground_id', as: 'ground' });
Sport.hasMany(GroundSport, { foreignKey: 'sport_id', as: 'groundSports' });
GroundSport.belongsTo(Sport, { foreignKey: 'sport_id', as: 'sport' });

// GroundSport → Slot
GroundSport.hasMany(Slot, { foreignKey: 'ground_sport_id', as: 'slots' });
Slot.belongsTo(GroundSport, { foreignKey: 'ground_sport_id', as: 'groundSport' });

// GroundSport → ScheduleTemplate
GroundSport.hasMany(ScheduleTemplate, { foreignKey: 'ground_sport_id', as: 'schedules' });
ScheduleTemplate.belongsTo(GroundSport, { foreignKey: 'ground_sport_id', as: 'groundSport' });

// User → Booking
User.hasMany(Booking, { foreignKey: 'user_id', as: 'bookings' });
Booking.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// GroundSport → Booking
GroundSport.hasMany(Booking, { foreignKey: 'ground_sport_id', as: 'bookings' });
Booking.belongsTo(GroundSport, { foreignKey: 'ground_sport_id', as: 'groundSport' });

// Booking ↔ Slot (via BookedSlot pivot)
Booking.belongsToMany(Slot, { through: BookedSlot, foreignKey: 'booking_id', otherKey: 'slot_id', as: 'slots' });
Slot.belongsToMany(Booking, { through: BookedSlot, foreignKey: 'slot_id', otherKey: 'booking_id', as: 'bookings' });
Booking.hasMany(BookedSlot, { foreignKey: 'booking_id' });
BookedSlot.belongsTo(Booking, { foreignKey: 'booking_id' });
BookedSlot.belongsTo(Slot,    { foreignKey: 'slot_id' });

// Booking ↔ Payment
Payment.hasOne(Booking, { foreignKey: 'payment_id', as: 'booking' });
Booking.belongsTo(Payment, { foreignKey: 'payment_id', as: 'payment' });
Booking.hasOne(Payment, { foreignKey: 'booking_id', as: 'paymentRecord' });
Payment.belongsTo(Booking, { foreignKey: 'booking_id', as: 'bookingRecord' });
User.hasMany(Payment, { foreignKey: 'done_by_user_id', as: 'payments' });
Payment.belongsTo(User, { foreignKey: 'done_by_user_id', as: 'paidBy' });

// Game
User.hasMany(Game, { foreignKey: 'hosted_by_user_id', as: 'hostedGames' });
Game.belongsTo(User, { foreignKey: 'hosted_by_user_id', as: 'hostedByUser' });
GroundOwner.hasMany(Game, { foreignKey: 'hosted_by_ground_owner_id', as: 'hostedGames' });
Game.belongsTo(GroundOwner, { foreignKey: 'hosted_by_ground_owner_id', as: 'hostedByOwner' });
Booking.hasOne(Game, { foreignKey: 'booking_id', as: 'game' });
Game.belongsTo(Booking, { foreignKey: 'booking_id', as: 'booking' });

// Game ↔ GameParticipant
Game.hasMany(GameParticipant, { foreignKey: 'game_id', as: 'participants' });
GameParticipant.belongsTo(Game, { foreignKey: 'game_id', as: 'game' });
User.hasMany(GameParticipant, { foreignKey: 'user_id', as: 'gameParticipations' });
GameParticipant.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

// Reviews
User.hasMany(Review, { foreignKey: 'reviewed_by_user_id', as: 'reviews' });
Review.belongsTo(User, { foreignKey: 'reviewed_by_user_id', as: 'reviewer' });
Ground.hasMany(Review, { foreignKey: 'ground_id', as: 'reviews' });
Review.belongsTo(Ground, { foreignKey: 'ground_id', as: 'ground' });
GroundSport.hasMany(Review, { foreignKey: 'ground_sport_id', as: 'reviews' });
Review.belongsTo(GroundSport, { foreignKey: 'ground_sport_id', as: 'groundSport' });
Coach.hasMany(Review, { foreignKey: 'coach_id', as: 'reviews' });
Review.belongsTo(Coach, { foreignKey: 'coach_id', as: 'coach' });
Booking.hasMany(Review, { foreignKey: 'booking_id', as: 'reviews' });
Review.belongsTo(Booking, { foreignKey: 'booking_id', as: 'booking' });

// ── Coaching ──────────────────────────────────────────────────────────────────

// Coach → Sport. sport_name is kept alongside for the rows that predate the
// foreign key; the id is what new code filters on.
Sport.hasMany(Coach, { foreignKey: 'sport_id', as: 'coaches' });
Coach.belongsTo(Sport, { foreignKey: 'sport_id', as: 'sport' });

// Coach → weekly hours and the concrete blocks generated from them
Coach.hasMany(CoachAvailability, { foreignKey: 'coach_id', as: 'availabilities' });
CoachAvailability.belongsTo(Coach, { foreignKey: 'coach_id', as: 'coach' });
Coach.hasMany(CoachSlot, { foreignKey: 'coach_id', as: 'coachSlots' });
CoachSlot.belongsTo(Coach, { foreignKey: 'coach_id', as: 'coach' });

// Coach ↔ Ground, through the owner-approved registration
Coach.hasMany(CoachGround, { foreignKey: 'coach_id', as: 'groundLinks' });
CoachGround.belongsTo(Coach, { foreignKey: 'coach_id', as: 'coach' });
Ground.hasMany(CoachGround, { foreignKey: 'ground_id', as: 'coachLinks' });
CoachGround.belongsTo(Ground, { foreignKey: 'ground_id', as: 'ground' });

// Coaching sessions
User.hasMany(CoachBooking, { foreignKey: 'user_id', as: 'coachBookings' });
CoachBooking.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Coach.hasMany(CoachBooking, { foreignKey: 'coach_id', as: 'bookings' });
CoachBooking.belongsTo(Coach, { foreignKey: 'coach_id', as: 'coach' });
Ground.hasMany(CoachBooking, { foreignKey: 'ground_id', as: 'coachBookings' });
CoachBooking.belongsTo(Ground, { foreignKey: 'ground_id', as: 'ground' });
CoachBooking.belongsTo(Payment, { foreignKey: 'payment_id', as: 'payment' });

// CoachBooking ↔ CoachSlot (via CoachBookingSlot pivot)
CoachBooking.belongsToMany(CoachSlot, {
  through: CoachBookingSlot, foreignKey: 'coach_booking_id', otherKey: 'coach_slot_id', as: 'slots',
});
CoachSlot.belongsToMany(CoachBooking, {
  through: CoachBookingSlot, foreignKey: 'coach_slot_id', otherKey: 'coach_booking_id', as: 'bookings',
});
CoachBooking.hasMany(CoachBookingSlot, { foreignKey: 'coach_booking_id' });
CoachBookingSlot.belongsTo(CoachBooking, { foreignKey: 'coach_booking_id' });
CoachBookingSlot.belongsTo(CoachSlot,    { foreignKey: 'coach_slot_id' });

// ─────────────────────────────────────────────────────────────────────────────

// Favorites
User.hasMany(Favorite, { foreignKey: 'user_id', as: 'favorites' });
Favorite.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Ground.hasMany(Favorite, { foreignKey: 'ground_id', as: 'favoritedBy' });
Favorite.belongsTo(Ground, { foreignKey: 'ground_id', as: 'ground' });

// UserSportPreferences
User.hasMany(UserSportPreference, { foreignKey: 'user_id', as: 'sportPreferences' });
UserSportPreference.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Sport.hasMany(UserSportPreference, { foreignKey: 'sport_id', as: 'userPreferences' });
UserSportPreference.belongsTo(Sport, { foreignKey: 'sport_id', as: 'sport' });

// BankDetails
GroundOwner.hasMany(BankDetails, { foreignKey: 'user_id', as: 'bankDetails',
  constraints: false, scope: { user_type: 'ground_owner' } });
BankDetails.belongsTo(GroundOwner, { foreignKey: 'user_id', as: 'owner', constraints: false });

// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
  sequelize,
  Admin,
  User,
  GroundOwner,
  Ground,
  GroundImage,
  Amenity,
  GroundAmenity,
  Sport,
  GroundSport,
  Slot,
  Booking,
  BookedSlot,
  Payment,
  Game,
  GameParticipant,
  Coach,
  CoachAvailability,
  CoachSlot,
  CoachGround,
  CoachBooking,
  CoachBookingSlot,
  Notification,
  Review,
  Favorite,
  UserSportPreference,
  RefreshToken,
  Otp,
  BankDetails,
  ScheduleTemplate,
  AppVersion,
};
