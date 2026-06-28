const { cleanIngestSourceLabel, publisherNameFromPost } = require('./serializers');

/** Stable key for follow/filter (ASCII slug + preserves Indic via unicode). */
function publisherKeyFromName(raw) {
  const cleaned = cleanIngestSourceLabel(raw) || String(raw || '').trim();
  if (!cleaned) return '';
  return cleaned
    .toLowerCase()
    .replace(/[^a-z0-9\u0900-\u097F\u0C00-\u0C7F]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 120);
}

function publisherIdentityFromPost(post) {
  const name = publisherNameFromPost(post);
  const key = publisherKeyFromName(name);
  return { publisherKey: key, publisherName: name };
}

module.exports = {
  publisherKeyFromName,
  publisherNameFromPost,
  publisherIdentityFromPost,
};
