const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const { stripNewsWireTruncationMarkers } = require('../../utils/stripNewsWireTruncation');

describe('stripNewsWireTruncation', () => {
  it('removes [+NNN chars] markers', () => {
    const input = 'Story excerpt ends here [+1909 chars]';
    assert.equal(stripNewsWireTruncationMarkers(input), 'Story excerpt ends here');
  });

  it('removes [NNN chars] markers', () => {
    const input = 'Another excerpt [512 chars]';
    assert.equal(stripNewsWireTruncationMarkers(input), 'Another excerpt');
  });

  it('returns null for null input', () => {
    assert.equal(stripNewsWireTruncationMarkers(null), null);
  });
});
