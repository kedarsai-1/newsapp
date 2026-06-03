const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { decodeHtmlEntities } = require('../../utils/decodeHtmlEntities');

describe('decodeHtmlEntities', () => {
  it('decodes numeric and named entities', () => {
    const raw = '&#039;Peddi&#039; &lsquo;test&rsquo; &amp; &zwnj;';
    assert.equal(decodeHtmlEntities(raw), "'Peddi' ‘test’ &");
  });

  it('removes caption of image placeholder', () => {
    const raw = 'Telugu text Caption of Image. more story';
    assert.match(decodeHtmlEntities(raw), /Telugu text more story/);
    assert.doesNotMatch(decodeHtmlEntities(raw), /Caption of Image/i);
  });

  it('strips disallowed C0/C1 control codepoints from numeric entities', () => {
    assert.equal(decodeHtmlEntities('a&#1;b'), 'ab');
    assert.equal(decodeHtmlEntities('a&#x1F;b'), 'ab');
    assert.equal(decodeHtmlEntities('a&#127;b'), 'ab');
    // Tab/LF/CR are allowed through decode, then normalized to spaces in output
    assert.equal(decodeHtmlEntities('a&#9;b'), 'a b');
    assert.equal(decodeHtmlEntities('a&#10;b'), 'a b');
    assert.equal(decodeHtmlEntities('a&#13;b'), 'a b');
  });
});
