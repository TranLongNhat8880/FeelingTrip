const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Itineraries
// Giao tiếp với cơ sở dữ liệu cho bảng itineraries, itinerary_items
// ============================================================================

/**
 * @description Lấy bản ghi thành viên của người dùng trong chuyến đi (mọi trạng thái).
 * Bảng: trip_members, lọc theo trip_id + user_id.
 * Nếu forUpdate = true thì khóa dòng (FOR UPDATE).
 * Dùng để kiểm tra quyền: có phải thành viên ACTIVE, có phải trưởng nhóm.
 * Trả về: bản ghi trip_members hoặc null.
 */
const getMembership = async (client, tripId, userId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trip_members WHERE trip_id=$1 AND user_id=$2${forUpdate ? ' FOR UPDATE' : ''}`,
    [tripId, userId]);
  return row || null;
};

/**
 * @description Lấy toàn bộ thông tin chuyến đi theo id.
 * Bảng: trips. Nếu forUpdate = true thì khóa dòng (FOR UPDATE).
 * Trả về: object chuyến đi hoặc null.
 */
const findTrip = async (client, tripId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trips WHERE id=$1${forUpdate ? ' FOR UPDATE' : ''}`, [tripId]);
  return row || null;
};

/**
 * @description Lấy thông tin cơ bản của chuyến đi, chỉ khi người dùng đang là thành viên ACTIVE.
 * Bảng: trips JOIN trip_members.
 * Lấy: id, tên, ngày bắt đầu, ngày kết thúc, trạng thái và vai trò của người dùng.
 * Trả về: object hoặc null (không tồn tại hoặc không có quyền).
 */
const findTripForMember = async (client, tripId, userId) => {
  const { rows: [row] } = await client.query(`
    SELECT t.id,t.name,t.start_date,t.end_date,t.status,tm.role AS member_role
    FROM trips t JOIN trip_members tm ON tm.trip_id=t.id
    WHERE t.id=$1 AND tm.user_id=$2 AND tm.membership_status='ACTIVE'`, [tripId, userId]);
  return row || null;
};

/**
 * @description Lấy tất cả các ngày lịch trình đã được tạo của chuyến đi, sắp xếp theo thứ tự ngày.
 * Bảng: itineraries.
 * Lưu ý: ngày nào chưa có hoạt động sẽ không có bản ghi; service tự dựng ngày "ảo" để hiển thị đủ.
 * Trả về: mảng ngày.
 */
const findDays = async (client, tripId) => {
  const { rows } = await client.query(
    'SELECT * FROM itineraries WHERE trip_id=$1 ORDER BY day_number', [tripId]);
  return rows;
};

/**
 * @description Lấy tất cả hoạt động của nhiều ngày chỉ bằng 1 câu truy vấn (dùng ANY với mảng id).
 * Bảng: itinerary_items.
 * Sắp xếp theo giờ bắt đầu, rồi order_index.
 * Gom 1 câu để tránh lỗi N+1 query (mỗi ngày phải query riêng một lần).
 * Trả về: mảng hoạt động; trả mảng rỗng nếu không truyền id nào.
 */
const findItemsForDays = async (client, dayIds) => {
  if (!dayIds.length) return [];
  const { rows } = await client.query(`
    SELECT * FROM itinerary_items WHERE itinerary_id=ANY($1::uuid[])
    ORDER BY start_time,order_index,id`, [dayIds]);
  return rows;
};

/**
 * @description Lấy một ngày lịch trình kèm thông tin chuyến đi (trạng thái, ngày bắt đầu/kết thúc, số ngày, điểm đến).
 * Bảng: itineraries JOIN trips.
 * Nếu forUpdate = true thì chỉ khóa dòng của bảng itineraries (FOR UPDATE OF i).
 * Trả về: object ngày hoặc null.
 */
const findDay = async (client, dayId, forUpdate = false) => {
  const { rows: [row] } = await client.query(`
    SELECT i.*,t.status AS trip_status,t.start_date,t.end_date,t.duration_days,t.destination
    FROM itineraries i JOIN trips t ON t.id=i.trip_id
    WHERE i.id=$1${forUpdate ? ' FOR UPDATE OF i' : ''}`, [dayId]);
  return row || null;
};

/**
 * @description Lấy một hoạt động kèm thông tin ngày, chuyến đi và địa điểm gắn với nó.
 * Bảng: itinerary_items JOIN itineraries JOIN trips, LEFT JOIN places.
 * Dùng LEFT JOIN vì hoạt động có thể là địa điểm tự nhập, không gắn với bảng places.
 * Dữ liệu địa điểm (tọa độ, mức giá, thời lượng, đánh giá) dùng cho tính năng Smart Swap.
 * Nếu forUpdate = true thì chỉ khóa dòng của bảng itinerary_items (FOR UPDATE OF ii).
 * Trả về: object hoạt động hoặc null.
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
 * @description Tạo một ngày lịch trình mới cho chuyến đi.
 * Bảng: itineraries (trip_id, day_number, title, trip_date).
 * Trả về: bản ghi ngày vừa tạo.
 */
