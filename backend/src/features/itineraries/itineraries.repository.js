const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Itineraries
// Giao tiếp với cơ sở dữ liệu cho bảng itineraries, itinerary_items
// ============================================================================

/**
 * @description Kiểm tra quyền thành viên của user trong chuyến đi.
 */
const getMembership = async (client, tripId, userId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trip_members WHERE trip_id=$1 AND user_id=$2${forUpdate ? ' FOR UPDATE' : ''}`,
    [tripId, userId]);
  return row || null;
};

/**
 * @description Lấy thông tin chung của chuyến đi.
 */
const findTrip = async (client, tripId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trips WHERE id=$1${forUpdate ? ' FOR UPDATE' : ''}`, [tripId]);
  return row || null;
};

/**
 * @description Lấy thông tin chuyến đi (dành cho người đã tham gia).
 */
const findTripForMember = async (client, tripId, userId) => {
  const { rows: [row] } = await client.query(`
    SELECT t.id,t.name,t.start_date::text AS start_date,
      t.end_date::text AS end_date,t.duration_days,t.status,
      tm.role AS member_role
    FROM trips t JOIN trip_members tm ON tm.trip_id=t.id
    WHERE t.id=$1 AND tm.user_id=$2 AND tm.membership_status='ACTIVE'`, [tripId, userId]);
  return row || null;
};

/**
 * @description Lấy danh sách các ngày lịch trình của chuyến đi.
 */
const findDays = async (client, tripId) => {
  const { rows } = await client.query(
    'SELECT i.*,i.xmin::text AS row_version FROM itineraries i WHERE trip_id=$1 ORDER BY day_number', [tripId]);
  return rows;
};

/**
 * @description Lấy tất cả các hoạt động của nhiều ngày cùng lúc.
 */
const findItemsForDays = async (client, dayIds) => {
  if (!dayIds.length) return [];
  const { rows } = await client.query(`
    SELECT ii.*,ii.xmin::text AS row_version,
      p.latitude,p.longitude
    FROM itinerary_items ii
    LEFT JOIN places p ON p.id=ii.place_id
    WHERE ii.itinerary_id=ANY($1::uuid[])
    ORDER BY ii.order_index,ii.start_time,ii.id`, [dayIds]);
  return rows;
};

/**
 * @description Lấy chi tiết một ngày lịch trình.
 */
const findDay = async (client, dayId, forUpdate = false) => {
  const { rows: [row] } = await client.query(`
    SELECT i.*,i.xmin::text AS row_version,
      t.status AS trip_status,t.start_date,t.end_date,t.duration_days,t.destination
    FROM itineraries i JOIN trips t ON t.id=i.trip_id
    WHERE i.id=$1${forUpdate ? ' FOR UPDATE OF i' : ''}`, [dayId]);
  return row || null;
};

/**
 * @description Lấy chi tiết một hoạt động kèm thông tin địa điểm.
 */
const findItem = async (client, itemId, forUpdate = false) => {
  const { rows: [row] } = await client.query(`
    SELECT ii.*,ii.xmin::text AS row_version,
      i.trip_id,i.day_number,i.trip_date,t.status AS trip_status,
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
 * @description Tạo thêm một ngày mới vào lịch trình.
 */
const createDay = async (client, tripId, dayNumber, title, tripDate) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itineraries (trip_id,day_number,title,trip_date)
    VALUES ($1,$2,$3,$4) RETURNING *,xmin::text AS row_version`,
  [tripId, dayNumber, title, tripDate]);
  return row;
};

/**
 * @description Đổi tên tiêu đề của một ngày lịch trình.
 */
const updateDay = async (client, dayId, title, expectedVersion) => {
  const { rows: [row] } = await client.query(`
    UPDATE itineraries SET title=$2
    WHERE id=$1 AND xmin::text=$3
    RETURNING *,xmin::text AS row_version`, [dayId, title, expectedVersion]);
  return row || null;
};

/**
 * @description Lấy thông tin chi tiết của một địa điểm.
 */
const findPlace = async (client, placeId) => {
  const { rows: [row] } = await client.query('SELECT * FROM places WHERE id=$1', [placeId]);
  return row || null;
};

/**
 * @description Kiểm tra xem giờ của hoạt động có bị trùng với các hoạt động khác không.
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
 * @description Lấy số thứ tự tiếp theo cho hoạt động mới trong ngày.
 */
