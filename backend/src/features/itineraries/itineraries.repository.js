const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Itineraries
// Giao tiếp với cơ sở dữ liệu cho bảng itineraries, itinerary_items
// ============================================================================

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 * @param {string} forUpdate
 */
const getMembership = async (client, tripId, userId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trip_members WHERE trip_id=$1 AND user_id=$2${forUpdate ? ' FOR UPDATE' : ''}`,
    [tripId, userId]);
  return row || null;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} forUpdate
 */
const findTrip = async (client, tripId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trips WHERE id=$1${forUpdate ? ' FOR UPDATE' : ''}`, [tripId]);
  return row || null;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 */
const findTripForMember = async (client, tripId, userId) => {
  const { rows: [row] } = await client.query(`
    SELECT t.id,t.name,t.start_date,t.end_date,t.status,tm.role AS member_role
    FROM trips t JOIN trip_members tm ON tm.trip_id=t.id
    WHERE t.id=$1 AND tm.user_id=$2 AND tm.membership_status='ACTIVE'`, [tripId, userId]);
  return row || null;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} tripId
 */
const findDays = async (client, tripId) => {
  const { rows } = await client.query(
    'SELECT * FROM itineraries WHERE trip_id=$1 ORDER BY day_number', [tripId]);
  return rows;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} dayIds
 */
const findItemsForDays = async (client, dayIds) => {
  if (!dayIds.length) return [];
  const { rows } = await client.query(`
    SELECT * FROM itinerary_items WHERE itinerary_id=ANY($1::uuid[])
    ORDER BY start_time,order_index,id`, [dayIds]);
  return rows;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} dayId
 * @param {string} forUpdate
 */
const findDay = async (client, dayId, forUpdate = false) => {
  const { rows: [row] } = await client.query(`
    SELECT i.*,t.status AS trip_status,t.start_date,t.end_date,t.duration_days,t.destination
    FROM itineraries i JOIN trips t ON t.id=i.trip_id
    WHERE i.id=$1${forUpdate ? ' FOR UPDATE OF i' : ''}`, [dayId]);
  return row || null;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} itemId
 * @param {string} forUpdate
 */
const findItem = async (client, itemId, forUpdate = false) => {
  const { rows: [row] } = await client.query(`
    SELECT ii.*,i.trip_id,i.day_number,i.trip_date,t.status AS trip_status,
      t.destination AS trip_destination,t.start_date,t.end_date,t.duration_days,
      p.latitude AS place_latitude,p.longitude AS place_longitude,p.destination AS place_destination,
      p.price_level AS place_price_level,p.avg_duration_minutes AS place_duration,
      p.rating AS place_rating,p.is_active AS place_active
    FROM itinerary_items ii
    JOIN itineraries i ON i.id=ii.itinerary_id
    JOIN trips t ON t.id=i.trip_id
    LEFT JOIN places p ON p.id=ii.place_id
    WHERE ii.id=$1${forUpdate ? ' FOR UPDATE OF ii' : ''}`, [itemId]);
  return row || null;
};

/**
 * @description Tạo mới lịch trình.
 * @param {object} client
 * @param {string} tripId
 * @param {string} dayNumber
 * @param {string} title
 * @param {string} tripDate
 */
const createDay = async (client, tripId, dayNumber, title, tripDate) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itineraries (trip_id,day_number,title,trip_date)
    VALUES ($1,$2,$3,$4) RETURNING *`, [tripId, dayNumber, title, tripDate]);
  return row;
};

/**
 * @description Cập nhật lịch trình.
 * @param {object} client
 * @param {string} dayId
 * @param {string} title
 */
const updateDay = async (client, dayId, title) => {
  const { rows: [row] } = await client.query(`
    UPDATE itineraries SET title=$2 WHERE id=$1 RETURNING *`, [dayId, title]);
  return row || null;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} placeId
 */
const findPlace = async (client, placeId) => {
  const { rows: [row] } = await client.query('SELECT * FROM places WHERE id=$1', [placeId]);
  return row || null;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} dayId
 * @param {string} startTime
 * @param {string} endTime
 * @param {string} excludedItemId
 */
const hasOverlap = async (client, dayId, startTime, endTime, excludedItemId = null) => {
  const { rowCount } = await client.query(`
    SELECT 1 FROM itinerary_items
    WHERE itinerary_id=$1 AND start_time<$3::time AND end_time>$2::time
      AND ($4::uuid IS NULL OR id<>$4::uuid) LIMIT 1`,
    [dayId, startTime, endTime, excludedItemId]);
  return rowCount > 0;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} dayId
 */
const nextOrderIndex = async (client, dayId) => {
  const { rows: [row] } = await client.query(
    'SELECT COALESCE(MAX(order_index),-1)+1 AS next FROM itinerary_items WHERE itinerary_id=$1', [dayId]);
  return Number(row.next);
};

/**
 * @description Tạo mới lịch trình.
 * @param {object} client
 * @param {string} dayId
 * @param {object} data
 */
const createItem = async (client, dayId, data) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itinerary_items (
      itinerary_id,place_id,custom_name,custom_address,category,start_time,end_time,
      order_index,note,estimated_cost,is_completed
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,FALSE) RETURNING *`,
    [dayId, data.placeId || null, data.customName, data.customAddress || null, data.category,
      data.startTime, data.endTime, data.orderIndex, data.note || null, data.estimatedCost ?? 0]);
  return row;
};

