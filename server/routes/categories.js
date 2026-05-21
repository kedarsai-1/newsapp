const express = require('express');
const router = express.Router();
const { prisma } = require('../config/prisma');
const { serializeCategory } = require('../utils/serializers');

// GET /api/categories/by-slug/:slug — resolve topic grid taps when list cache is empty
router.get('/by-slug/:slug', async (req, res) => {
  try {
    const slug = String(req.params.slug || '').trim().toLowerCase();
    if (!slug) return res.status(400).json({ success: false, message: 'Missing slug' });
    const category = await prisma.category.findFirst({ where: { slug, isActive: true } });
    if (!category) {
      return res.status(404).json({ success: false, message: 'Category not found.' });
    }
    return res.json({ success: true, category: serializeCategory(category) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/categories — public
router.get('/', async (req, res) => {
  try {
    const categories = await prisma.category.findMany({
      where: { isActive: true },
      orderBy: [{ order: 'asc' }, { name: 'asc' }],
    });
    res.json({ success: true, categories: categories.map(serializeCategory) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;