const createDay = async (client, tripId, dayNumber, title, tripDate) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itineraries (trip_id,day_number,title,trip_date)
    VALUES ($1,$2,$3,$4) RETURNING *`, [tripId, dayNumber, title, tripDate]);
  return row;
};

/**
 * @description Đổi tiêu đề của một ngày lịch trình.
 * Bảng: itineraries.
 * Trả về: bản ghi sau khi cập nhật hoặc null.
 */
const updateDay = async (client, dayId, title) => {
  const { rows: [row] } = await client.query(`
    UPDATE itineraries SET title=$2 WHERE id=$1 RETURNING *`, [dayId, title]);
  return row || null;
};

/**
 * @description Lấy thông tin một địa điểm theo id.
 * Bảng: places (thuộc phân hệ Places).
 * Dùng để kiểm tra địa điểm tồn tại và lấy tên, địa chỉ, danh mục khi thêm hoạt động.
 * Trả về: object địa điểm hoặc null.
 */
const findPlace = async (client, placeId) => {
  const { rows: [row] } = await client.query('SELECT * FROM places WHERE id=$1', [placeId]);
  return row || null;
};

/**
 * @description Kiểm tra hoạt động mới có bị trùng giờ với hoạt động khác trong cùng ngày hay không.
 * Bảng: itinerary_items.
 * Hai khoảng giờ bị trùng khi: giờ bắt đầu cũ < giờ kết thúc mới VÀ giờ kết thúc cũ > giờ bắt đầu mới.
 * excludedItemId: bỏ qua chính hoạt động đang sửa để nó không bị tính là trùng với chính nó.
 * Trả về: true nếu bị trùng giờ.
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
 * @description Tính số thứ tự (order_index) cho hoạt động tiếp theo trong ngày.
 * Bảng: itinerary_items. Công thức: MAX(order_index) + 1; ngày chưa có hoạt động nào thì trả về 0.
 * Trả về: số nguyên.
 */
const nextOrderIndex = async (client, dayId) => {
  const { rows: [row] } = await client.query(
    'SELECT COALESCE(MAX(order_index),-1)+1 AS next FROM itinerary_items WHERE itinerary_id=$1', [dayId]);
  return Number(row.next);
};

/**
 * @description Thêm một hoạt động mới vào ngày lịch trình.
 * Bảng: itinerary_items. Mặc định is_completed = FALSE, chi phí dự kiến mặc định 0.
 * place_id có thể null nếu là địa điểm tự nhập.
 * Trả về: bản ghi hoạt động vừa tạo.
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
 * @description Cập nhật thông tin hoạt động, chỉ cập nhật các trường được gửi lên.
 * Bảng: itinerary_items.
 * Câu UPDATE được ghép động từ danh sách cột cố định (map) nên không bị SQL injection. Chuỗi rỗng lưu thành NULL.
 * Trả về: bản ghi sau khi cập nhật hoặc null.
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
 * @description Đánh dấu hoạt động đã hoàn thành / chưa hoàn thành.
 * Bảng: itinerary_items, cột is_completed.
 * Trả về: bản ghi sau khi cập nhật hoặc null.
 */
const setCompletion = async (client, itemId, isCompleted) => {
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET is_completed=$2
    WHERE id=$1 RETURNING *`, [itemId, isCompleted]);
  return row || null;
};

/**
 * @description Xóa hẳn một hoạt động khỏi lịch trình.
 * Bảng: itinerary_items.
 * Trả về: bản ghi vừa xóa hoặc null nếu không tồn tại.
 */
const deleteItem = async (client, itemId) => {
  const { rows: [row] } = await client.query(
    'DELETE FROM itinerary_items WHERE id=$1 RETURNING *', [itemId]);
  return row || null;
};

/**
 * @description Lấy tất cả hoạt động trong một ngày kèm thông tin địa điểm (tọa độ, mức giá, thời lượng, đánh giá).
 * Bảng: itinerary_items LEFT JOIN places.
 * Sắp xếp theo giờ bắt đầu, rồi order_index.
 * Dùng cho Smart Swap để kiểm tra hoạt động trước và sau khi gợi ý địa điểm thay thế.
 * Trả về: mảng hoạt động.
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
 * @description Tìm các địa điểm có thể thay thế cho một hoạt động (tính năng Smart Swap).
 * Bảng: places, kèm NOT EXISTS sang itinerary_items + itineraries.
 * Khoảng cách (km) được tính bằng công thức Haversine từ vĩ độ / kinh độ.
 * Điều kiện chọn địa điểm:
 *   - Khác địa điểm hiện tại và đang hoạt động (is_active = TRUE).
 *   - Cùng điểm đến (không phân biệt hoa thường) và cùng danh mục.
 *   - Có tọa độ.
 *   - Mức giá chênh không quá 1 bậc (nếu null thì coi là bậc 1).
 *   - Thời lượng tham quan chênh không quá max(30 phút, 50% thời lượng gốc).
 *   - Chưa được dùng trong bất kỳ hoạt động nào của chuyến đi này.
 *   - Nằm trong bán kính radiusKm.
 * Sắp xếp theo khoảng cách gần nhất, lấy tối đa 100 địa điểm.
 * Trả về: mảng địa điểm kèm distance_from_original_km.
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
 * @description Áp dụng Smart Swap: thay địa điểm của hoạt động bằng địa điểm mới đã chọn.
 * Bảng: itinerary_items. Cập nhật place_id, tên, địa chỉ, danh mục theo địa điểm mới.
 * Giờ bắt đầu / kết thúc được giữ nguyên.
 * Trả về: bản ghi sau khi cập nhật hoặc null.
 */
