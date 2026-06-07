const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  idOf,
  serializeUser,
  serializeCategory,
  serializeNewsPost,
  serializeFeedPost,
} = require('../../utils/serializers');

describe('serializers', () => {
  it('idOf returns string id from object or string', () => {
    assert.equal(idOf('abc'), 'abc');
    assert.equal(idOf({ id: 'uuid-1' }), 'uuid-1');
    assert.equal(idOf(null), null);
  });

  it('serializeUser maps prisma fields to API shape', () => {
    const user = serializeUser({
      id: 'u1',
      name: 'Ada',
      email: 'ada@test.com',
      role: 'reporter',
      isActive: true,
      isVerified: true,
      createdAt: new Date('2024-01-01'),
    });

    assert.equal(user._id, 'u1');
    assert.equal(user.email, 'ada@test.com');
    assert.equal(user.role, 'reporter');
    assert.equal(user.fcmToken, undefined);
  });

  it('serializeCategory includes slug and icon', () => {
    const cat = serializeCategory({
      id: 'c1',
      name: 'Politics',
      slug: 'politics',
      icon: '🗳️',
      color: '#1D9E75',
    });
    assert.equal(cat.slug, 'politics');
    assert.equal(cat.icon, '🗳️');
  });

  it('serializeNewsPost embeds location when coordinates exist', () => {
    const post = serializeNewsPost({
      id: 'p1',
      title: 'Headline',
      body: 'Body',
      status: 'pending',
      locationLatitude: 16.5,
      locationLongitude: 80.6,
      locationCity: 'Vijayawada',
      locationCountry: 'India',
      tags: ['news'],
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    assert.equal(post.title, 'Headline');
    assert.equal(post.location.city, 'Vijayawada');
    assert.equal(post.location.latitude, 16.5);
  });

  it('serializeFeedPost omits body and admin metadata', () => {
    const post = serializeFeedPost({
      id: 'p1',
      title: 'Headline',
      body: 'Long body text',
      summary: 'Short summary',
      status: 'approved',
      reporter: { id: 'u1', name: 'Rep', email: 'hidden@test.com' },
      approvedBy: { id: 'a1', name: 'Admin' },
      entities: [{ id: 'e1', text: 'Entity' }],
      tags: ['news'],
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    assert.equal(post.summary, 'Short summary');
    assert.equal(post.body, undefined);
    assert.equal(post.approvedBy, undefined);
    assert.equal(post.entities, undefined);
    assert.equal(post.reporter.name, 'Rep');
    assert.equal(post.reporter.email, undefined);
  });
});
