/**
 * Playsher Database Seed Script
 * Creates sample data: sports, amenities, ground owners, grounds, slots, users, bookings, reviews
 *
 * Usage:
 *   cd E:/playsher/Beckend/playsher-api
 *   node database/seed.js
 *
 * Requires a running MySQL instance with the schema already imported.
 */

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { sequelize } = require('../src/models');
const {
  Sport, Amenity, GroundOwner, Ground, GroundImage,
  GroundSport, GroundAmenity, Slot, User, Booking,
  Payment, Review, Game, GameParticipant, Coach,
  ScheduleTemplate,
} = require('../src/models');

const SALT = 12;
const hash = (pw) => bcrypt.hash(pw, SALT);

// ─────────────────────────────────────────────────────────────────────────────
// Seed data definitions
// ─────────────────────────────────────────────────────────────────────────────

const SPORTS = [
  { name: 'Cricket',    is_approved: true, is_active: true },
  { name: 'Football',   is_approved: true, is_active: true },
  { name: 'Tennis',     is_approved: true, is_active: true },
  { name: 'Badminton',  is_approved: true, is_active: true },
  { name: 'Basketball', is_approved: true, is_active: true },
  { name: 'Squash',     is_approved: true, is_active: true },
  { name: 'Volleyball', is_approved: true, is_active: true },
];

const AMENITIES = [
  { name: 'Parking',           type: 'venue',  is_active: true },
  { name: 'Changing Rooms',    type: 'venue',  is_active: true },
  { name: 'Floodlights',       type: 'venue',  is_active: true },
  { name: 'Cafeteria',         type: 'venue',  is_active: true },
  { name: 'First Aid',         type: 'venue',  is_active: true },
  { name: 'CCTV',              type: 'venue',  is_active: true },
  { name: 'Wifi',              type: 'venue',  is_active: true },
  { name: 'Scoreboard',        type: 'sport',  is_active: true },
  { name: 'Equipment Rental',  type: 'sport',  is_active: true },
  { name: 'Coaching Available',type: 'sport',  is_active: true },
  { name: 'Referee Service',   type: 'sport',  is_active: true },
  { name: 'Water Dispenser',   type: 'venue',  is_active: true },
];

const GROUND_OWNERS = [
  { name: 'Ali Sports Complex',  email: 'ali@playsher.com',  mobile: '03001234501', password: 'Owner@123', is_approved: true, is_active: true },
  { name: 'Zara Sports Hub',     email: 'zara@playsher.com', mobile: '03001234502', password: 'Owner@123', is_approved: true, is_active: true },
];

const USERS = [
  { name: 'Ahmed Khan',  mobile: '03111234001', email: 'ahmed@example.com',  password: 'User@123' },
  { name: 'Sara Malik',  mobile: '03111234002', email: 'sara@example.com',   password: 'User@123' },
  { name: 'Bilal Ahmed', mobile: '03111234003', email: 'bilal@example.com',  password: 'User@123' },
  { name: 'Hina Akhtar', mobile: '03111234004', email: 'hina@example.com',   password: 'User@123' },
];

