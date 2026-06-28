const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildBriefBody,
  requirePublicShareBaseUrl,
} = require('../../services/morningBriefService');

test('buildBriefBody fits multiple headlines and one short link', () => {
  const posts = [
    { id: 'a', title: 'Headline one', shareCode: 'Ab12Cd', isBreaking: true },
    { id: 'b', title: 'Headline two', shareCode: 'Xy34Zw', isBreaking: false },
    { id: 'c', title: 'Headline three', shareCode: 'Mn56Op', isBreaking: false },
  ];
  const body = buildBriefBody(posts, 'http://147.93.169.3');
  assert.ok(body.length <= 240);
  assert.match(body, /http:\/\/147\.93\.169\.3\/n\/Ab12Cd/);
  assert.match(body, /Headline one/);
  assert.match(body, /\+2 more/);
});

test('requirePublicShareBaseUrl rejects missing and localhost', () => {
  const prev = process.env.SHARE_WEB_BASE_URL;
  delete process.env.SHARE_WEB_BASE_URL;
  assert.throws(() => requirePublicShareBaseUrl(), /SHARE_WEB_BASE_URL must be set/);
  process.env.SHARE_WEB_BASE_URL = 'http://127.0.0.1:5001';
  assert.throws(() => requirePublicShareBaseUrl(), /public URL/);
  process.env.SHARE_WEB_BASE_URL = 'http://147.93.169.3';
  assert.equal(requirePublicShareBaseUrl(), 'http://147.93.169.3');
  if (prev === undefined) delete process.env.SHARE_WEB_BASE_URL;
  else process.env.SHARE_WEB_BASE_URL = prev;
});