/**
 * @description Cập nhật lịch trình.
 * @param {object} client
 * @param {string} itemId
 * @param {object} data
 */
const updateItem = async (client, itemId, data) => {
  const map = {
    customName: 'custom_name', customAddress: 'custom_address', category: 'category',
    startTime: 'start_time', endTime: 'end_time', note: 'note', estimatedCost: 'estimated_cost',
  };
  const params = [itemId];
  const sets = [];
  for (const [key, column] of Object.entries(map)) {
    if (data[key] !== undefined) {
      params.push(data[key] === '' ? null : data[key]);
      sets.push(`${column}=$${params.length}`);
    }
  }
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET ${sets.join(', ')}
    WHERE id=$1 RETURNING *`, params);
  return row || null;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} itemId
 * @param {string} isCompleted
 */
const setCompletion = async (client, itemId, isCompleted) => {
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET is_completed=$2
    WHERE id=$1 RETURNING *`, [itemId, isCompleted]);
  return row || null;
};

/**
 * @description Xóa lịch trình.
 * @param {object} client
 * @param {string} itemId
 */
const deleteItem = async (client, itemId) => {
  const { rows: [row] } = await client.query(
    'DELETE FROM itinerary_items WHERE id=$1 RETURNING *', [itemId]);
  return row || null;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} dayId
 */
const findDayItemsWithPlaces = async (client, dayId) => {
  const { rows } = await client.query(`
    SELECT ii.*,p.latitude,p.longitude,p.price_level,p.avg_duration_minutes,p.rating,p.is_active,
      p.destination AS place_destination
    FROM itinerary_items ii LEFT JOIN places p ON p.id=ii.place_id
    WHERE ii.itinerary_id=$1 ORDER BY ii.start_time,ii.order_index,ii.id`, [dayId]);
  return rows;
};

/**
 * @description Lấy thông tin lịch trình.
 * @param {object} client
 * @param {string} item
 * @param {string} radiusKm
 */
const findSwapCandidates = async (client, item, radiusKm) => {
  const { rows } = await client.query(`
    SELECT p.*,
      (6371 * 2 * asin(sqrt(
        power(sin(radians(p.latitude-$2)/2),2) +
        cos(radians($2))*cos(radians(p.latitude))*power(sin(radians(p.longitude-$3)/2),2)
      ))) AS distance_from_original_km
    FROM places p
    WHERE p.id<>$1 AND p.is_active=TRUE
      AND LOWER(p.destination)=LOWER($4) AND p.category=$5
      AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL
      AND ABS(COALESCE(p.price_level,1)-COALESCE($6,1))<=1
      AND ABS(COALESCE(p.avg_duration_minutes,0)-$7)<=GREATEST(30,$7*0.5)
      AND NOT EXISTS (
        SELECT 1 FROM itinerary_items used
        JOIN itineraries used_day ON used_day.id=used.itinerary_id
        WHERE used_day.trip_id=$8 AND used.place_id=p.id
      )
      AND (6371 * 2 * asin(sqrt(
        power(sin(radians(p.latitude-$2)/2),2) +
        cos(radians($2))*cos(radians(p.latitude))*power(sin(radians(p.longitude-$3)/2),2)
      ))) <= $9
    ORDER BY distance_from_original_km ASC LIMIT 100`,
    [item.place_id, item.place_latitude, item.place_longitude, item.place_destination,
      item.category, item.place_price_level, item.place_duration, item.trip_id, radiusKm]);
  return rows;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} itemId
 * @param {string} place
 */