// Grounds — we'll add owner_id after owners are created
const GROUNDS_TEMPLATE = [
  {
    ownerIndex: 0,
    name: 'Green Valley Cricket Ground',
    address: 'Block C, Gulberg III, Lahore',
    city: 'Lahore',
    description: 'Professional cricket ground with well-maintained pitch and outfield. Ideal for club and friendly matches.',
    about: 'Lahore\'s premier cricket venue with day and night facilities.',
    venue_rules: 'No outside food. Studs allowed. Players must be in proper sportswear.',
    latitude: 31.5204,
    longitude: 74.3587,
    is_approved: true,
    is_active: true,
    sportIndices: [0, 3], // Cricket, Badminton
    amenityIndices: [0, 1, 2, 4, 7, 11],
    price_per_slot: 2500,
  },
  {
    ownerIndex: 0,
    name: 'Elite Football Arena',
    address: 'DHA Phase 5, Lahore',
    city: 'Lahore',
    description: 'FIFA-standard 5-a-side and 7-a-side football turf with artificial grass. Floodlit for night matches.',
    about: 'Best football turf in Lahore\'s DHA with international standard artificial grass.',
    venue_rules: 'Flat-soled shoes only. No smoking. Maximum 14 players per booking.',
    latitude: 31.4697,
    longitude: 74.4064,
    is_approved: true,
    is_active: true,
    sportIndices: [1, 4], // Football, Basketball
    amenityIndices: [0, 1, 2, 3, 5, 8],
    price_per_slot: 3000,
  },
  {
    ownerIndex: 1,
    name: 'Zara Sports Complex',
    address: 'Bahria Town Phase 4, Rawalpindi',
    city: 'Rawalpindi',
    description: 'Multi-sport complex with courts for tennis, badminton, and squash. Air-conditioned indoor courts available.',
    about: 'Rawalpindi\'s most versatile sports complex with indoor and outdoor facilities.',
    venue_rules: 'Sport-specific shoes required. Advance booking mandatory.',
    latitude: 33.5651,
    longitude: 73.0169,
    is_approved: true,
    is_active: true,
    sportIndices: [2, 3, 5], // Tennis, Badminton, Squash
    amenityIndices: [0, 1, 3, 4, 6, 9, 10],
    price_per_slot: 1800,
  },
  {
    ownerIndex: 1,
    name: 'Champions Basketball Court',
    address: 'F-8 Markaz, Islamabad',
    city: 'Islamabad',
    description: 'Professional basketball court with hardwood flooring and international-standard hoops. Full 5v5 court.',
    about: 'Islamabad\'s first dedicated basketball facility with indoor hardwood courts.',
    venue_rules: 'Basketball shoes only. No jewellery. Respect referee decisions.',
    latitude: 33.7077,
    longitude: 73.0479,
    is_approved: true,
    is_active: true,
    sportIndices: [4, 6], // Basketball, Volleyball
    amenityIndices: [0, 1, 5, 7, 11],
    price_per_slot: 2000,
  },
];

const COACHES = [
  { name: 'Coach Tariq', bio: 'Ex-national cricket player with 15 years coaching experience.', hourly_rate: 1500, is_approved: true, is_active: true },
  { name: 'Coach Imran', bio: 'UEFA B Licensed football coach, specialises in youth development.', hourly_rate: 2000, is_approved: true, is_active: true },
];

