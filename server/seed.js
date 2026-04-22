// Run with: npm run seed  OR  node seed.js
require('dotenv').config();
const mongoose = require('mongoose');

const User = require('./models/User');
const Category = require('./models/Category');
const { defaultCategories } = require('./config/defaultCategories');

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    await Category.deleteMany({});
    await Category.insertMany(defaultCategories);
    console.log(`✅ Seeded ${defaultCategories.length} categories`);

    const existing = await User.findOne({ email: 'admin@newsapp.com' });
    if (!existing) {
      await User.create({
        name: 'Super Admin',
        email: 'admin@newsapp.com',
        password: 'Admin@123',
        role: 'admin',
        isActive: true,
        isVerified: true,
      });
      console.log('✅ Admin user created: admin@newsapp.com / Admin@123');
    } else {
      console.log('ℹ️  Admin user already exists');
    }

    const reporter = await User.findOne({ email: 'reporter@newsapp.com' });
    if (!reporter) {
      await User.create({
        name: 'Sample Reporter',
        email: 'reporter@newsapp.com',
        password: 'Reporter@123',
        role: 'reporter',
        isActive: true,
        isVerified: true,
      });
      console.log('✅ Reporter created: reporter@newsapp.com / Reporter@123');
    }

    console.log('\n🎉 Database seeded successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Seed error:', err);
    process.exit(1);
  }
};

seed();
