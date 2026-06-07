const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  getPost,
  isValidUuid,
  resolveCategoryFilter,
} = require('../../controllers/newsController');
const { prisma } = require('../../config/prisma');

describe('newsController validation', () => {
  it('isValidUuid rejects malformed ids', () => {
    assert.equal(isValidUuid('not-a-uuid'), false);
    assert.equal(isValidUuid(''), false);
    assert.equal(isValidUuid('550e8400-e29b-41d4-a716-446655440000'), true);
  });

  it('getPost returns 400 for invalid uuid without hitting prisma', async () => {
    let prismaCalled = false;
    const originalFindFirst = prisma.newsPost.findFirst;
    prisma.newsPost.findFirst = async () => {
      prismaCalled = true;
      return null;
    };

    const req = { params: { id: 'not-a-uuid' }, user: null };
    const res = {
      statusCode: 200,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
      set() {
        return this;
      },
    };

    try {
      await getPost(req, res);
      assert.equal(res.statusCode, 400);
      assert.equal(res.body.message, 'Invalid post id');
      assert.equal(prismaCalled, false);
    } finally {
      prisma.newsPost.findFirst = originalFindFirst;
    }
  });

  it('resolveCategoryFilter resolves slug to category id', async () => {
    const originalFindFirst = prisma.category.findFirst;
    prisma.category.findFirst = async ({ where }) => {
      if (where.slug === 'politics') {
        return { id: 'cat-politics-uuid', slug: 'politics' };
      }
      return null;
    };

    try {
      const out = await resolveCategoryFilter('politics');
      assert.equal(out.categoryId, 'cat-politics-uuid');
      assert.equal(out.categorySlugFilter, 'politics');
    } finally {
      prisma.category.findFirst = originalFindFirst;
    }
  });
});