// ─────────────────────────────────────────────────────────────────────────────
// Helper: generate weekly schedule templates (7 days, 06:00-22:00)
// ─────────────────────────────────────────────────────────────────────────────
function generateScheduleTemplates(groundSportId) {
  const templates = [];
  for (let day = 0; day < 7; day++) {
    templates.push({
      ground_sport_id: groundSportId,
      day_of_week: day,
      start_time: '06:00:00',
      end_time: '22:00:00',
      is_closed: false,
    });
  }
  return templates;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main seed function
// ─────────────────────────────────────────────────────────────────────────────
async function seed() {
  try {
    console.log('🌱  Connecting to database…');
    await sequelize.authenticate();
    console.log('✅  Connected.');

    // ── Sports ────────────────────────────────────────────────────────────
    console.log('\n📌  Seeding sports…');
    const sports = await Promise.all(
      SPORTS.map((s) => Sport.findOrCreate({ where: { name: s.name }, defaults: s }).then(([r]) => r)),
    );
    console.log(`   Created / found ${sports.length} sports.`);

    // ── Amenities ─────────────────────────────────────────────────────────
    console.log('\n📌  Seeding amenities…');
    const amenities = await Promise.all(
      AMENITIES.map((a) => Amenity.findOrCreate({ where: { name: a.name }, defaults: a }).then(([r]) => r)),
    );
    console.log(`   Created / found ${amenities.length} amenities.`);

    // ── Ground Owners ─────────────────────────────────────────────────────
    console.log('\n📌  Seeding ground owners…');
    const groundOwners = [];
    for (const go of GROUND_OWNERS) {
      const [owner] = await GroundOwner.findOrCreate({
        where: { email: go.email },
        defaults: {
          ...go,
          password_hash: await hash(go.password),
        },
      });
      groundOwners.push(owner);
    }
    console.log(`   Created / found ${groundOwners.length} ground owners.`);

    // ── Coaches ────────────────────────────────────────────────────────────
    console.log('\n📌  Seeding coaches…');
    const coaches = [];
    for (let i = 0; i < COACHES.length; i++) {
      const c = COACHES[i];
      const [coach] = await Coach.findOrCreate({
        where: { name: c.name },
        defaults: { ...c, sport_id: sports[i % sports.length].id },
      });
      coaches.push(coach);
    }
    console.log(`   Created / found ${coaches.length} coaches.`);

    // ── Grounds ───────────────────────────────────────────────────────────
    console.log('\n📌  Seeding grounds…');
    const grounds = [];
    for (const gt of GROUNDS_TEMPLATE) {
      const owner = groundOwners[gt.ownerIndex];
      const [ground] = await Ground.findOrCreate({
        where: { name: gt.name },
        defaults: {
          owner_id: owner.id,
          name: gt.name,
          address: gt.address,
          city: gt.city,
          description: gt.description,
          about: gt.about,
          venue_rules: gt.venue_rules,
          latitude: gt.latitude,
          longitude: gt.longitude,
          is_approved: gt.is_approved,
          is_active: gt.is_active,
        },
      });
      grounds.push({ ground, gt });

      // ── Ground Images (placeholder URLs) ──────────────────────────────
      const imgCount = await GroundImage.count({ where: { ground_id: ground.id } });
      if (imgCount === 0) {
        await GroundImage.bulkCreate([
          { ground_id: ground.id, image: `https://picsum.photos/seed/${ground.id}a/800/600`, is_primary: true },
          { ground_id: ground.id, image: `https://picsum.photos/seed/${ground.id}b/800/600`, is_primary: false },
          { ground_id: ground.id, image: `https://picsum.photos/seed/${ground.id}c/800/600`, is_primary: false },
        ]);
      }

      // ── Ground Sports ─────────────────────────────────────────────────
      for (const si of gt.sportIndices) {
        const sport = sports[si];
        const [gs] = await GroundSport.findOrCreate({
          where: { ground_id: ground.id, sport_id: sport.id },
          defaults: {
            ground_id: ground.id,
            sport_id: sport.id,
            price_per_slot: gt.price_per_slot + si * 100,
            currency: 'PKR',
          },
        });

        // ── Schedule Templates ────────────────────────────────────────
        const scheduleCount = await ScheduleTemplate.count({ where: { ground_sport_id: gs.id } });
        if (scheduleCount === 0) {
          const templateData = generateScheduleTemplates(gs.id);
          await ScheduleTemplate.bulkCreate(templateData, { ignoreDuplicates: true });
          console.log(`   Inserted ${templateData.length} schedule templates for ${ground.name} / ${sport.name}`);
        }
      }

      // ── Ground Amenities ──────────────────────────────────────────────
      for (const ai of gt.amenityIndices) {
        const amenity = amenities[ai];
        if (amenity) {
          await GroundAmenity.findOrCreate({
            where: { ground_id: ground.id, amenity_id: amenity.id },
            defaults: { ground_id: ground.id, amenity_id: amenity.id },
          });
        }
      }
    }
    console.log(`   Created / found ${grounds.length} grounds.`);

    // ── Users ─────────────────────────────────────────────────────────────
    console.log('\n📌  Seeding users…');
    const users = [];
    for (const u of USERS) {
      const [user] = await User.findOrCreate({
        where: { mobile: u.mobile },
        defaults: {
          ...u,
          password_hash: await hash(u.password),
          is_active: true,
        },
      });
      users.push(user);
    }
    console.log(`   Created / found ${users.length} users.`);

    // ── Sample Bookings ────────────────────────────────────────────────────
    console.log('\n📌  Seeding sample bookings…');
    const bookingCount = await Booking.count();
    if (bookingCount === 0) {
      const { ensureSlotsForDate } = require('../src/utils/slotGenerator');
      for (let i = 0; i < 2; i++) {
        const { ground, gt } = grounds[i];
        const groundSport = await GroundSport.findOne({ where: { ground_id: ground.id } });
        if (!groundSport) continue;

        const today = new Date().toISOString().split('T')[0];
        // Lazy-generate slots for today so we can book one
        await ensureSlotsForDate(groundSport.id, today);
        const slot = await Slot.findOne({
          where: { ground_sport_id: groundSport.id, slot_date: today, is_available: true },
        });
        if (!slot) continue;

        const user = users[i];
        const booking = await Booking.create({
          user_id: user.id,
          ground_sport_id: groundSport.id,
          booking_date: today,
          status: 'confirmed',
          total_price: groundSport.price_per_slot,
        });

        // Mark slot as unavailable
        await slot.update({ is_available: false });

        // Create BookedSlot (pivot)
        try {
          const { BookedSlot } = require('../src/models');
          await BookedSlot.create({ booking_id: booking.id, slot_id: slot.id });
        } catch (_) { /* model may not exist */ }

        // Payment
        await Payment.create({
          booking_id: booking.id,
          amount: groundSport.price_per_slot,
          payment_status: 'success',
          transaction_id: `TXN${Date.now()}${i}`,
        });
      }
      console.log('   Sample bookings created.');
    } else {
      console.log(`   Skipped — ${bookingCount} bookings already exist.`);
    }

    // ── Sample Reviews ─────────────────────────────────────────────────────
    console.log('\n📌  Seeding sample reviews…');
    const reviewCount = await Review.count();
    if (reviewCount === 0) {
      const reviewData = [
        { user_id: users[0].id, ground_id: grounds[0].ground.id, review_type: 'ground', rating: 5, comment: 'Excellent facility! Pitch was perfect and staff were very helpful.' },
        { user_id: users[1].id, ground_id: grounds[0].ground.id, review_type: 'ground', rating: 4, comment: 'Great cricket ground, clean and well-maintained. Parking could be better.' },
        { user_id: users[2].id, ground_id: grounds[1].ground.id, review_type: 'ground', rating: 5, comment: 'Best football turf in Lahore! The artificial grass is top quality.' },
        { user_id: users[0].id, ground_id: grounds[2].ground.id, review_type: 'ground', rating: 4, comment: 'Nice indoor courts, AC working well. Will book again.' },
        { user_id: users[3].id, ground_id: grounds[3].ground.id, review_type: 'ground', rating: 5, comment: 'Amazing basketball court! Professional level facility.' },
      ];

      for (const rd of reviewData) {
        await Review.create(rd);
      }
      console.log('   Sample reviews created.');
    } else {
      console.log(`   Skipped — ${reviewCount} reviews already exist.`);
    }

    // ── Sample Game ────────────────────────────────────────────────────────
    console.log('\n📌  Seeding sample game…');
    const gameCount = await Game.count();
    if (gameCount === 0) {
      const groundSport = await GroundSport.findOne({ where: { ground_id: grounds[1].ground.id } });
      if (groundSport) {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const game = await Game.create({
          ground_sport_id: groundSport.id,
          host_user_id: users[0].id,
          game_date: tomorrow.toISOString().split('T')[0],
          start_time: '18:00:00',
          end_time: '19:00:00',
          max_players: 10,
          current_players: 1,
          status: 'open',
          description: 'Casual 5-a-side football game. All skill levels welcome!',
          entry_fee: 300,
        });

        await GameParticipant.create({
          game_id: game.id,
          user_id: users[0].id,
          status: 'confirmed',
        });
      }
      console.log('   Sample game created.');
    } else {
      console.log(`   Skipped — ${gameCount} games already exist.`);
    }

    // ── Summary ───────────────────────────────────────────────────────────
    console.log('\n');
    console.log('═══════════════════════════════════════════════════════');
    console.log('  ✅  Seed complete!');
    console.log('═══════════════════════════════════════════════════════');
    console.log('');
    console.log('  Ground Owners:');
    for (const go of GROUND_OWNERS) {
      console.log(`    Email: ${go.email}   Password: ${go.password}`);
    }
    console.log('');
    console.log('  Users:');
    for (const u of USERS) {
      console.log(`    Mobile: ${u.mobile}   Password: ${u.password}   OTP login: use send-otp endpoint`);
    }
    console.log('');
    console.log('  API base: http://localhost:3000/api/v1');
    console.log('  OTP send: POST /api/v1/auth/send-otp  { mobile }');
    console.log('            OTP will be printed to server console');
    console.log('═══════════════════════════════════════════════════════');

    process.exit(0);
  } catch (err) {
    console.error('❌  Seed failed:', err);
    process.exit(1);
  }
}

seed();
