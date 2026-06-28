const test = require('node:test');
const assert = require('node:assert/strict');

const {
  publisherMatchClause,
  buildPublishersOrFilter,
} = require('../../utils/publisherFeedFilter');

test('publisherMatchClause uses equals for short names', () => {
  const clause = publisherMatchClause('ABP');
  assert.deepEqual(clause, { sourceName: { equals: 'ABP', mode: 'insensitive' } });
});

test('publisherMatchClause uses contains for longer names', () => {
  const clause = publisherMatchClause('The Hindu');
  assert.deepEqual(clause, {
    sourceName: { contains: 'The Hindu', mode: 'insensitive' },
  });
});

test('buildPublishersOrFilter ignores empty values', () => {
  assert.equal(buildPublishersOrFilter(' , '), null);
});
