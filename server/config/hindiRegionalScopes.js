/**
 * Hindi belt regional scopes — mirrors AP/TG `andhra` / `telangana` for Local + Politics tabs.
 */
const HINDI_REGIONAL_SCOPES = {
  north: {
    label: 'North',
    state: null,
    keywords: [
      'uttarakhand', 'dehradun', 'haridwar', 'nainital', 'rishikesh',
      'himachal pradesh', 'shimla', 'kangra', 'kullu', 'solan',
      'madhya pradesh', 'bhopal', 'indore', 'gwalior', 'jabalpur',
      'jammu and kashmir', 'srinagar', 'jammu', 'udhampur',
      'chhattisgarh', 'raipur', 'bilaspur',
      'उत्तराखंड', 'हिमाचल', 'मध्य प्रदेश', 'जम्मू', 'कश्मीर', 'छत्तीसगढ़',
    ],
  },
  up: {
    label: 'UP',
    state: 'Uttar Pradesh',
    keywords: [
      'uttar pradesh', 'lucknow', 'kanpur', 'varanasi', 'prayagraj', 'allahabad',
      'agra', 'meerut', 'noida', 'ghaziabad', 'gorakhpur', 'ayodhya', 'bareilly',
      'yogi adityanath', 'akhilesh yadav',
      'उत्तर प्रदेश', 'यूपी', 'लखनऊ', 'कानपुर', 'वाराणसी', 'प्रयागराज', 'आगरा', 'मेरठ', 'नोएडा',
    ],
  },
  bihar: {
    label: 'Bihar',
    state: 'Bihar',
    keywords: [
      'bihar', 'patna', 'gaya', 'muzaffarpur', 'bhagalpur', 'nitish kumar', 'tejashwi',
      'बिहार', 'पटना', 'गया', 'मुजफ्फरपुर',
    ],
  },
  rajasthan: {
    label: 'Rajasthan',
    state: 'Rajasthan',
    keywords: [
      'rajasthan', 'jaipur', 'jodhpur', 'udaipur', 'kota', 'ajmer', 'bikaner',
      'राजस्थान', 'जयपुर', 'जोधपुर', 'उदयपुर',
    ],
  },
  punjab: {
    label: 'Punjab',
    state: 'Punjab',
    keywords: [
      'punjab', 'chandigarh', 'amritsar', 'ludhiana', 'jalandhar', 'patiala',
      'पंजाब', 'चंडीगढ़', 'अमृतसर', 'लुधियाना',
    ],
  },
  haryana: {
    label: 'Haryana',
    state: 'Haryana',
    keywords: [
      'haryana', 'gurugram', 'gurgaon', 'faridabad', 'panipat', 'hisar', 'rohtak',
      'हरियाणा', 'गुरुग्राम', 'गुड़गांव', 'फरीदाबाद',
    ],
  },
  delhi: {
    label: 'Delhi',
    state: 'Delhi',
    keywords: [
      'delhi', 'new delhi', 'nct delhi', 'kejriwal', 'दिल्ली', 'नई दिल्ली',
    ],
  },
};

const HINDI_SCOPE_KEYS = Object.keys(HINDI_REGIONAL_SCOPES);

/** Legacy `north` + per-state scopes used in politicsScope column. */
const HINDI_POLITICS_SCOPE_VALUES = new Set([
  'north', 'states', 'delhi', ...HINDI_SCOPE_KEYS,
]);

function politicsScopeToState(scope) {
  const ps = String(scope || '').toLowerCase().trim();
  if (ps === 'delhi') return HINDI_REGIONAL_SCOPES.delhi.state;
  return HINDI_REGIONAL_SCOPES[ps]?.state || null;
}

function inferHindiPoliticsScope(title = '', description = '') {
  const text = `${title || ''} ${description || ''}`.toLowerCase();
  for (const [scope, meta] of Object.entries(HINDI_REGIONAL_SCOPES)) {
    if (meta.keywords.some((kw) => text.includes(kw.toLowerCase()))) {
      return scope;
    }
  }
  return null;
}

/** Prisma OR branch for a Hindi regional scope (title text + stored politicsScope). */
function hindiScopeTitleOrClause(scope) {
  const meta = HINDI_REGIONAL_SCOPES[scope];
  if (!meta) return [];
  const clauses = meta.keywords.slice(0, 12).map((kw) => ({
    title: { contains: kw, mode: 'insensitive' },
  }));
  if (meta.state) {
    clauses.push({ locationState: { equals: meta.state, mode: 'insensitive' } });
  }
  return clauses;
}

module.exports = {
  HINDI_REGIONAL_SCOPES,
  HINDI_SCOPE_KEYS,
  HINDI_POLITICS_SCOPE_VALUES,
  politicsScopeToState,
  inferHindiPoliticsScope,
  hindiScopeTitleOrClause,
};
