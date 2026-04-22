/** Default categories when the DB is empty or missing `general` (used by scraper). */
const defaultCategories = [
  { name: 'General', slug: 'general', icon: '📰', color: '#1D9E75', order: 0 },
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

module.exports = { defaultCategories };
