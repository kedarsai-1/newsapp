// Run with: node server/seed.js
require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const User = require('./models/User');
const Category = require('./models/Category');

const categories = [
  { name: 'Politics', slug: 'politics', icon: '🏛️', color: '#185FA5', order: 1 },
  { name: 'Sports', slug: 'sports', icon: '⚽', color: '#1D9E75', order: 2 },
  { name: 'Technology', slug: 'technology', icon: '💻', color: '#534AB7', order: 3 },
  { name: 'Entertainment', slug: 'entertainment', icon: '🎬', color: '#D14520', order: 4 },
  { name: 'Business', slug: 'business', icon: '📈', color: '#854F0B', order: 5 },
  { name: 'Health', slug: 'health', icon: '🏥', color: '#0F6E56', order: 6 },
  { name: 'Education', slug: 'education', icon: '🎓', color: '#3B6D11', order: 7 },
  { name: 'Local', slug: 'local', icon: '📍', color: '#A32D2D', order: 8 },
  { name: 'Crime', slug: 'crime', icon: '🚨', color: '#993C1D', order: 9 },
  { name: 'Weather', slug: 'weather', icon: '🌦️', color: '#378ADD', order: 10 },
];

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // Seed categories
    await Category.deleteMany({});
    await Category.insertMany(categories);
    console.log(`✅ Seeded ${categories.length} categories`);

    // Create admin user
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

    // Create sample reporter
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