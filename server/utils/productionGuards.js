const WEAK_JWT_SECRETS = new Set([
  'change_me_in_production',
  'secret',
  'jwt_secret',
  'your_jwt_secret',
]);

const DEFAULT_ADMIN_PASSWORD = 'Admin@123';

function assertProductionSecrets() {
  if (process.env.NODE_ENV !== 'production') return;

  const jwt = String(process.env.JWT_SECRET || '').trim();
  if (!jwt || jwt.length < 32 || WEAK_JWT_SECRETS.has(jwt.toLowerCase())) {
    console.error(
      '[startup] FATAL: Set JWT_SECRET to a random string of at least 32 characters in production.',
    );
    process.exit(1);
  }
}

function resolveAdminSeedPassword() {
  const fromEnv = String(process.env.ADMIN_SEED_PASSWORD || '').trim();
  if (fromEnv) return fromEnv;

  if (process.env.NODE_ENV === 'production') {
    console.error(
      '[startup] FATAL: Set ADMIN_SEED_PASSWORD when provisioning a fresh production database.',
    );
    process.exit(1);
  }

  return DEFAULT_ADMIN_PASSWORD;
}

function isWeakAdminPassword(password) {
  const plain = String(password || '').trim();
  return !plain || plain === DEFAULT_ADMIN_PASSWORD;
}

module.exports = {
  assertProductionSecrets,
  resolveAdminSeedPassword,
  isWeakAdminPassword,
  DEFAULT_ADMIN_PASSWORD,
};
