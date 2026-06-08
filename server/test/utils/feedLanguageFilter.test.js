const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

describe('feed language filter (YouTube shorts regression)', () => {
  it('english languageWhere must include rows with null originalLanguage', async () => {
    require('dotenv').config();
    const { prisma } = require('../../config/prisma');

    const allowOriginalLanguages = (codes) => ({
      OR: [
        { originalLanguage: null },
        { NOT: { originalLanguage: { in: codes } } },
      ],
    });

    const brokenWhere = {
      status: 'approved',
      sourceType: 'youtube',
      youtubeIsShort: true,
      language: 'en',
      NOT: { originalLanguage: { in: ['hin', 'tel', 'hi', 'te'] } },
    };
    const fixedWhere = {
      status: 'approved',
      sourceType: 'youtube',
      youtubeIsShort: true,
      language: 'en',
      ...allowOriginalLanguages(['hin', 'tel', 'hi', 'te']),
    };

    const broken = await prisma.newsPost.count({ where: brokenWhere });
    const fixed = await prisma.newsPost.count({ where: fixedWhere });
    assert.ok(fixed > 0, 'expected english youtube shorts in DB');
    assert.ok(fixed > broken, 'null originalLanguage rows must not be excluded');

    await prisma.$disconnect();
  });
});
