const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { prisma } = require('../../config/prisma');
const { markPostSeen, getFeed, getPost } = require('../../controllers/newsController');

describe('seenTracking', () => {
  let originalFindMany;
  let originalUpsert;
  let originalFindUnique;
  let originalFindFirst;
  let originalNewsPostFindMany;
  let originalCount;

  beforeEach(() => {
    originalFindMany = prisma.postSeen.findMany;
    originalUpsert = prisma.postSeen.upsert;
    originalFindUnique = prisma.newsPost.findUnique;
    originalFindFirst = prisma.newsPost.findFirst;
    originalNewsPostFindMany = prisma.newsPost.findMany;
    originalCount = prisma.newsPost.count;
  });

  afterEach(() => {
    prisma.postSeen.findMany = originalFindMany;
    prisma.postSeen.upsert = originalUpsert;
    prisma.newsPost.findUnique = originalFindUnique;
    prisma.newsPost.findFirst = originalFindFirst;
    prisma.newsPost.findMany = originalNewsPostFindMany;
    prisma.newsPost.count = originalCount;
  });

  it('markPostSeen returns 401 when user is not authenticated', async () => {
    const req = {
      params: { id: 'post-1' },
      user: null,
    };
    const res = {
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
    };

    await markPostSeen(req, res);
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.success, false);
    assert.equal(res.body.message, 'Authorization required.');
  });

  it('markPostSeen returns 404 when post does not exist', async () => {
    prisma.newsPost.findUnique = async () => null;

    const req = {
      params: { id: 'post-1' },
      user: { id: 'user-1' },
    };
    const res = {
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
    };

    await markPostSeen(req, res);
    assert.equal(res.statusCode, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.message, 'Post not found.');
  });

  it('markPostSeen records seen status and returns 200 when post exists and user is authenticated', async () => {
    let upsertCalled = false;
    prisma.newsPost.findUnique = async () => ({ id: 'post-1' });
    prisma.postSeen.upsert = async (args) => {
      upsertCalled = true;
      assert.equal(args.where.userId_postId.userId, 'user-1');
      assert.equal(args.where.userId_postId.postId, 'post-1');
      return {};
    };

    const req = {
      params: { id: 'post-1' },
      user: { id: 'user-1' },
    };
    const res = {
      json(data) {
        this.body = data;
        return this;
      },
    };

    await markPostSeen(req, res);
    assert.equal(upsertCalled, true);
    assert.equal(res.body.success, true);
    assert.equal(res.body.message, 'Post marked as seen.');
  });
});
