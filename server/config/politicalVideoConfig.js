/**
 * Multilingual political video classification — keywords, labels, channels.
 */

const POLITICAL_LABELS = [
  'political interview',
  'political debate',
  'press meet',
];

const NON_POLITICAL_LABELS = ['entertainment', 'sports'];

const ALL_LABELS = [...POLITICAL_LABELS, ...NON_POLITICAL_LABELS];

const POLITICAL_KEYWORDS = {
  en: [
    'minister', 'chief minister', 'cm ', 'mla', 'mp ', 'election', 'parliament',
    'assembly', 'debate', 'interview', 'press meet', 'press conference',
    'bjp', 'congress', 'speech', 'rally', 'cabinet', 'opposition', 'polling',
    'governor', 'president', 'prime minister', 'modi', 'amit shah', 'rahul',
    'ycp', 'tdp', 'trs', 'brs', 'ysrcp', 'party',
  ],
  te: [
    'మంత్రి', 'సీఎం', 'ఎమ్మెల్యే', 'ఎంపీ', 'ఎన్నికలు', 'సభ', 'ఇంటర్వ్యూ',
    'ప్రసంగం', 'పార్లమెంట్', 'అసెంబ్లీ', 'బహస', 'ప్రెస్ మీట్', 'జాతీయ',
    'రాజకీయ', 'మంత్రివర్గం', 'పార్టీ',
    // Additional Telugu political terms for news channels
    'ముఖ్యమంత్రి', 'గవర్నర్', 'ప్రభుత్వం', 'నేత', 'నాయకుడు', 'అధ్యక్షుడు',
    'మోదీ', 'రేవంత్', 'చంద్రబాబు', 'జగన్', 'కేటీఆర్', 'హరీష్',
    'బీజేపీ', 'కాంగ్రెస్', 'టీడీపీ', 'వైసీపీ', 'బీఆర్ఎస్', 'తెలంగాణ',
    'ఆంధ్రప్రదేశ్', 'హైదరాబాద్', 'అమరావతి', 'విజయవాడ',
    'చట్టసభ', 'ఓటు', 'ఎన్నిక', 'పోలింగ్', 'ఫలితాలు', 'విధానం',
    'cmrevanthreddy', 'chandrababu', 'jagan',
  ],
  hi: [
    'मंत्री', 'मुख्यमंत्री', 'विधायक', 'सांसद', 'चुनाव', 'संसद', 'विधानसभा',
    'बहस', 'इंटरव्यू', 'प्रेस कॉन्फ्रेंस', 'भाजपा', 'कांग्रेस', 'भाषण',
    'राजनीति', 'सरकार', 'विरोध',
    // Additional Hindi political terms
    'प्रधानमंत्री', 'राज्यपाल', 'नेता', 'पार्टी', 'मोदी', 'राहुल',
    'अमित शाह', 'योगी', 'केजरीवाल', 'ममता', 'लोकसभा', 'राज्यसभा',
    'दिल्ली', 'उत्तर प्रदेश', 'बिहार', 'महाराष्ट्र', 'राजनेता',
    'मतदान', 'वोट', 'चुनावी', 'घोषणापत्र', 'आरोप',
  ],
};

const BLACKLIST_KEYWORDS = [
  'movie', 'trailer', 'song', 'cricket', 'ipl', 'comedy', 'serial', 'astrology',
  'horoscope', 'rashifal', 'ज्योतिष', 'రాశి', 'teaser', 'lyrics', 'full video song',
  'web series', 'ott', 'box office', 'match', 'wicket',
  // Note: 'highlights' removed — it's used in Telugu/Hindi political news (e.g. "press meet highlights")
];

