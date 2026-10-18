const crypto = require('crypto');
const db = require('../../config/database');
const env = require('../../config/env');
const apiError = require('../../shared/utils/apiError.util');
const repo = require('./itineraries.repository');

const asIso = value => value instanceof Date ? value.toISOString() : value;

const asTime = value => typeof value === 'string' ? value.slice(0, 5) : value;

const formatItem = row => ({
  id: row.id,
  itineraryId: row.itinerary_id,
  placeId: row.place_id || null,
  customName: row.custom_name,
  customAddress: row.custom_address || null,
  category: row.category,
  locationSource: row.location_source || 'MANUAL',
  externalProvider: row.external_provider || null,
  externalPlaceId: row.external_place_id || null,
  latitude: row.latitude != null ? Number(row.latitude) : null,
  longitude: row.longitude != null ? Number(row.longitude) : null,
  startTime: asTime(row.start_time),
  endTime: asTime(row.end_time),
  note: row.note || null,
  estimatedCost: Number(row.estimated_cost || 0),
  expenseId: row.expense_id || null,
  actualAmount: row.actual_amount == null ? null : Number(row.actual_amount),
  isCompleted: Boolean(row.is_completed),
  createdAt: asIso(row.created_at),
  version: String(row.row_version),
});

const formatDay = (row, items = []) => ({
  id: row.id || null,
  tripId: row.trip_id || row.tripId,
  dayNumber: Number(row.day_number ?? row.dayNumber),
  title: row.title,
  tripDate: row.trip_date || row.tripDate,
  materialized: Boolean(row.id),
  ...(row.id ? { createdAt: asIso(row.created_at), version: String(row.row_version) } : {}),
  items: items.map(formatItem),
});

const formatTripHeader = row => ({
  id: row.id,
  name: row.name,
  startDate: row.start_date,
  endDate: row.end_date,
  status: row.status,
  memberRole: row.member_role,
});

const formatPublicSummary = row => ({
  sourceTripId: row.id,
  name: row.name,
  destination: row.destination,
  durationDays: Number(row.duration_days),
  coverImageUrl: row.cover_image_url || null,
  description: row.description || null,
  averageRating: Number(row.average_rating || 0),
  reviewCount: Number(row.review_count || 0),
  cloneCount: Number(row.clone_count || 0),
  updatedAt: asIso(row.updated_at),
});

const formatPublicItem = row => ({
  customName: row.custom_name,
  customAddress: row.custom_address || null,
  category: row.category,
  startTime: asTime(row.start_time),
  endTime: asTime(row.end_time),
  note: row.note || null,
});

const formatPublicDay = (row, items = []) => ({
  dayNumber: Number(row.day_number),
  title: row.title,
  items: items.map(formatPublicItem),
});

const sameVersion = (actual, expected) => String(actual) === String(expected);

const asDateOnly = value => {
  if (value instanceof Date) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  const match = String(value).match(/^\d{4}-\d{2}-\d{2}/);
  if (!match) throw apiError(500, 'Dữ liệu ngày chuyến đi không hợp lệ');
  return match[0];
};

const datePlus = (date, days) => {
  const [year, month, day] = asDateOnly(date).split('-').map(Number);
  const value = new Date(Date.UTC(year, month - 1, day));
  value.setUTCDate(value.getUTCDate() + Number(days));
  return value.toISOString().slice(0, 10);
};

const requireMember = async (client, tripId, userId, leaderOnly = false, lock = false) => {
  const membership = await repo.getMembership(client, tripId, userId, lock);
  if (!membership || membership.membership_status !== 'ACTIVE') {
    throw apiError(404, 'Không tìm thấy lịch trình');
  }
  if (leaderOnly && membership.role !== 'LEADER') {
    throw apiError(403, 'Chỉ trưởng nhóm được chỉnh sửa lịch trình');
  }
  return membership;
};

const ensureEditable = trip => {
  if (!['UPCOMING', 'ONGOING'].includes(trip.status || trip.trip_status)) {
    throw apiError(409, 'Chuyến đi không còn cho phép chỉnh sửa');
  }
};

/**
 * Tính lại start_time/end_time tuần tự cho danh sách hoạt động đã sắp xếp lại.
 * Giữ nguyên duration (khoảng thời gian) của từng item, xếp nối tiếp nhau
 * bắt đầu từ start_time của item đầu tiên trong thứ tự mới.
 * @param {Array} orderedItems - danh sách item theo thứ tự mới (từ DB row)
 * @returns {Array<{id, startTime, endTime}>} chỉ trả về item có thay đổi
 */