const applySmartSwap = async (client, itemId, place) => {
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET place_id=$2,custom_name=$3,custom_address=$4,category=$5
    WHERE id=$1 RETURNING *`, [itemId, place.id, place.name, place.address, place.category]);
  return row || null;
};

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} actorId
 * @param {string} title
 * @param {string} message
 * @param {object} data
 */
const notifyTripMembers = async (client, tripId, actorId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    SELECT tm.user_id,$3,$4,'TRIP_UPDATE',$5::jsonb FROM trip_members tm
    WHERE tm.trip_id=$1 AND tm.membership_status='ACTIVE' AND tm.user_id<>$2`,
    [tripId, actorId, title, message, JSON.stringify(data)]);
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {object} query
 */
const listPublicTrips = async (client, query) => {
  const params = [];
  const filters = ["t.status<>'CANCELLED'",
    "(t.privacy_type='PUBLIC' OR (t.is_template=TRUE AND t.template_status='ACTIVE'))"];
  if (query.destination) { params.push(query.destination); filters.push(`LOWER(t.destination)=LOWER($${params.length})`); }
  if (query.durationDays) { params.push(query.durationDays); filters.push(`t.duration_days=$${params.length}`); }
  if (query.keyword) {
    params.push(`%${query.keyword}%`);
    filters.push(`(t.name ILIKE $${params.length} OR t.description ILIKE $${params.length}
      OR EXISTS (SELECT 1 FROM itineraries ki JOIN itinerary_items kii ON kii.itinerary_id=ki.id
        WHERE ki.trip_id=t.id AND kii.custom_name ILIKE $${params.length}))`);
  }
  const where = filters.join(' AND ');
  const { rows: [{ total }] } = await client.query(
    `SELECT COUNT(*)::int AS total FROM trips t WHERE ${where}`, params);
  params.push(query.limit, (query.page - 1) * query.limit);
  const { rows } = await client.query(`
    SELECT t.* FROM trips t WHERE ${where}
    ORDER BY CASE WHEN t.is_template AND t.template_status='ACTIVE' THEN 0 ELSE 1 END,
      t.clone_count DESC,t.updated_at DESC
    LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows, total };
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const findPublicTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    SELECT * FROM trips WHERE id=$1 AND status<>'CANCELLED'
      AND (privacy_type='PUBLIC' OR (is_template=TRUE AND template_status='ACTIVE'))`, [tripId]);
  return row || null;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} tripId
 */
const targetHasDays = async (client, tripId) => {
  const { rowCount } = await client.query('SELECT 1 FROM itineraries WHERE trip_id=$1 LIMIT 1', [tripId]);
  return rowCount > 0;
};

/**
 * @description Tạo mới lịch trình.
 * @param {object} client
 * @param {string} targetTripId
 * @param {string} sourceDay
 * @param {string} tripDate
 */
const insertClonedDay = async (client, targetTripId, sourceDay, tripDate) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itineraries (trip_id,day_number,title,trip_date)
    VALUES ($1,$2,$3,$4) RETURNING *`, [targetTripId, sourceDay.day_number, sourceDay.title, tripDate]);
  return row;
};

/**
 * @description Tạo mới lịch trình.
 * @param {object} client
 * @param {string} sourceDayId
 * @param {string} targetDayId
 */
const insertClonedItems = async (client, sourceDayId, targetDayId) => {
  const { rows } = await client.query(`
    INSERT INTO itinerary_items (
      itinerary_id,place_id,custom_name,custom_address,category,start_time,end_time,
      order_index,note,estimated_cost,is_completed
    ) SELECT $2,place_id,custom_name,custom_address,category,start_time,end_time,
      order_index,note,estimated_cost,FALSE
    FROM itinerary_items WHERE itinerary_id=$1
    ORDER BY start_time,order_index,id RETURNING *`, [sourceDayId, targetDayId]);
  return rows;
};

/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 * @param {object} client
 * @param {string} sourceTripId
 * @param {string} targetTripId
 */
const markClone = async (client, sourceTripId, targetTripId) => {
  await client.query(
    'UPDATE trips SET is_clone=TRUE,original_trip_id=$2 WHERE id=$1', [targetTripId, sourceTripId]);
  await client.query(
    'UPDATE trips SET clone_count=clone_count+1 WHERE id=$1', [sourceTripId]);
};

module.exports = {
  getMembership, findTrip, findTripForMember, findDays, findItemsForDays,
  findDay, findItem, createDay, updateDay, findPlace, hasOverlap, nextOrderIndex,
  createItem, updateItem, setCompletion, deleteItem, findDayItemsWithPlaces,
  findSwapCandidates, applySmartSwap, notifyTripMembers, listPublicTrips,
  findPublicTrip, targetHasDays, insertClonedDay, insertClonedItems, markClone,
};
