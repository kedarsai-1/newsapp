const EMAIL_RE = /^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$/;
/** Allows optional +, spaces, hyphens, parentheses; digit count validated separately. */
const PHONE_FORMAT_RE = /^\+?[\d\s\-()]+$/;
const MIN_PHONE_DIGITS = 10;
const MAX_PHONE_DIGITS = 15;
const PASSWORD_RE = /^(?=.*[A-Za-z])(?=.*\d).{8,}$/;

function countPhoneDigits(value) {
  return (String(value).match(/\d/g) || []).length;
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function validateEmail(email, { required = true } = {}) {
  const normalized = normalizeEmail(email);
  if (!normalized) {
    if (required) return { ok: false, message: 'Email is required.' };
    return { ok: true, value: null };
  }
  if (!EMAIL_RE.test(normalized)) {
    return { ok: false, message: 'Enter a valid email address.' };
  }
  return { ok: true, value: normalized };
}

function validatePassword(password, { required = true } = {}) {
  const value = String(password || '');
  if (!value) {
    if (required) return { ok: false, message: 'Password is required.' };
    return { ok: true, value: null };
  }
  if (!PASSWORD_RE.test(value)) {
    return {
      ok: false,
      message: 'Password must be at least 8 characters and include a letter and a number.',
    };
  }
  return { ok: true, value };
}

function validateName(name, { required = true } = {}) {
  const value = String(name || '').trim();
  if (!value) {
    if (required) return { ok: false, message: 'Name is required.' };
    return { ok: true, value: null };
  }
  if (value.length < 2 || value.length > 100) {
    return { ok: false, message: 'Name must be between 2 and 100 characters.' };
  }
  return { ok: true, value };
}

function validatePhone(phone) {
  const value = String(phone || '').trim();
  if (!value) return { ok: true, value: null };
  if (!PHONE_FORMAT_RE.test(value)) {
    return { ok: false, message: 'Enter a valid phone number.' };
  }
  const digits = countPhoneDigits(value);
  if (digits < MIN_PHONE_DIGITS || digits > MAX_PHONE_DIGITS) {
    return {
      ok: false,
      message: 'Enter a valid phone number (10–15 digits).',
    };
  }
  return { ok: true, value };
}

/** Maps admin → user; allows only user | reporter for self-registration. */
function resolveRegistrationRole(role) {
  if (role === 'admin') return 'user';
  if (role === 'reporter') return 'reporter';
  return 'user';
}

function validateRegisterPayload({ name, email, password, role, phone }) {
  const nameResult = validateName(name);
  if (!nameResult.ok) return nameResult;

  const assignedRole = resolveRegistrationRole(role);

  const emailResult = validateEmail(email, { required: assignedRole === 'reporter' });
  if (!emailResult.ok) return emailResult;

  if (assignedRole === 'reporter' && !emailResult.value) {
    return { ok: false, message: 'Email is required for reporter accounts.' };
  }

  const passwordResult = validatePassword(password);
  if (!passwordResult.ok) return passwordResult;

  const phoneResult = validatePhone(phone);
  if (!phoneResult.ok) return phoneResult;

  if (assignedRole === 'reporter' && role === 'reporter' && !emailResult.value) {
    return { ok: false, message: 'Reporter accounts must register with email and password.' };
  }

  return {
    ok: true,
    data: {
      name: nameResult.value,
      email: emailResult.value,
      password: passwordResult.value,
      phone: phoneResult.value,
      role: assignedRole,
    },
  };
}

function validateOtpRegisterPayload({ name, email, phone, password, role }) {
  const assignedRole = resolveRegistrationRole(role);

  if (assignedRole === 'reporter') {
    return {
      ok: false,
      message: 'Reporter accounts must register with email and password (not OTP-only).',
    };
  }

  const nameResult = validateName(name);
  if (!nameResult.ok) return nameResult;

  const emailResult = validateEmail(email, { required: false });
  if (!emailResult.ok) return emailResult;

  const phoneResult = validatePhone(phone);
  if (!phoneResult.ok) return phoneResult;

  if (!emailResult.value && !phoneResult.value) {
    return { ok: false, message: 'Email or phone is required.' };
  }

  const passwordResult = validatePassword(password);
  if (!passwordResult.ok) return passwordResult;

  return {
    ok: true,
    data: {
      name: nameResult.value,
      email: emailResult.value,
      phone: phoneResult.value,
      password: passwordResult.value,
      role: assignedRole,
    },
  };
}

module.exports = {
  EMAIL_RE,
  PHONE_FORMAT_RE,
  MIN_PHONE_DIGITS,
  MAX_PHONE_DIGITS,
  countPhoneDigits,
  PASSWORD_RE,
  normalizeEmail,
  validateEmail,
  validatePassword,
  validateName,
  validatePhone,
  resolveRegistrationRole,
  validateRegisterPayload,
  validateOtpRegisterPayload,
};
