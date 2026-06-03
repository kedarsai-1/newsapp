/**
 * Referer/Origin hints for hotlinked images and og:image fetches (en/hi/te publishers).
 */
function hostMatchesPublisher(host, domain) {
  const h = String(host || '').toLowerCase();
  const d = String(domain || '').toLowerCase();
  return h === d || h.endsWith(`.${d}`);
}

function getPublisherReferer(pageUrlOrHost) {
  const raw = String(pageUrlOrHost || '').trim();
  if (!raw) return null;

  let host = raw.toLowerCase();
  if (raw.includes('://')) {
    try {
      host = new URL(raw).hostname.toLowerCase();
    } catch {
      return null;
    }
  }

  const rules = [
    ['thgimgs.com', 'https://www.thehindu.com/'],
    ['thehindu.com', 'https://www.thehindu.com/'],
    ['toiimg.com', 'https://timesofindia.indiatimes.com/'],
    ['indiatimes.com', 'https://timesofindia.indiatimes.com/'],
    ['hindustantimes.com', 'https://www.hindustantimes.com/'],
    ['livemint.com', 'https://www.livemint.com/'],
    ['indianexpress.com', 'https://indianexpress.com/'],
    ['moneycontrol.com', 'https://www.moneycontrol.com/'],
    ['indiatoday.in', 'https://www.indiatoday.in/'],
    ['ndtv.com', 'https://www.ndtv.com/'],
    ['abplive.com', 'https://www.abplive.com/'],
    ['amarujala.com', 'https://www.amarujala.com/'],
    ['bhaskar.com', 'https://www.bhaskar.com/'],
    ['jagran.com', 'https://www.jagran.com/'],
    ['prabhatkhabar.com', 'https://www.prabhatkhabar.com/'],
    ['theprint.in', 'https://theprint.in/'],
    ['tv9telugu.com', 'https://www.tv9telugu.com/'],
    ['ntvtelugu.com', 'https://www.ntvtelugu.com/'],
    ['v6velugu.com', 'https://www.v6velugu.com/'],
    ['bbc.co.uk', 'https://www.bbc.com/'],
    ['bbci.co.uk', 'https://www.bbc.com/'],
    ['bbc.com', 'https://www.bbc.com/'],
  ];

  for (const [domain, referer] of rules) {
    if (hostMatchesPublisher(host, domain)) return referer;
  }

  try {
    const parsed = new URL(raw.includes('://') ? raw : `https://${host}/`);
    return `${parsed.protocol}//${parsed.host}/`;
  } catch {
    return null;
  }
}

module.exports = { getPublisherReferer, hostMatchesPublisher };
