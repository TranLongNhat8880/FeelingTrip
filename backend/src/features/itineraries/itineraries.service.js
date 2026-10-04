const crypto = require('crypto');
const db = require('../../config/database');
const env = require('../../config/env');
const apiError = require('../../shared/utils/apiError.util');
const repo = require('./itineraries.repository');
const serializer = require('./itineraries.serializer');

// ============================================================================
// SERVICE: Itineraries
// Xử lý logic nghiệp vụ cho lịch trình (ngày, hoạt động, smart swap, clone)
// ============================================================================

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} actual
 * @param {string} expected
 */
const sameVersion = (actual, expected) =>
  new Date(actual).getTime() === new Date(expected).getTime();
/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} date
 * @param {string} days
 */
const datePlus = (date, days) => {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
};

/**
 * @description Xử lý thao tác thành viên đối với lịch trình.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 * @param {string} leaderOnly
 * @param {string} lock
 */
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

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const ensureEditable = trip => {
  if (!['UPCOMING', 'ONGOING'].includes(trip.status || trip.trip_status)) {
    throw apiError(409, 'Chuyến đi không còn cho phép chỉnh sửa');
  }
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 */
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
  const duration = Math.round((Date.parse(`${trip.end_date}T00:00:00Z`)
    - Date.parse(`${trip.start_date}T00:00:00Z`)) / 86400000) + 1;
  for (let dayNumber = 1; dayNumber <= duration; dayNumber++) {
    const existing = daysByNumber.get(dayNumber);
    const row = existing || {
      tripId,
      dayNumber,
      title: `Ngày ${dayNumber}`,
      tripDate: datePlus(trip.start_date, dayNumber - 1),
    };
    output.push(serializer.day(row, existing ? (itemsByDay.get(existing.id) || []) : []));
  }
  return { trip: serializer.tripHeader(trip), days: output };
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {string} tripId
 * @param {string} userId
 */
const getItineraries = (tripId, userId) => buildInternalItinerary(db, tripId, userId);

/**
 * @description Tạo mới lịch trình.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} data
 */
const createDay = (tripId, userId, data) => db.transaction(async client => {
  const trip = await repo.findTrip(client, tripId, true);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true, true);
  ensureEditable(trip);
  if (data.dayNumber > Number(trip.duration_days)) throw apiError(400, 'Ngày nằm ngoài chuyến đi');
  try {
    const row = await repo.createDay(client, tripId, data.dayNumber,
      data.title || `Ngày ${data.dayNumber}`, datePlus(trip.start_date, data.dayNumber - 1));
    return serializer.day(row);
  } catch (error) {
    if (error.code === '23505') throw apiError(409, 'Ngày lịch trình đã tồn tại');
    throw error;
  }
});

/**
 * @description Lấy thông tin lịch trình.
 * @param {string} dayId
 * @param {string} userId
 */
const getDay = async (dayId, userId) => {
  const day = await repo.findDay(db, dayId);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  await requireMember(db, day.trip_id, userId);
  const items = await repo.findItemsForDays(db, [dayId]);
  return serializer.day(day, items);
};

/**
 * @description Cập nhật lịch trình.
 * @param {string} dayId
 * @param {string} userId
 * @param {object} data
 */
const updateDay = (dayId, userId, data) => db.transaction(async client => {
  const initial = await repo.findDay(client, dayId);
  if (!initial) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const day = await repo.findDay(client, dayId, true);
  if (!day) throw apiError(404, 'Không tìm thấy ngày lịch trình');
  ensureEditable(trip);
  if (!sameVersion(day.updated_at, data.expectedUpdatedAt)) throw apiError(409, 'Ngày đã được cập nhật');
  const updated = await repo.updateDay(client, dayId, data.title || `Ngày ${day.day_number}`);
  if (!updated) throw apiError(409, 'Ngày đã được cập nhật');
  const items = await repo.findItemsForDays(client, [dayId]);
  return serializer.day(updated, items);
});

/**
 * @description Lấy thông tin lịch trình.
 * @param {string} itemId
 * @param {string} userId
 */
