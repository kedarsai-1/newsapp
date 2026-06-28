const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { getPoliticalYoutubeChannels } = require('../../config/politicalVideoConfig');

describe('politicalVideoConfig', () => {
  let originalEnv = {};

  before(() => {
    // Save original env variables we will modify
    originalEnv = {
      POLITICAL_YOUTUBE_CHANNELS_JSON: process.env.POLITICAL_YOUTUBE_CHANNELS_JSON,
      POLITICAL_YOUTUBE_CHANNEL_IDS_TE: process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_TE,
      POLITICAL_YOUTUBE_CHANNEL_IDS_HI: process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_HI,
      POLITICAL_YOUTUBE_CHANNEL_IDS_EN: process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_EN,
    };
  });

  after(() => {
    // Restore original env variables
    for (const key in originalEnv) {
      if (originalEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = originalEnv[key];
      }
    }
  });

  it('getPoliticalYoutubeChannels returns default channels when no env is set', () => {
    delete process.env.POLITICAL_YOUTUBE_CHANNELS_JSON;
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_TE;
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_HI;
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_EN;

    const channels = getPoliticalYoutubeChannels();
    assert.ok(channels.length > 0);
    assert.equal(channels[0].language, 'te');
  });

  it('getPoliticalYoutubeChannels parses valid JSON channels from env', () => {
    process.env.POLITICAL_YOUTUBE_CHANNELS_JSON = JSON.stringify([
      { channelId: 'UC123', language: 'te', name: 'Custom Telugu Channel' },
      { channelId: 'UC456', language: 'hi', name: 'Custom Hindi Channel' }
    ]);

    const channels = getPoliticalYoutubeChannels();
    assert.equal(channels.length, 2);
    assert.deepEqual(channels[0], { channelId: 'UC123', language: 'te', name: 'Custom Telugu Channel' });
    assert.deepEqual(channels[1], { channelId: 'UC456', language: 'hi', name: 'Custom Hindi Channel' });
  });

  it('getPoliticalYoutubeChannels falls back when JSON is invalid', () => {
    process.env.POLITICAL_YOUTUBE_CHANNELS_JSON = 'invalid-json';
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_TE;
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_HI;
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_EN;

    const channels = getPoliticalYoutubeChannels();
    assert.ok(channels.length > 0);
    // Should fallback to default list
    assert.equal(channels.some(c => c.channelId === 'UCZ9m4KOh8Ei60428xeGYDCQ'), true);
  });

  it('getPoliticalYoutubeChannels parses comma-separated lists from env', () => {
    delete process.env.POLITICAL_YOUTUBE_CHANNELS_JSON;
    process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_TE = 'UC_TE1, UC_TE2 ';
    process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_HI = ' UC_HI1 ';
    delete process.env.POLITICAL_YOUTUBE_CHANNEL_IDS_EN;

    const channels = getPoliticalYoutubeChannels();
    const targetIds = channels.map(c => c.channelId);
    assert.ok(targetIds.includes('UC_TE1'));
    assert.ok(targetIds.includes('UC_TE2'));
    assert.ok(targetIds.includes('UC_HI1'));
    // En should fallback to default English channels since no EN channels were provided
    assert.ok(targetIds.includes('UCwqusr8YDwM-3mEYTDeJHzw')); // English Political 1
  });
});
