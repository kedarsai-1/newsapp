const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildShareText,
  generateShareCode,
  getShareWebBaseUrl,
} = require('../../utils/shareLinkService');

test('generateShareCode returns alphanumeric string', () => {
  const code = generateShareCode();
  assert.match(code, /^[0-9A-Za-z]{6}$/);
});

test('buildShareText matches Dailyhunt-style layout', () => {
  const text = buildShareText({
    title: 'సువేందు స్కెచ్‌కు ఆర్‌ఎస్‌ఎస్‌ బ్రేక్‌!',
    shareUrl: 'https://example.com/n/14FXL6',
    sourceName: 'సాక్షి',
    appName: 'NewsNow',
  });
  assert.equal(
    text,
    'సువేందు స్కెచ్‌కు ఆర్‌ఎస్‌ఎస్‌ బ్రేక్‌!\nhttps://example.com/n/14FXL6\n\nBy సాక్షి via NewsNow.',
  );
});

test('getShareWebBaseUrl prefers SHARE_WEB_BASE_URL', () => {
  const prev = process.env.SHARE_WEB_BASE_URL;
  process.env.SHARE_WEB_BASE_URL = 'https://news.example.com/';
  assert.equal(getShareWebBaseUrl(), 'https://news.example.com');
  if (prev == null) delete process.env.SHARE_WEB_BASE_URL;
  else process.env.SHARE_WEB_BASE_URL = prev;
});