const recalculateSequentialTimes = orderedItems => {
  if (!orderedItems.length) return [];
  const firstStart = asTime(orderedItems[0]?.start_time);
  if (!firstStart) return [];
  const updates = [];
  // Lấy start_time của item đầu tiên trong thứ tự mới làm mốc
  let cursor = firstStart;
  for (const item of orderedItems) {
    const oldStart = asTime(item.start_time);
    const oldEnd = asTime(item.end_time);
    if (!oldStart || !oldEnd) continue;
    // Tính duration bằng phút
    const durationMinutes = timeToMinutes(oldEnd) - timeToMinutes(oldStart);
    if (durationMinutes <= 0) continue; // bỏ qua item có thời gian không hợp lệ
    const newStart = cursor;
    const newEnd = minutesToTime(timeToMinutes(newStart) + durationMinutes);
    if (newStart !== oldStart || newEnd !== oldEnd) {
      updates.push({ id: item.id, startTime: newStart, endTime: newEnd });
    }
    cursor = newEnd;
  }
  return updates;
};

/** Chuyển "HH:MM" thành tổng số phút. */
const timeToMinutes = time => {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
};

/** Chuyển tổng số phút thành "HH:MM". */
const minutesToTime = minutes => {
  const clamped = Math.min(minutes, 23 * 60 + 59);
  const h = String(Math.floor(clamped / 60)).padStart(2, '0');
  const m = String(clamped % 60).padStart(2, '0');
  return `${h}:${m}`;
};

const buildInternalItinerary = async (client, tripId, userId) => {
  const trip = await repo.findTripForMember(client, tripId, userId);
  if (!trip) throw apiError(404, 'Không tìm thấy lịch trình');
  const days = await repo.findDays(client, tripId);
  const items = await repo.findItemsForDays(client, days.map(day => day.id));
  const itemsByDay = new Map();
  for (const item of items) {
    if (!itemsByDay.has(item.itinerary_id)) itemsByDay.set(item.itinerary_id, []);
    itemsByDay.get(item.itinerary_id).push(item);
  }
  const daysByNumber = new Map(days.map(day => [Number(day.day_number), day]));
  const output = [];
  const duration = Number(trip.duration_days);
  if (!Number.isInteger(duration) || duration < 1) {
    throw apiError(500, 'Thời lượng chuyến đi không hợp lệ');
  }
  for (let dayNumber = 1; dayNumber <= duration; dayNumber++) {
    const existing = daysByNumber.get(dayNumber);
    const row = existing || {
      tripId,
      dayNumber,
      title: `Ngày ${dayNumber}`,
      tripDate: datePlus(trip.start_date, dayNumber - 1),
    };
    output.push(formatDay(row, existing ? (itemsByDay.get(existing.id) || []) : []));
  }
  return { trip: formatTripHeader(trip), days: output };
};

const getItineraries = (tripId, userId) => buildInternalItinerary(db, tripId, userId);

const createDay = (tripId, userId, data) => db.transaction(async client => {
  const trip = await repo.findTrip(client, tripId, true);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true, true);
  ensureEditable(trip);
  if (data.dayNumber > Number(trip.duration_days)) throw apiError(400, 'Ngày nằm ngoài chuyến đi');
  try {
    const row = await repo.createDay(client, tripId, data.dayNumber,
      data.title || `Ngày ${data.dayNumber}`, datePlus(trip.start_date, data.dayNumber - 1));
    return formatDay(row);
  } catch (error) {
    if (error.code === '23505') throw apiError(409, 'Ngày lịch trình đã tồn tại');
    throw error;
  }
});

const getDay = async (dayId, userId) => {
  const day = await repo.findDay(db, dayId);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  await requireMember(db, day.trip_id, userId);
  const items = await repo.findItemsForDays(db, [dayId]);
  return formatDay(day, items);
};

const updateDay = (dayId, userId, data) => db.transaction(async client => {
  const initial = await repo.findDay(client, dayId);
  if (!initial) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, dayId, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  ensureEditable(trip);
  if (!sameVersion(day.row_version, data.expectedVersion)) throw apiError(409, 'Ngày đã được cập nhật');
  const updated = await repo.updateDay(client, dayId,
    data.title || `Ngày ${day.day_number}`, data.expectedVersion);
  if (!updated) throw apiError(409, 'Ngày đã được cập nhật');
  const items = await repo.findItemsForDays(client, [dayId]);
  return formatDay(updated, items);
});

