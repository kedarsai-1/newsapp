const { describe, it, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');

// 1. Require modules to mock
const { prisma } = require('../../config/prisma');
const youtubePoliticsFetchService = require('../../services/youtubePoliticsFetchService');
const politicalVideoClassifierService = require('../../services/politicalVideoClassifierService');
const feedSocket = require('../../services/feedSocket');
const prismaNewsPost = require('../../utils/prismaNewsPost');

// 2. Mutable mock function variables
let mockFetchLatestFromChannels = async () => [];
let mockFilterEmbeddableVideos = async (v) => v;
let mockClassifyVideosBatch = async (v) => v;
let mockPreloadPoliticalClassifier = async () => {};
let mockIsMlEnabled = () => true;
let mockEmitFeedUpdated = async () => {};
let mockCreateNewsPost = async (doc) => ({ id: 'mocked-post-id', ...doc });

// 3. Assign wrapper functions BEFORE requiring politicalVideoIngestionService
youtubePoliticsFetchService.fetchLatestFromChannels = (...args) => mockFetchLatestFromChannels(...args);
youtubePoliticsFetchService.filterEmbeddableVideos = (...args) => mockFilterEmbeddableVideos(...args);
politicalVideoClassifierService.classifyVideosBatch = (...args) => mockClassifyVideosBatch(...args);
politicalVideoClassifierService.preloadPoliticalClassifier = (...args) => mockPreloadPoliticalClassifier(...args);
politicalVideoClassifierService.isMlEnabled = (...args) => mockIsMlEnabled(...args);
feedSocket.emitFeedUpdated = (...args) => mockEmitFeedUpdated(...args);
prismaNewsPost.createNewsPost = (...args) => mockCreateNewsPost(...args);

// 4. Save original prisma functions for restoration
const originalPrisma = {
  user: {
    findUnique: prisma.user.findUnique,
    create: prisma.user.create,
  },
  category: {
    findFirst: prisma.category.findFirst,
  },
  politicalVideo: {
    findFirst: prisma.politicalVideo.findFirst,
    upsert: prisma.politicalVideo.upsert,
  },
  newsPost: {
    findFirst: prisma.newsPost.findFirst,
    create: prisma.newsPost.create,
  },
};

let originalEnv = {};

// 5. Require the service under test
const { runPoliticalVideoIngestion, inferPoliticsScope } = require('../../services/politicalVideoIngestionService');

describe('politicalVideoIngestionService', () => {
  before(() => {
    // Save original env variables
    originalEnv = {
      POLITICAL_VIDEO_ENABLED: process.env.POLITICAL_VIDEO_ENABLED,
      YOUTUBE_API_KEY: process.env.YOUTUBE_API_KEY,
    };
  });

  after(() => {
    // Restore env variables
    for (const key in originalEnv) {
      if (originalEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = originalEnv[key];
      }
    }
    
    // Restore all functions
    prisma.user.findUnique = originalPrisma.user.findUnique;
    prisma.user.create = originalPrisma.user.create;
    prisma.category.findFirst = originalPrisma.category.findFirst;
    prisma.politicalVideo.findFirst = originalPrisma.politicalVideo.findFirst;
    prisma.politicalVideo.upsert = originalPrisma.politicalVideo.upsert;
    prisma.newsPost.findFirst = originalPrisma.newsPost.findFirst;
    prisma.newsPost.create = originalPrisma.newsPost.create;
  });

  beforeEach(() => {
    // Reset env vars to standard test conditions
    process.env.POLITICAL_VIDEO_ENABLED = 'true';
    process.env.YOUTUBE_API_KEY = 'mock-api-key';

    // Reset prisma mocks
    prisma.user.findUnique = async () => ({ id: 'reporter-1', email: 'scraper@newsnow.local' });
    prisma.user.create = async () => ({ id: 'reporter-1', email: 'scraper@newsnow.local' });
    prisma.category.findFirst = async () => ({ id: 'cat-politics', slug: 'politics' });
    prisma.politicalVideo.findFirst = async () => null;
    prisma.newsPost.findFirst = async () => null;
    prisma.newsPost.create = async (args) => ({ id: 'post-123', ...args.data });
    prisma.politicalVideo.upsert = async (args) => ({ id: 'vid-123', ...args.create });

    // Reset default mock implementations
    mockFetchLatestFromChannels = async () => [];
    mockFilterEmbeddableVideos = async (v) => v;
    mockClassifyVideosBatch = async (items) => items.map(i => ({
      ...i,
      category: 'political interview',
      confidence: 0.95,
      method: 'ml',
      accepted: true,
    }));
    mockPreloadPoliticalClassifier = async () => {};
    mockIsMlEnabled = () => true;
    mockEmitFeedUpdated = async () => {};
    mockCreateNewsPost = async (doc) => ({ id: 'post-123', ...doc });
  });

  describe('runPoliticalVideoIngestion', () => {
    it('returns skipped when POLITICAL_VIDEO_ENABLED is false', async () => {
      process.env.POLITICAL_VIDEO_ENABLED = 'false';
      const result = await runPoliticalVideoIngestion();
      assert.equal(result.success, true);
      assert.equal(result.skipped, true);
      assert.match(result.message, /disabled/i);
    });

    it('returns error when YOUTUBE_API_KEY is missing or empty', async () => {
      delete process.env.YOUTUBE_API_KEY;
      const result = await runPoliticalVideoIngestion();
      assert.equal(result.success, false);
      assert.match(result.error, /YOUTUBE_API_KEY/i);
    });

    it('happy path: processes and saves videos matching political keywords', async () => {
      mockFetchLatestFromChannels = async () => [
        {
          videoId: 'vid-kw-accepted',
          title: 'Chief Minister exclusive interview on election preparations',
          description: 'Full video details of parliament session.',
          channelId: 'UC_TEST',
          channelName: 'Test Channel',
          publishedAt: new Date(),
          language: 'en',
        },
        {
          videoId: 'vid-rejected',
          title: 'Unrelated movie trailer video song release',
          description: 'Fun comedy entertainment show.',
          channelId: 'UC_TEST',
          channelName: 'Test Channel',
          publishedAt: new Date(),
          language: 'en',
        }
      ];

      let savedPostDoc = null;
      let savedVideoArgs = null;

      mockCreateNewsPost = async (doc) => {
        savedPostDoc = doc;
        return { id: 'news-post-id' };
      };

      prisma.politicalVideo.upsert = async (args) => {
        savedVideoArgs = args.create;
        return { id: 'political-vid-id' };
      };

      const result = await runPoliticalVideoIngestion();
      assert.equal(result.success, true);
      
      const stats = result.stats;
      assert.equal(stats.fetched, 2);
      assert.equal(stats.keywordAccepted, 1);
      assert.equal(stats.rejected, 1);
      assert.equal(stats.saved, 1);

      assert.ok(savedPostDoc);
      assert.equal(savedPostDoc.title, 'Chief Minister exclusive interview on election preparations');
      assert.equal(savedPostDoc.youtube?.videoId, 'vid-kw-accepted');
      assert.equal(savedPostDoc.videoCategory, 'political interview');
      assert.equal(savedPostDoc.videoClassificationMethod, 'keyword');

      assert.ok(savedVideoArgs);
      assert.equal(savedVideoArgs.videoId, 'vid-kw-accepted');
      assert.equal(savedVideoArgs.category, 'political interview');
      assert.equal(savedVideoArgs.classificationMethod, 'keyword');
    });

    it('happy path with ML: classifies uncertain videos with MiniLM batch', async () => {
      mockFetchLatestFromChannels = async () => [
        {
          videoId: 'vid-ml-accepted',
          title: 'Election day coverage highlights',
          description: 'A brief description.',
          channelId: 'UC_TEST',
          channelName: 'Test Channel',
          publishedAt: new Date(),
          language: 'en',
        }
      ];

      mockClassifyVideosBatch = async (items) => items.map(item => ({
        ...item,
        category: 'political debate',
        confidence: 0.88,
        method: 'ml',
        accepted: true,
      }));

      const result = await runPoliticalVideoIngestion();
      assert.equal(result.success, true);

      const stats = result.stats;
      assert.equal(stats.fetched, 1);
      assert.equal(stats.uncertain, 1);
      assert.equal(stats.mlAccepted, 1);
      assert.equal(stats.saved, 1);
    });

    it('ignores duplicates already existing in DB', async () => {
      mockFetchLatestFromChannels = async () => [
        {
          videoId: 'vid-duplicate',
          title: 'Chief Minister election interview',
          description: 'parliament session',
          channelId: 'UC_TEST',
          channelName: 'Test Channel',
          publishedAt: new Date(),
          language: 'en',
        }
      ];

      prisma.politicalVideo.findFirst = async () => ({ id: 'existing' });

      const result = await runPoliticalVideoIngestion();
      assert.equal(result.success, true);
      assert.equal(result.stats.duplicates, 1);
      assert.equal(result.stats.saved, 0);
    });

    it('falls back to keyword-only logic gracefully when ML preloading or batch fails', async () => {
      mockFetchLatestFromChannels = async () => [
        {
          videoId: 'vid-uncertain-failed-ml',
          title: 'Cabinet meet discussion',
          description: 'details',
          channelId: 'UC_TEST',
          channelName: 'Test Channel',
          publishedAt: new Date(),
          language: 'en',
        }
      ];

      mockClassifyVideosBatch = async () => {
        throw new Error('ML model not loaded');
      };

      const result = await runPoliticalVideoIngestion();
      assert.equal(result.success, true);
      assert.equal(result.stats.mlUnavailable, 'ML model not loaded');
      assert.equal(result.stats.saved, 0);
    });

    it('skips run if locked', async () => {
      let resolveFetch;
      const fetchPromise = new Promise((res) => { resolveFetch = res; });
      mockFetchLatestFromChannels = async () => {
        await fetchPromise;
        return [];
      };

      const firstRun = runPoliticalVideoIngestion();
      const secondRun = runPoliticalVideoIngestion();

      resolveFetch([]);
      
      const [res1, res2] = await Promise.all([firstRun, secondRun]);
      
      if (res1.skipped) {
        assert.equal(res2.success, true);
        assert.equal(res2.skipped, undefined);
      } else {
        assert.equal(res1.success, true);
        assert.equal(res2.success, false);
        assert.equal(res2.skipped, true);
        assert.match(res2.message, /already running/i);
      }
    });
  });

  describe('inferPoliticsScope helper', () => {
    it('correctly classifies scopes based on text matches', () => {
      assert.equal(inferPoliticsScope('Biden Zelenskiy Kremlin summit', ''), 'international');
      assert.equal(inferPoliticsScope('Chandrababu Naidu Amaravati TDP news', ''), 'andhra');
      assert.equal(inferPoliticsScope('KCR KTR Revanth Hyderabad BRS', ''), 'telangana');
      assert.equal(inferPoliticsScope('Kejriwal Delhi Yogi assembly', ''), 'delhi');
      assert.equal(inferPoliticsScope('General national politics budget', ''), 'india');
    });

    it('strips TV channels/social boilerplate from description to avoid scope false positives', () => {
      const description = `
        Subscribe to Sakshi TV: http://youtube.com/sakshitv
        Follow us on Twitter: https://twitter.com/sakshinews
        For Telugu news from Andhra and Telangana: http://sakshi.com
      `;
      const scope = inferPoliticsScope('National parliament debate on financial bill', description);
      assert.equal(scope, 'india');
    });
  });
});
