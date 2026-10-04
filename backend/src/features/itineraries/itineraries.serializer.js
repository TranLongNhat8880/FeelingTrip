
// ============================================================================
// SERIALIZER: Itineraries
// Định dạng dữ liệu lịch trình trả về cho Client
// ============================================================================
const asIso = value => value instanceof Date ? value.toISOString() : value;
/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} 0
 * @param {string} 5
 */
const asTime = value => typeof value === 'string' ? value.slice(0, 5) : value;

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const item = row => ({
  id: row.id,
  itineraryId: row.itinerary_id,
  placeId: row.place_id || null,
  customName: row.custom_name,
  customAddress: row.custom_address || null,
  category: row.category,
  startTime: asTime(row.start_time),
  endTime: asTime(row.end_time),
  note: row.note || null,
  estimatedCost: Number(row.estimated_cost || 0),
  isCompleted: Boolean(row.is_completed),
  createdAt: asIso(row.created_at),
  updatedAt: asIso(row.updated_at),
});

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} row
 * @param {string} items
 */
const day = (row, items = []) => ({
  id: row.id || null,
  tripId: row.trip_id || row.tripId,
  dayNumber: Number(row.day_number ?? row.dayNumber),
  title: row.title,
  tripDate: row.trip_date || row.tripDate,
  materialized: Boolean(row.id),
  ...(row.id ? { createdAt: asIso(row.created_at), updatedAt: asIso(row.updated_at) } : {}),
  items: items.map(item),
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 */
const tripHeader = row => ({
  id: row.id,
  name: row.name,
  startDate: row.start_date,
  endDate: row.end_date,
  status: row.status,
  memberRole: row.member_role,
});

/**
 * @description Định dạng dữ liệu đầu ra cho lịch trình.
 */
const publicSummary = row => ({
  sourceTripId: row.id,
  name: row.name,
  destination: row.destination,
  durationDays: Number(row.duration_days),
  coverImageUrl: row.cover_image_url || null,
  description: row.description || null,
  isTemplate: Boolean(row.is_template),
  cloneCount: Number(row.clone_count || 0),
  updatedAt: asIso(row.updated_at),
});

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const publicItem = row => ({
  customName: row.custom_name,
  customAddress: row.custom_address || null,
  category: row.category,
  startTime: asTime(row.start_time),
  endTime: asTime(row.end_time),
  note: row.note || null,
});

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {string} row
 * @param {string} items
 */
const publicDay = (row, items = []) => ({
  dayNumber: Number(row.day_number),
  title: row.title,
  items: items.map(publicItem),
});

module.exports = { item, day, tripHeader, publicSummary, publicDay };