const getItem = async (itemId, userId) => {
  const item = await repo.findItem(db, itemId);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  await requireMember(db, item.trip_id, userId);
  return formatItem(item);
};

const resolveItemInput = async (client, data) => {
  const source = data.locationSource || (data.placeId ? 'CATALOG' : 'MANUAL');
  if (source === 'CATALOG') {
    if (!data.placeId) throw apiError(400, 'placeId bắt buộc cho CATALOG');
    const place = await repo.findPlace(client, data.placeId);
    if (!place || !place.is_active) throw apiError(404, 'Không tìm thấy địa điểm đang hoạt động');
    return {
      ...data,
      locationSource: 'CATALOG',
      customName: place.name,
      customAddress: place.address,
      category: place.category,
      latitude: place.latitude != null ? Number(place.latitude) : null,
      longitude: place.longitude != null ? Number(place.longitude) : null,
      externalProvider: null,
      externalPlaceId: null,
    };
  }
  if (source === 'GEOAPIFY') {
    if (!data.category) throw apiError(400, 'Category là bắt buộc cho hoạt động GEOAPIFY');
    return {
      ...data,
      locationSource: 'GEOAPIFY',
      externalProvider: data.externalProvider || 'GEOAPIFY',
      placeId: null,
    };
  }
  // MANUAL
  if (!data.category) throw apiError(400, 'Category là bắt buộc cho hoạt động tùy chỉnh');
  return {
    ...data,
    locationSource: 'MANUAL',
    placeId: null,
    externalProvider: null,
    externalPlaceId: null,
  };
};

const addItem = (dayId, userId, data) => db.transaction(async client => {
  const initial = await repo.findDay(client, dayId);
  if (!initial) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, dayId, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  ensureEditable(trip);
  if (await repo.hasOverlap(client, dayId, data.startTime, data.endTime)) {
    throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
  }
  const resolved = await resolveItemInput(client, data);
  resolved.orderIndex = await repo.nextOrderIndex(client, dayId);
  try { return formatItem(await repo.createItem(client, dayId, resolved)); }
  catch (error) {
    if (error.code === '23P01') throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
    throw error;
  }
});

const updateItem = (itemId, userId, data) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, initial.itinerary_id, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.row_version, data.expectedVersion)) throw apiError(409, 'Hoạt động đã được cập nhật');
  const startTime = data.startTime || asTime(item.start_time);
  const endTime = data.endTime || asTime(item.end_time);
  if (!startTime || !endTime) throw apiError(400, 'Hoạt động cần đủ giờ bắt đầu và kết thúc');
  if (startTime >= endTime) throw apiError(400, 'Thời gian bắt đầu phải trước thời gian kết thúc');
  if (await repo.hasOverlap(client, item.itinerary_id, startTime, endTime, itemId)) {
    throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
  }
  try {
    const updated = await repo.updateItem(client, itemId, data, data.expectedVersion);
    if (!updated) throw apiError(409, 'Hoạt động đã được cập nhật');
    return formatItem(updated);
  } catch (error) {
    if (error.code === '23P01') throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
    throw error;
  }
});

const deleteItem = (itemId, userId, data = {}) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, initial.itinerary_id, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.row_version, data.expectedVersion)) {
    throw apiError(409, 'Hoạt động đã được cập nhật');
  }
  const deleted = await repo.deleteItem(client, itemId, data.expectedVersion);
  if (!deleted) throw apiError(409, 'Hoạt động đã được cập nhật');
  return formatItem(deleted);
});

const setCompletion = (itemId, userId, data) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, initial.itinerary_id, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.row_version, data.expectedVersion)) throw apiError(409, 'Hoạt động đã được cập nhật');
  const updated = await repo.setCompletion(client, itemId, data.isCompleted, data.expectedVersion);
  if (!updated) throw apiError(409, 'Hoạt động đã được cập nhật');
  return formatItem(updated);
});