const applySmartSwap = async (client, itemId, place) => {
  const { rows: [row] } = await client.query(`
    UPDATE itinerary_items SET place_id=$2,custom_name=$3,custom_address=$4,category=$5
    WHERE id=$1 RETURNING *`, [itemId, place.id, place.name, place.address, place.category]);
  return row || null;
};

/**
 * @description Gửi thông báo cho TẤT CẢ thành viên ACTIVE của chuyến đi, trừ người thực hiện thao tác.
 * Bảng: notifications, dùng INSERT ... SELECT từ trip_members, type = TRIP_UPDATE.
 * Ví dụ: báo cả nhóm khi lịch trình bị thay đổi bằng Smart Swap.
 */
const notifyTripMembers = async (client, tripId, actorId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    SELECT tm.user_id,$3,$4,'TRIP_UPDATE',$5::jsonb FROM trip_members tm
    WHERE tm.trip_id=$1 AND tm.membership_status='ACTIVE' AND tm.user_id<>$2`,
    [tripId, actorId, title, message, JSON.stringify(data)]);
};

/**
 * @description Lấy danh sách lịch trình công khai để người khác tham khảo hoặc sao chép, có lọc và phân trang.
 * Bảng: trips.
 * Chỉ lấy chuyến đi chưa bị hủy và (công khai HOẶC là mẫu đang hoạt động).
 * Lọc thêm (không bắt buộc):
 *   - destination: điểm đến, so khớp không phân biệt hoa thường.
 *   - durationDays: số ngày.
 *   - keyword: tìm trong tên chuyến, mô tả, hoặc tên bất kỳ hoạt động nào (ILIKE).
 * Câu 1: COUNT(*) để đếm tổng số bản ghi.
 * Câu 2: lấy dữ liệu, sắp xếp mẫu đang hoạt động lên đầu, rồi theo số lượt sao chép, rồi theo lần cập nhật mới nhất.
 * Phân trang: LIMIT = limit, OFFSET = (page - 1) * limit.
 * Trả về: { rows, total }.
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
 * @description Lấy một chuyến đi công khai theo id.
 * Bảng: trips. Điều kiện: chưa bị hủy và (công khai HOẶC là mẫu đang hoạt động).
 * Trả về: object chuyến đi hoặc null nếu không tồn tại / không được xem.
 */
const findPublicTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    SELECT * FROM trips WHERE id=$1 AND status<>'CANCELLED'
      AND (privacy_type='PUBLIC' OR (is_template=TRUE AND template_status='ACTIVE'))`, [tripId]);
  return row || null;
};

/**
 * @description Kiểm tra chuyến đi đích đã có ngày lịch trình nào chưa.
 * Bảng: itineraries.
 * Dùng trước khi sao chép (clone) để không ghi đè lên lịch trình đang có.
 * Trả về: true nếu đã có ít nhất 1 ngày.
 */
const targetHasDays = async (client, tripId) => {
  const { rowCount } = await client.query('SELECT 1 FROM itineraries WHERE trip_id=$1 LIMIT 1', [tripId]);
  return rowCount > 0;
};

/**
 * @description Sao chép một ngày lịch trình từ chuyến nguồn sang chuyến đích.
 * Bảng: itineraries. Giữ số thứ tự ngày và tiêu đề;
 * trip_date được tính lại theo ngày bắt đầu của chuyến đích.
 * Trả về: bản ghi ngày mới tạo.
 */
const insertClonedDay = async (client, targetTripId, sourceDay, tripDate) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO itineraries (trip_id,day_number,title,trip_date)
    VALUES ($1,$2,$3,$4) RETURNING *`, [targetTripId, sourceDay.day_number, sourceDay.title, tripDate]);
  return row;
};

/**
 * @description Sao chép toàn bộ hoạt động của một ngày nguồn sang ngày đích chỉ bằng 1 câu lệnh.
 * Bảng: itinerary_items, dùng INSERT ... SELECT.
 * Mỗi hoạt động mới có id mới; trạng thái hoàn thành được đặt lại là FALSE.
 * Trả về: mảng hoạt động vừa tạo.
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
 * @description Ghi lại thông tin sao chép giữa 2 chuyến đi.
 * Bước 1: bảng trips, đánh dấu chuyến đích is_clone = TRUE và lưu original_trip_id = id chuyến nguồn.
 * Bước 2: bảng trips, tăng clone_count của chuyến nguồn thêm 1.
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
