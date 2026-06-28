const test = require('node:test');
const assert = require('node:assert/strict');

const { publisherKeyFromName } = require('../../utils/publisherKey');
const { buildPublishersOrFilter } = require('../../utils/publisherFeedFilter');

test('publisherKeyFromName normalizes ingest labels', () => {
  assert.equal(publisherKeyFromName('RSS · Sakshi'), 'sakshi');
  assert.ok(publisherKeyFromName('సాక్షి').length > 0);
});

test('buildPublishersOrFilter caps names and builds OR clause', () => {
  const clause = buildPublishersOrFilter('Sakshi,The Hindu');
  assert.ok(clause);
  assert.equal(clause.OR.length, 2);
});