const reorderItems = (dayId, userId, data) => db.transaction(async client => {
  const initial = await repo.findDay(client, dayId);
  if (!initial) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, dayId, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  ensureEditable(trip);
  if (!sameVersion(day.row_version, data.expectedVersion)) {
    throw apiError(409, 'Ngày đã được cập nhật');
  }

  const currentItems = await repo.findItemsForDays(client, [dayId]);
  const currentIds = new Set(currentItems.map(item => item.id));
  if (data.orderedItemIds.length !== currentIds.size
      || data.orderedItemIds.some(id => !currentIds.has(id))) {
    throw apiError(400, 'Danh sách sắp xếp phải chứa đúng toàn bộ hoạt động của ngày');
  }

  await repo.reorderItems(client, dayId, data.orderedItemIds);

  // Phương án A: tự động tính lại start_time/end_time theo thứ tự mới,
  // giữ nguyên duration (khoảng thời gian) của từng hoạt động.
  const itemMap = new Map(currentItems.map(item => [item.id, item]));
  const orderedItems = data.orderedItemIds.map(id => itemMap.get(id));
  const timeUpdates = recalculateSequentialTimes(orderedItems);
  if (timeUpdates.length > 0) {
    await repo.bulkUpdateItemTimes(client, timeUpdates);
  }

  const updatedDay = await repo.touchDayVersion(client, dayId, data.expectedVersion);
  if (!updatedDay) throw apiError(409, 'Ngày đã được cập nhật');
  await repo.notifyTripMembers(
    client,
    initial.trip_id,
    userId,
    'Lịch trình đã được sắp xếp lại',
    `Thứ tự các điểm đến trong Ngày ${day.day_number} đã được cập nhật.`,
    { tripId: initial.trip_id, dayId },
  );
  const updatedItems = await repo.findItemsForDays(client, [dayId]);
  return formatDay(updatedDay, updatedItems);
});

const haversine = (a, b) => {
  if (!a || !b || [a.latitude, a.longitude, b.latitude, b.longitude].some(v => v == null)) return null;
  const rad = value => value * Math.PI / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
};

const routeThrough = (a, middle, c) => {
  let total = 0;
  if (a) total += haversine(a, middle) || 0;
  if (c) total += haversine(middle, c) || 0;
  return total;
};

const signCandidate = payload => {
  const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', env.jwt.secret).update(encoded).digest('base64url');
  return `${encoded}.${signature}`;
};

const verifyCandidate = token => {
  const [encoded, signature, extra] = String(token).split('.');
  if (!encoded || !signature || extra) throw apiError(409, 'Candidate token không hợp lệ');
  const expected = crypto.createHmac('sha256', env.jwt.secret).update(encoded).digest('base64url');
  const actualBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (actualBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(actualBuffer, expectedBuffer)) {
    throw apiError(409, 'Candidate token không hợp lệ');
  }
  let payload;
  try { payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')); }
  catch { throw apiError(409, 'Candidate token không hợp lệ'); }
  if (!payload.expiresAt || Date.now() >= payload.expiresAt) throw apiError(409, 'Candidate token đã hết hạn');
  return payload;
};

const candidateRows = async (client, item, radiusKm, limit, withTokens) => {
  // Smart Swap chỉ hỗ trợ item CATALOG có place nội bộ hợp lệ
  if (!item.place_id || item.location_source !== 'CATALOG'
      || item.place_latitude == null || item.place_longitude == null
      || !item.place_active || !item.place_duration || item.place_duration <= 0) {
    throw apiError(422, 'Hoạt động không đủ điều kiện Smart Swap');
  }
  const dayItems = await repo.findDayItemsWithPlaces(client, item.itinerary_id);
  const index = dayItems.findIndex(row => row.id === item.id);
  const coordinate = row => row && row.latitude != null && row.longitude != null
    ? { latitude: row.latitude, longitude: row.longitude } : null;
  const previous = coordinate(dayItems[index - 1]);
  const next = coordinate(dayItems[index + 1]);
  const original = { latitude: item.place_latitude, longitude: item.place_longitude };
  const originalRoute = routeThrough(previous, original, next);
  const candidates = await repo.findSwapCandidates(client, item, radiusKm);
  const rows = candidates.map(place => {
    const point = { latitude: place.latitude, longitude: place.longitude };
    const routeDeltaKm = routeThrough(previous, point, next) - originalRoute;
    const distance = Number(place.distance_from_original_km);
    const durationPenalty = Math.min(1, Math.abs(place.avg_duration_minutes - item.place_duration) / item.place_duration);
    const pricePenalty = Math.min(1, Math.abs((place.price_level || 1) - (item.place_price_level || 1)) / 3);
    const ratingPenalty = Math.min(1, (5 - Number(place.rating || 0)) / 5);
    const score = 0.40 * Math.min(1, Math.max(0, (routeDeltaKm + radiusKm) / (2 * radiusKm)))
      + 0.25 * Math.min(1, Math.max(0, distance / radiusKm))
      + 0.15 * durationPenalty + 0.10 * pricePenalty + 0.10 * ratingPenalty;
    const result = {
      placeId: place.id, name: place.name, address: place.address || null, category: place.category,
      rating: Number(place.rating || 0), priceLevel: place.price_level,
      avgDurationMinutes: place.avg_duration_minutes,
      distanceFromOriginalKm: Number(distance.toFixed(3)),
      routeDeltaKm: Number(routeDeltaKm.toFixed(3)), score: Number(score.toFixed(6)),
    };
    if (withTokens) result.candidateToken = signCandidate({
      itemId: item.id, candidatePlaceId: place.id,
      itemVersion: String(item.row_version), radiusKm,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });
    return result;
  }).filter(row => row.routeDeltaKm <= 2 * radiusKm)
    .sort((a, b) => a.score - b.score || a.placeId.localeCompare(b.placeId));
  return rows.slice(0, limit);
};

const getSwapCandidates = async (itemId, userId, query) => {
  const item = await repo.findItem(db, itemId);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  await requireMember(db, item.trip_id, userId);
  return candidateRows(db, item, query.radiusKm, query.limit, true);
};

const applySmartSwap = (itemId, userId, data) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, initial.itinerary_id, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.row_version, data.expectedVersion)) throw apiError(409, 'Hoạt động đã được cập nhật');
  const token = verifyCandidate(data.candidateToken);
  const currentVersion = String(item.row_version);
  if (token.itemId !== itemId || token.candidatePlaceId !== data.newPlaceId
      || token.itemVersion !== currentVersion) throw apiError(409, 'Candidate token đã cũ');
  const eligible = await candidateRows(client, item, token.radiusKm, 100, false);
  if (!eligible.some(row => row.placeId === data.newPlaceId)) {
    throw apiError(422, 'Địa điểm không còn đủ điều kiện thay thế');
  }
  const place = await repo.findPlace(client, data.newPlaceId);
  const updated = await repo.applySmartSwap(client, itemId, place, data.expectedVersion);
  if (!updated) throw apiError(409, 'Hoạt động đã được cập nhật');
  await repo.notifyTripMembers(client, item.trip_id, userId, 'Lịch trình đã thay đổi',
    place.name, { tripId: item.trip_id, itemId, placeId: place.id });
  return formatItem(updated);
});