/** Label prototypes for MiniLM cosine classification (multilingual). */
const LABEL_PROTOTYPES = {
  'political interview': [
    'political interview with minister',
    'exclusive interview election leader',
    'మంత్రి ఇంటర్వ్యూ రాజకీయ',
    'मंत्री इंटरव्यू चुनाव',
  ],
  'political debate': [
    'political debate assembly election',
    'party leaders debate parliament',
    'రాజకీయ బహస ఎన్నికలు',
    'राजनीतिक बहस चुनाव संसद',
  ],
  'press meet': [
    'press conference chief minister',
    'press meet political party announcement',
    'ప్రెస్ మీట్ మంత్రి',
    'प्रेस कॉन्फ्रेंस मंत्री',
  ],
  entertainment: [
    'movie trailer teaser release',
    'film song promo celebrity',
    'సినిమా ట్రైలర్',
    'फिल्म ट्रेलर गाना',
  ],
  sports: [
    'cricket match highlights ipl',
    'football score sports news',
    'క్రికెట్ మ్యాచ్',
    'क्रिकेट मैच आईपीएल',
  ],
};

/** Strong keyword → default label hints */
const KEYWORD_LABEL_HINTS = [
  { pattern: /interview|ఇంటర్వ్యూ|इंटरव्यू/i, label: 'political interview' },
  { pattern: /debate|బహస|बहस/i, label: 'political debate' },
  { pattern: /press meet|press conference|ప్రెస్|प्रेस कॉन्फ/i, label: 'press meet' },
];

/** Fallback when no POLITICAL_YOUTUBE_CHANNEL_IDS_* env vars are set. */
const defaultPoliticalChannels = [
  { channelId: 'UCZ9m4KOh8Ei60428xeGYDCQ', language: 'te', name: 'Telugu Political 1' },
  { channelId: 'UC_2irx_BQR7RsBKmUV9fePQ', language: 'te', name: 'Telugu Political 2' },
  { channelId: 'UCwqusr8YDwM-3mEYTDeJHzw', language: 'en', name: 'English Political 1' },
  { channelId: 'UCZFMm1mMw0F81Z37aaEzTUA', language: 'en', name: 'English Political 2' },
  { channelId: 'UCt4t-jeY85JegMlZ-E5UWtA', language: 'hi', name: 'Hindi Political 1' },
  { channelId: 'UC7wXt18f2iA3EDXeqAVuKng', language: 'hi', name: 'Hindi Political 2' },
];

function channelsFromCommaEnv(envKey, language) {
  const raw = process.env[envKey]?.trim();
  if (!raw) return [];
  return raw
    .split(',')
    .map((id) => id.trim())
    .filter((id) => id.length > 0)
    .map((channelId) => ({
      channelId,
      language,
      name: channelId,
    }));
}

function parseChannelsFromEnv() {
  const raw = process.env.POLITICAL_YOUTUBE_CHANNELS_JSON?.trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return null;
    return parsed
      .filter((c) => c?.channelId)
      .map((c) => ({
        channelId: String(c.channelId).trim(),
        language: String(c.language || 'en').toLowerCase(),
        name: String(c.name || c.channelId).trim(),
      }));
  } catch {
    return null;
  }
}

function getPoliticalYoutubeChannels() {
  const fromJson = parseChannelsFromEnv();
  if (fromJson?.length) return fromJson;

  const te = channelsFromCommaEnv('POLITICAL_YOUTUBE_CHANNEL_IDS_TE', 'te');
  const hi = channelsFromCommaEnv('POLITICAL_YOUTUBE_CHANNEL_IDS_HI', 'hi');
  const en = channelsFromCommaEnv('POLITICAL_YOUTUBE_CHANNEL_IDS_EN', 'en');

  if (te.length || hi.length || en.length) {
    const pick = (lang, fromEnv) =>
      fromEnv.length
        ? fromEnv
        : defaultPoliticalChannels.filter((c) => c.language === lang);
    return [...pick('te', te), ...pick('hi', hi), ...pick('en', en)];
  }

  return defaultPoliticalChannels;
}

module.exports = {
  POLITICAL_LABELS,
  NON_POLITICAL_LABELS,
  ALL_LABELS,
  POLITICAL_KEYWORDS,
  BLACKLIST_KEYWORDS,
  LABEL_PROTOTYPES,
  KEYWORD_LABEL_HINTS,
  getPoliticalYoutubeChannels,
};
