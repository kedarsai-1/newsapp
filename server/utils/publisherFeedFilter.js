/** Build Prisma OR-clause for matching posts by publisher display names. */
function publisherMatchClause(publisherName) {
  const name = String(publisherName || '').trim();
  if (!name) return null;
  if (name.length >= 6) {
    return { sourceName: { contains: name, mode: 'insensitive' } };
  }
  return { sourceName: { equals: name, mode: 'insensitive' } };
}

function buildPublishersOrFilter(rawNames) {
  const names = [...new Set(
    String(rawNames || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  )].slice(0, 20);
  if (!names.length) return null;
  const clauses = names.map(publisherMatchClause).filter(Boolean);
  if (!clauses.length) return null;
  return { OR: clauses };
}

module.exports = {
  publisherMatchClause,
  buildPublishersOrFilter,
};