const nextOrderIndex = async (client, dayId) => {
  const { rows: [row] } = await client.query(
    'SELECT COALESCE(MAX(order_index),-1)+1 AS next FROM itinerary_items WHERE itinerary_id=$1', [dayId]);
  return Number(row.next);
};

/**
 * @description Thêm hoạt động mới vào lịch trình.
 */
const createItem = async (client, dayId, data) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itinerary_items (
      itinerary_id,place_id,custom_name,custom_address,category,start_time,end_time,
      order_index,note,estimated_cost,is_completed
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,FALSE)
    RETURNING *,xmin::text AS row_version`,
    [dayId, data.placeId || null, data.customName, data.customAddress || null, data.category,
      data.startTime, data.endTime, data.orderIndex, data.note || null, data.estimatedCost ?? 0]);
  return row;
};

/**
 * @description Cập nhật chi tiết một hoạt động.
 */
const updateItem = async (client, itemId, data, expectedVersion) => {
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
  params.push(expectedVersion);
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET ${sets.join(', ')}
    WHERE id=$1 AND xmin::text=$${params.length}
    RETURNING *,xmin::text AS row_version`, params);
  return row || null;
};

/**
 * @description Đánh dấu hoàn thành/chưa hoàn thành cho một hoạt động.
 */
const setCompletion = async (client, itemId, isCompleted, expectedVersion) => {
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET is_completed=$2
    WHERE id=$1 AND xmin::text=$3
    RETURNING *,xmin::text AS row_version`, [itemId, isCompleted, expectedVersion]);
  return row || null;
};

/**
 * @description Xóa một hoạt động khỏi lịch trình.
 */
const deleteItem = async (client, itemId, expectedVersion) => {
  const { rows: [row] } = await client.query(
    'DELETE FROM itinerary_items WHERE id=$1 AND xmin::text=$2 RETURNING *,xmin::text AS row_version',
    [itemId, expectedVersion]);
  return row || null;
};

/**
 * @description Lấy danh sách hoạt động trong ngày kèm thông tin địa điểm chi tiết.
 */
const findDayItemsWithPlaces = async (client, dayId) => {
  const { rows } = await client.query(`
    SELECT ii.*,ii.xmin::text AS row_version,
      p.latitude,p.longitude,p.price_level,p.avg_duration_minutes,p.rating,p.is_active,
      p.destination AS place_destination
    FROM itinerary_items ii LEFT JOIN places p ON p.id=ii.place_id
    WHERE ii.itinerary_id=$1 ORDER BY ii.order_index,ii.start_time,ii.id`, [dayId]);
  return rows;
};

/**
 * @description Tìm các địa điểm tương đồng gần đó để gợi ý thay thế (Smart Swap).
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
 * @description Cập nhật hoạt động sang địa điểm mới được chọn.
 */
const applySmartSwap = async (client, itemId, place, expectedVersion) => {
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET place_id=$2,custom_name=$3,custom_address=$4,category=$5
    WHERE id=$1 AND xmin::text=$6
    RETURNING *,xmin::text AS row_version`,
  [itemId, place.id, place.name, place.address, place.category, expectedVersion]);
  return row || null;
};

/**
 * @description Gửi thông báo cho tất cả thành viên trong nhóm.
 */