const listPublic = async query => {
  const result = await repo.listPublicTrips(db, query);
  return {
    items: result.rows.map(formatPublicSummary),
    pagination: { page: query.page, limit: query.limit, total: result.total,
      totalPages: Math.ceil(result.total / query.limit) },
  };
};

const getPublic = async sourceTripId => {
  const trip = await repo.findPublicTrip(db, sourceTripId);
  if (!trip) throw apiError(404, 'Không tìm thấy lịch trình công khai');
  const days = await repo.findDays(db, sourceTripId);
  const items = await repo.findItemsForDays(db, days.map(day => day.id));
  const grouped = new Map();
  for (const item of items) {
    if (!grouped.has(item.itinerary_id)) grouped.set(item.itinerary_id, []);
    grouped.get(item.itinerary_id).push(item);
  }
  return { ...formatPublicSummary(trip),
    days: days.map(day => formatPublicDay(day, grouped.get(day.id) || [])) };
};

const clonePlan = (sourceTripId, userId, data) => db.transaction(async client => {
  const source = await repo.findTrip(client, sourceTripId, true);
  if (!source || source.status !== 'COMPLETED' || source.privacy_type !== 'PUBLIC') {
    throw apiError(404, 'Không tìm thấy lịch trình công khai');
  }
  const sourceDays = await repo.findDays(client, sourceTripId);
  if (!sourceDays.length) throw apiError(422, 'Lịch trình nguồn không có ngày để sao chép');

  const durationDays = Number(source.duration_days);
  const target = await repo.createClonedTrip(client, userId, source, {
    name: (data.name || `${source.name} (Bản sao)`).slice(0, 255),
    startDate: data.startDate,
    endDate: datePlus(data.startDate, durationDays - 1),
  });
  for (const sourceDay of sourceDays) {
    const targetDay = await repo.insertClonedDay(client, target.id, sourceDay,
      datePlus(data.startDate, sourceDay.day_number - 1));
    await repo.insertClonedItems(client, sourceDay.id, targetDay.id);
  }
  await repo.markClone(client, sourceTripId);
  return buildInternalItinerary(client, target.id, userId);
});

module.exports = {
  getItineraries, createDay, getDay, updateDay, getItem, addItem, updateItem,
  deleteItem, setCompletion, reorderItems, getSwapCandidates, applySmartSwap,
  listPublic, getPublic, clonePlan, resolveItemInput, recalculateSequentialTimes,
};