const getItem = async (itemId, userId) => {
  const item = await repo.findItem(db, itemId);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  await requireMember(db, item.trip_id, userId);
  return serializer.item(item);
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {object} data
 */
const resolveItemInput = async (client, data) => {
  if (!data.placeId) {
    if (!data.category) throw apiError(400, 'Category là bắt buộc cho hoạt động tùy chỉnh');
    return data;
  }
  const place = await repo.findPlace(client, data.placeId);
  if (!place || !place.is_active) throw apiError(404, 'Không tìm thấy địa điểm đang hoạt động');
  return { ...data, customName: place.name, customAddress: place.address, category: place.category };
};

/**
 * @description Tạo mới lịch trình.
 * @param {string} dayId
 * @param {string} userId
 * @param {object} data
 */
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
  try { return serializer.item(await repo.createItem(client, dayId, resolved)); }
  catch (error) {
    if (error.code === '23P01') throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
    throw error;
  }
});

/**
 * @description Cập nhật lịch trình.
 * @param {string} itemId
 * @param {string} userId
 * @param {object} data
 */
const updateItem = (itemId, userId, data) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.updated_at, data.expectedUpdatedAt)) throw apiError(409, 'Hoạt động đã được cập nhật');
  const startTime = data.startTime || String(item.start_time).slice(0, 5);
  const endTime = data.endTime || String(item.end_time).slice(0, 5);
  if (startTime >= endTime) throw apiError(400, 'Thời gian bắt đầu phải trước thời gian kết thúc');
  if (await repo.hasOverlap(client, item.itinerary_id, startTime, endTime, itemId)) {
    throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
  }
  try {
    const updated = await repo.updateItem(client, itemId, data);
    if (!updated) throw apiError(409, 'Hoạt động đã được cập nhật');
    return serializer.item(updated);
  } catch (error) {
    if (error.code === '23P01') throw apiError(409, 'Thời gian hoạt động bị chồng lấn');
    throw error;
  }
});

/**
 * @description Xóa lịch trình.
 * @param {string} itemId
 * @param {string} userId
 * @param {object} data
 */
const deleteItem = (itemId, userId, data = {}) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (data.expectedUpdatedAt && !sameVersion(item.updated_at, data.expectedUpdatedAt)) {
    throw apiError(409, 'Hoạt động đã được cập nhật');
  }
  const deleted = await repo.deleteItem(client, itemId);
  if (!deleted) throw apiError(409, 'Hoạt động đã được cập nhật');
  return serializer.item(deleted);
});

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} itemId
 * @param {string} userId
 * @param {object} data
 */
const setCompletion = (itemId, userId, data) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.updated_at, data.expectedUpdatedAt)) throw apiError(409, 'Hoạt động đã được cập nhật');
  const updated = await repo.setCompletion(client, itemId, data.isCompleted);
  if (!updated) throw apiError(409, 'Hoạt động đã được cập nhật');
  return serializer.item(updated);
});

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} a
 * @param {string} b
 */
const haversine = (a, b) => {
  if (!a || !b || [a.latitude, a.longitude, b.latitude, b.longitude].some(v => v == null)) return null;
  const rad = value => value * Math.PI / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} a
 * @param {string} middle
 * @param {string} c
 */
const routeThrough = (a, middle, c) => {
  let total = 0;
  if (a) total += haversine(a, middle) || 0;
  if (c) total += haversine(middle, c) || 0;
  return total;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const signCandidate = payload => {
  const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', env.smartSwapTokenSecret).update(encoded).digest('base64url');
  return `${encoded}.${signature}`;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const verifyCandidate = token => {
  const [encoded, signature, extra] = String(token).split('.');
  if (!encoded || !signature || extra) throw apiError(409, 'Candidate token không hợp lệ');
  const expected = crypto.createHmac('sha256', env.smartSwapTokenSecret).update(encoded).digest('base64url');
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

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} item
 * @param {string} radiusKm
 * @param {string} limit
 * @param {string} withTokens
 */
const candidateRows = async (client, item, radiusKm, limit, withTokens) => {
  if (!item.place_id || item.place_latitude == null || item.place_longitude == null
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
      itemUpdatedAt: new Date(item.updated_at).toISOString(), radiusKm,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });
    return result;
  }).filter(row => row.routeDeltaKm <= 2 * radiusKm)
    .sort((a, b) => a.score - b.score || a.placeId.localeCompare(b.placeId));
  return rows.slice(0, limit);
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {string} itemId
 * @param {string} userId
 * @param {object} query
 */
const getSwapCandidates = async (itemId, userId, query) => {
  const item = await repo.findItem(db, itemId);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  await requireMember(db, item.trip_id, userId);
  return candidateRows(db, item, query.radiusKm, query.limit, true);
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} itemId
 * @param {string} userId
 * @param {object} data
 */