const notifyTripMembers = async (client, tripId, actorId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    SELECT tm.user_id,$3::varchar,$4::text,'TRIP_UPDATE',$5::jsonb FROM trip_members tm
    WHERE tm.trip_id=$1 AND tm.membership_status='ACTIVE' AND tm.user_id<>$2`,
    [tripId, actorId, title, message, JSON.stringify(data)]);
};

const reorderItems = async (client, dayId, orderedItemIds) => {
  const { rows } = await client.query(`
    UPDATE itinerary_items ii SET order_index=(ordered.position-1)::int
    FROM unnest($2::uuid[]) WITH ORDINALITY AS ordered(id,position)
    WHERE ii.itinerary_id=$1 AND ii.id=ordered.id
    RETURNING ii.*,ii.xmin::text AS row_version`, [dayId, orderedItemIds]);
  return rows;
};

const touchDayVersion = async (client, dayId, expectedVersion) => {
  const { rows: [row] } = await client.query(`
    UPDATE itineraries SET title=title
    WHERE id=$1 AND xmin::text=$2
    RETURNING *,xmin::text AS row_version`, [dayId, expectedVersion]);
  return row || null;
};

/**
 * @description Lấy danh sách các chuyến đi/lịch trình công khai.
 */
const listPublicTrips = async (client, query) => {
  const params = [];
  const filters = ["t.status='COMPLETED'", "t.privacy_type='PUBLIC'"];
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
    SELECT t.*,COALESCE(r.average_rating,0) AS average_rating,
      COALESCE(r.review_count,0)::int AS review_count
    FROM trips t
    LEFT JOIN LATERAL (
      SELECT AVG(tr.rating)::numeric(3,2) AS average_rating,COUNT(*) AS review_count
      FROM trip_reviews tr WHERE tr.trip_id=t.id AND tr.reviewee_id IS NULL
    ) r ON TRUE
    WHERE ${where}
    ORDER BY average_rating DESC,review_count DESC,t.clone_count DESC,t.updated_at DESC
    LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows, total };
};

/**
 * @description Xem chi tiết một chuyến đi công khai.
 */
const findPublicTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    SELECT t.*,COALESCE(r.average_rating,0) AS average_rating,
      COALESCE(r.review_count,0)::int AS review_count
    FROM trips t
    LEFT JOIN LATERAL (
      SELECT AVG(tr.rating)::numeric(3,2) AS average_rating,COUNT(*) AS review_count
      FROM trip_reviews tr WHERE tr.trip_id=t.id AND tr.reviewee_id IS NULL
    ) r ON TRUE
    WHERE t.id=$1 AND t.status='COMPLETED' AND t.privacy_type='PUBLIC'`, [tripId]);
  return row || null;
};

const createClonedTrip = async (client, userId, source, data) => {
  const { rows: [trip] } = await client.query(`
    INSERT INTO trips (
      creator_id,name,destination,start_date,end_date,estimated_budget,
      cover_image_url,description,privacy_type,status,is_clone,original_trip_id
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'PRIVATE','UPCOMING',TRUE,$9)
    RETURNING *`, [userId, data.name, source.destination, data.startDate, data.endDate,
    source.estimated_budget || 0, source.cover_image_url || null,
    source.description || null, source.id]);
  await client.query(`
    INSERT INTO trip_members (trip_id,user_id,role,membership_status)
    VALUES ($1,$2,'LEADER','ACTIVE')`, [trip.id, userId]);
  return trip;
};

/**
 * @description Sao chép một ngày lịch trình từ chuyến đi mẫu.
 */
const insertClonedDay = async (client, targetTripId, sourceDay, tripDate) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itineraries (trip_id,day_number,title,trip_date)
    VALUES ($1,$2,$3,$4) RETURNING *,xmin::text AS row_version`,
  [targetTripId, sourceDay.day_number, sourceDay.title, tripDate]);
  return row;
};

/**
 * @description Sao chép toàn bộ hoạt động của ngày vào chuyến đi mới.
 */
const insertClonedItems = async (client, sourceDayId, targetDayId) => {
  const { rows } = await client.query(`
    INSERT INTO itinerary_items (
      itinerary_id,place_id,custom_name,custom_address,category,start_time,end_time,
      order_index,note,estimated_cost,is_completed
    ) SELECT $2,place_id,custom_name,custom_address,category,start_time,end_time,
      order_index,note,estimated_cost,FALSE
    FROM itinerary_items WHERE itinerary_id=$1
    ORDER BY order_index,start_time,id RETURNING *,xmin::text AS row_version`,
  [sourceDayId, targetDayId]);
  return rows;
};

/**
 * @description Ghi nhận số lượt sao chép từ chuyến đi gốc.
 */
const markClone = async (client, sourceTripId) => {
  await client.query(
    'UPDATE trips SET clone_count=clone_count+1 WHERE id=$1', [sourceTripId]);
};

module.exports = {
  getMembership, findTrip, findTripForMember, findDays, findItemsForDays,
  findDay, findItem, createDay, updateDay, findPlace, hasOverlap, nextOrderIndex,
  createItem, updateItem, setCompletion, deleteItem, findDayItemsWithPlaces,
  findSwapCandidates, applySmartSwap, notifyTripMembers, reorderItems, touchDayVersion,
  listPublicTrips, findPublicTrip, createClonedTrip,
  insertClonedDay, insertClonedItems, markClone,
};
