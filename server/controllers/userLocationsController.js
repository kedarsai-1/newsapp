const { prisma } = require('../config/prisma');

const MAX_SLOTS = 2;

function serializeSavedLocation(row) {
  if (!row) return null;
  return {
    slot: row.slot,
    label: row.label,
    city: row.city,
    district: row.district,
    mandal: row.mandal,
    state: row.state,
    latitude: row.latitude,
    longitude: row.longitude,
  };
}

function normalizeSlot(slot) {
  const n = Number(slot);
  if (!Number.isInteger(n) || n < 0 || n >= MAX_SLOTS) return null;
  return n;
}

function validateLocationPayload(body = {}) {
  const label = String(body.label || 'Home').trim().slice(0, 40) || 'Home';
  const city = body.city ? String(body.city).trim().slice(0, 120) : null;
  const district = body.district ? String(body.district).trim().slice(0, 120) : null;
  const mandal = body.mandal ? String(body.mandal).trim().slice(0, 120) : null;
  const state = body.state ? String(body.state).trim().slice(0, 80) : null;
  const latitude = body.latitude != null ? Number(body.latitude) : null;
  const longitude = body.longitude != null ? Number(body.longitude) : null;
  if (!city && !district && !mandal) {
    return { ok: false, message: 'At least one of city, district, or mandal is required.' };
  }
  return {
    ok: true,
    data: {
      label,
      city,
      district,
      mandal,
      state,
      latitude: Number.isFinite(latitude) ? latitude : null,
      longitude: Number.isFinite(longitude) ? longitude : null,
    },
  };
}

async function getSavedLocations(req, res) {
  try {
    const rows = await prisma.userSavedLocation.findMany({
      where: { userId: req.user.id },
      orderBy: { slot: 'asc' },
    });
    const locations = Array.from({ length: MAX_SLOTS }, (_, slot) => {
      const row = rows.find((r) => r.slot === slot);
      return serializeSavedLocation(row);
    });
    return res.json({ success: true, locations, maxSlots: MAX_SLOTS });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
}

async function upsertSavedLocation(req, res) {
  try {
    const slot = normalizeSlot(req.params.slot ?? req.body?.slot);
    if (slot == null) {
      return res.status(400).json({ success: false, message: `Slot must be 0 or 1.` });
    }
    const validation = validateLocationPayload(req.body);
    if (!validation.ok) {
      return res.status(400).json({ success: false, message: validation.message });
    }

    const row = await prisma.userSavedLocation.upsert({
      where: { userId_slot: { userId: req.user.id, slot } },
      create: { userId: req.user.id, slot, ...validation.data },
      update: validation.data,
    });
    return res.json({ success: true, location: serializeSavedLocation(row) });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
}

async function deleteSavedLocation(req, res) {
  try {
    const slot = normalizeSlot(req.params.slot);
    if (slot == null) {
      return res.status(400).json({ success: false, message: `Slot must be 0 or 1.` });
    }
    await prisma.userSavedLocation.deleteMany({
      where: { userId: req.user.id, slot },
    });
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
}

module.exports = {
  getSavedLocations,
  upsertSavedLocation,
  deleteSavedLocation,
  MAX_SLOTS,
};