const applySmartSwap = (itemId, userId, data) => db.transaction(async client => {
  const initial = await repo.findItem(client, itemId);
  if (!initial) throw apiError(404, 'Không tìm thấy hoạt động');
  const trip = await repo.findTrip(client, initial.trip_id, true);
  await requireMember(client, initial.trip_id, userId, true, true);
  const item = await repo.findItem(client, itemId, true);
  if (!item) throw apiError(404, 'Không tìm thấy hoạt động');
  ensureEditable(trip);
  if (!sameVersion(item.updated_at, data.expectedUpdatedAt)) throw apiError(409, 'Hoạt động đã được cập nhật');
  const token = verifyCandidate(data.candidateToken);
  const currentVersion = new Date(item.updated_at).toISOString();
  if (token.itemId !== itemId || token.candidatePlaceId !== data.newPlaceId
      || token.itemUpdatedAt !== currentVersion) throw apiError(409, 'Candidate token đã cũ');
  const eligible = await candidateRows(client, item, token.radiusKm, 100, false);
  if (!eligible.some(row => row.placeId === data.newPlaceId)) {
    throw apiError(422, 'Địa điểm không còn đủ điều kiện thay thế');
  }
  const place = await repo.findPlace(client, data.newPlaceId);
  const updated = await repo.applySmartSwap(client, itemId, place);
  if (!updated) throw apiError(409, 'Hoạt động đã được cập nhật');
  await repo.notifyTripMembers(client, item.trip_id, userId, 'Lịch trình đã thay đổi',
    place.name, { tripId: item.trip_id, itemId, placeId: place.id });
  return serializer.item(updated);
});

/**
 * @description Lấy thông tin lịch trình.
 */
const listPublic = async query => {
  const result = await repo.listPublicTrips(db, query);
  return {
    items: result.rows.map(serializer.publicSummary),
    pagination: { page: query.page, limit: query.limit, total: result.total,
      totalPages: Math.ceil(result.total / query.limit) },
  };
};

/**
 * @description Lấy thông tin lịch trình.
 */
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
  return { ...serializer.publicSummary(trip),
    days: days.map(day => serializer.publicDay(day, grouped.get(day.id) || [])) };
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} sourceTripId
 * @param {string} targetTripId
 * @param {string} userId
 */
const clonePlan = (sourceTripId, targetTripId, userId) => db.transaction(async client => {
  if (sourceTripId === targetTripId) throw apiError(400, 'Chuyến nguồn và đích phải khác nhau');
  const ids = [sourceTripId, targetTripId].sort();
  const locked = new Map();
  for (const id of ids) locked.set(id, await repo.findTrip(client, id, true));
  const source = locked.get(sourceTripId);
  const target = locked.get(targetTripId);
  if (!source || source.status === 'CANCELLED' || !(source.privacy_type === 'PUBLIC'
      || (source.is_template && source.template_status === 'ACTIVE'))) {
    throw apiError(404, 'Không tìm thấy lịch trình nguồn');
  }
  if (!target) throw apiError(404, 'Không tìm thấy chuyến đi đích');
  await requireMember(client, targetTripId, userId, true, true);
  if (target.status !== 'UPCOMING') throw apiError(409, 'Chuyến đi đích phải ở trạng thái UPCOMING');
  if (Number(source.duration_days) !== Number(target.duration_days)) {
    throw apiError(409, 'Số ngày của chuyến nguồn và đích không khớp');
  }
  if (await repo.targetHasDays(client, targetTripId)) throw apiError(409, 'Chuyến đi đích đã có lịch trình');
  const sourceDays = await repo.findDays(client, sourceTripId);
  if (!sourceDays.length) throw apiError(422, 'Lịch trình nguồn không có ngày để sao chép');
  for (const sourceDay of sourceDays) {
    const targetDay = await repo.insertClonedDay(client, targetTripId, sourceDay,
      datePlus(target.start_date, sourceDay.day_number - 1));
    await repo.insertClonedItems(client, sourceDay.id, targetDay.id);
  }
  await repo.markClone(client, sourceTripId, targetTripId);
  return buildInternalItinerary(client, targetTripId, userId);
});

module.exports = {
  getItineraries, createDay, getDay, updateDay, getItem, addItem, updateItem,
  deleteItem, setCompletion, getSwapCandidates, applySmartSwap,
  listPublic, getPublic, clonePlan,
};
