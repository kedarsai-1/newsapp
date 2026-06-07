const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function validateCategoryInput({ name, slug }) {
  const trimmedName = String(name || '').trim();
  const trimmedSlug = String(slug || '').trim().toLowerCase();
  if (!trimmedName) {
    return { error: 'Category name is required.' };
  }
  if (trimmedName.length > 80) {
    return { error: 'Category name is too long (max 80 characters).' };
  }
  if (!trimmedSlug) {
    return { error: 'Category slug is required.' };
  }
  if (!SLUG_RE.test(trimmedSlug)) {
    return { error: 'Category slug must be lowercase letters, numbers, and hyphens only.' };
  }
  return {
    data: {
      name: trimmedName,
      slug: trimmedSlug,
    },
  };
}

module.exports = { validateCategoryInput, SLUG_RE };
