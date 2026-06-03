const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  isPoliticalNoise,
  isTeluguPoliticalStory,
  isHindiPoliticalStory,
  acceptPoliticsRssItem,
  isStrictPoliticalStory,
} = require('../../utils/politicalStoryFilter');

describe('politicalStoryFilter', () => {
  it('rejects Telugu cinema stories', () => {
    assert.equal(
      isTeluguPoliticalStory({
        title: 'Peddi trailer: Ram Charan pan-India rural sports drama',
        body: 'Global Star Ram Charan movie BGM ready',
      }),
      false,
    );
    assert.equal(isPoliticalNoise({
      title: 'Peddi trailer: Ram Charan pan-India rural sports drama',
    }, 'te'), true);
  });

  it('accepts Telugu political stories with a single signal', () => {
    assert.equal(
      isTeluguPoliticalStory({
        title: 'మంత్రి ప్రెస్ మీట్.. కేంద్ర నిర్ణయం',
        body: 'హైదరాబాద్',
      }),
      true,
    );
    assert.equal(
      acceptPoliticsRssItem({
        title: 'మంత్రి ప్రెస్ మీట్.. కేంద్ర నిర్ణయం',
      }, 'te', { fromPoliticsFeed: true }),
      true,
    );
  });

  it('accepts Telugu political stories with multiple signals', () => {
    assert.equal(
      isTeluguPoliticalStory({
        title: 'తెలంగాణ ఎన్నికల్లో YSRCP-TDP పోటీ',
        body: 'హైదరాబాద్‌లో మంత్రి ప్రెస్ మీట్',
      }),
      true,
    );
  });

  it('accepts Hindi national politics with one signal', () => {
    assert.equal(
      isHindiPoliticalStory({
        title: 'केंद्र सरकार का नया फैसला',
        body: 'संसद में चर्चा',
      }),
      true,
    );
  });

  it('rejects Hindi cinema stories', () => {
    assert.equal(
      isHindiPoliticalStory({
        title: 'बॉलीवुड फिल्म ट्रेलर रिलीज',
        body: 'सेलिब्रिटी wedding',
      }),
      false,
    );
  });

  it('strict mode needs two signals', () => {
    assert.equal(
      isStrictPoliticalStory({ title: 'मंत्री ने कहा' }, 'hi'),
      false,
    );
    assert.equal(
      isStrictPoliticalStory({
        title: 'मोदी और शाह की बैठक',
        body: 'संसद सत्र',
      }, 'hi'),
      true,
    );
  });
});
